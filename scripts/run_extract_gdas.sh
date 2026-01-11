#!/bin/bash
#==============================================================================
# Script: run_extract_gdas.sh
# Purpose: Extraction with precise record matching
#==============================================================================

exit_err() {
    echo "FATAL ERROR: ${1}" >&2
    exit 1
}

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <START_YYYYMMDD> <END_YYYYMMDD> <BASE_PATH> [PURGE_GRIB]"
    exit 1
fi

SDATE="${1}"
EDATE="${2}"
BASE_PATH="${3}"
PURGE_GRIB=${4:-"False"}

# 1. List of variables from https://github.com/sanAkel/ufs-ocean/blob/main/scripts/grib_to_nc_mapping.md
# A. Instantaneous state variables (HGT, PRES, LAND, Wind, Humidity)
G_INST=':LAND:surface:|:UGRD:1 hybrid level:|:VGRD:1 hybrid level:|:TMP:1 hybrid level:|:PRES:surface:|:SPFH:1 hybrid level:|:UGRD:10 m above ground:|:VGRD:10 m above ground:|:SPFH:2 m above ground:|:HGT:1 hybrid level:|:TMP:surface:|:TMP:2 m above ground:|:CPOFP:surface:'

# 2. Averaged Fluxes (DLWRF, VBDSF, VDDSF, NBDSF, NDDSF, PRATE)
#G_FLUX=':DLWRF:surface:.*ave fcst:|:V[BD]DSF:surface:.*ave fcst:|:N[BD]DSF:surface:.*ave fcst:|:PRATE:surface:.*ave fcst:|:CPOFP:surface:'
G_FLUX=':DLWRF:surface:|:VBDSF:surface:|:VDDSF:surface:|:NBDSF:surface:|:NDDSF:surface:|:PRATE:surface:|:CPOFP:surface:'

# C. Temperatures (matches surface, 2m, and hyb lev for any hour)
G_TEMP=':TMP:(surface|2 m above ground|1 hybrid level):'

# Concatenate them
GRIB_SEARCH="${G_INST}|${G_FLUX}|${G_TEMP}"
#GRIB_SEARCH="${G_INST}|${G_TEMP}"

source "machine_modules.sh"

echo "----------------------------------------------------------"
echo " CONFIGURATION: $SDATE - $EDATE | Purge: $PURGE_GRIB"
echo "----------------------------------------------------------"

for grib_file in "${BASE_PATH}"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*/*.grib2; do

    if [[ -f "${grib_file}" && -s "${grib_file}" ]]; then
      base_filename="${grib_file##*/}"       # Extracts 'rtofs.gdas.t00z.sfluxgrbf001.grib2'
      dir_path="${grib_file%/*}"
      output_nc="${dir_path}/${base_filename%.grib2}.nc"

      echo "Processing: ${grib_file}"
      # 2. Extract using wgrib2
      wgrib2 "${grib_file}" -match "${GRIB_SEARCH}" -netcdf "${output_nc}" || exit_err "wgrib2 failed on ${grib_file}"
      #wgrib2 "${grib_file}" -egrep "${GRIB_SEARCH}" -netcdf "${output_nc}" || exit_err "wgrib2 failed on ${grib_file}"

      if [[ -f "${output_nc}" && -s "${output_nc}" ]]; then
        echo "   SUCCESS: Created $(basename "${output_nc}")"
      else
        exit_err "Final NetCDF ${output_nc} is missing or empty."
      fi 
        
      if [[ "${PURGE_GRIB^^}" == "TRUE" ]]; then
        rm -f "${grib_file}"
      fi

    else
      exit_err "GRIB2 file ${grib_file} missing or empty."
    fi
done
