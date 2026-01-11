#!/bin/bash
#==============================================================================
# Script: run_extract_gdas.sh
# Purpose: Extraction of variables from sflux grib2 file(s)
#==============================================================================

exit_err() {
    echo "FATAL ERROR: ${1}" >&2
    exit 1
}

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <START_YYYYMMDD> <END_YYYYMMDD> <BASE_PATH> [PURGE_GRIB] [RUN_PARALLEL]"
    exit 1
fi

SDATE="${1}"
EDATE="${2}"
BASE_PATH="${3}"
PURGE_GRIB=${4:-"False"}
RUN_PARALLEL=${5:-"True"}

# 1. List of variables from https://github.com/sanAkel/ufs-ocean/blob/main/scripts/grib_to_nc_mapping.md
# A. Instantaneous state variables
G_INST=':LAND:surface:|:UGRD:1 hybrid level:|:VGRD:1 hybrid level:|:TMP:1 hybrid level:|:PRES:surface:|:SPFH:1 hybrid level:|:UGRD:10 m above ground:|:VGRD:10 m above ground:|:SPFH:2 m above ground:|:HGT:1 hybrid level:|:TMP:surface:|:TMP:2 m above ground:|:CPOFP:surface:'

# 2. Averaged Fluxes
G_FLUX=':DLWRF:surface:|:VBDSF:surface:|:VDDSF:surface:|:NBDSF:surface:|:NDDSF:surface:|:PRATE:surface:|:CPOFP:surface:'

# C. Temperatures
G_TEMP=':TMP:(surface|2 m above ground|1 hybrid level):'

# Concatenate them
GRIB_SEARCH="${G_INST}|${G_FLUX}|${G_TEMP}"

# 1. FORCE wgrib2 to use only 1 thread per process to avoid OMP Resource Errors
export OMP_NUM_THREADS=1

# Define the processing logic as a function for parallel/loop compatibility
process_file() {
    local grib_file="$1"
    local GRIB_SEARCH="$2"
    local PURGE_GRIB="$3"

    # Ensure the thread limit is respected inside the sub-shell
    export OMP_NUM_THREADS=1

    if [[ -f "${grib_file}" && -s "${grib_file}" ]]; then
      base_filename="${grib_file##*/}"
      dir_path="${grib_file%/*}"
      output_nc="${dir_path}/${base_filename%.grib2}.nc"

      echo "Processing: ${grib_file}"
      # 2. Extract using wgrib2
      wgrib2 "${grib_file}" -match "${GRIB_SEARCH}" -netcdf "${output_nc}"

      if [[ -f "${output_nc}" && -s "${output_nc}" ]]; then
        echo "   SUCCESS: Created $(basename "${output_nc}")"
        if [[ "${PURGE_GRIB^^}" == "TRUE" ]]; then
          rm -f "${grib_file}"
        fi
      else
        echo "FATAL ERROR: NetCDF ${output_nc} is missing or empty." >&2
        return 1
      fi
    else
      echo "FATAL ERROR: GRIB2 file ${grib_file} missing or empty." >&2
      return 1
    fi
}

export -f process_file
source "machine_modules.sh"

echo "----------------------------------------------------------"
echo " CONFIGURATION: $SDATE - $EDATE"
echo " Purge GRIB:    $PURGE_GRIB"
echo " Run Parallel:  $RUN_PARALLEL | OMP_THREADS: $OMP_NUM_THREADS"
echo "----------------------------------------------------------"

# ... [Keep your variable definitions and process_file function as is] ...

if [[ "${RUN_PARALLEL^^}" == "TRUE" ]]; then
    # --- Parallel Logic ---
    echo "Starting Parallel Extraction (Jobs: 4)..."

    # Use find to list files, then use parallel to call the function.
    # We wrap the arguments in single quotes to protect the regex pipes (|)
    find "${BASE_PATH}"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]* -name "*.grib2" -print0 | \
    parallel -0 --jobs 4 "process_file {} '${GRIB_SEARCH}' '${PURGE_GRIB}'"
else
    # --- Sequential Logic ---
    echo "Starting Sequential Extraction..."
    for grib_file in "${BASE_PATH}"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*/*.grib2; do
        process_file "${grib_file}" "${GRIB_SEARCH}" "${PURGE_GRIB}" || exit_err "Processing failed for ${grib_file}"
    done
fi

echo "Extraction Complete."
