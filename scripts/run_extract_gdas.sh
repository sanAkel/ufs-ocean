#!/bin/bash
#==============================================================================
# Script: run_extract_gdas.sh
# Purpose: Extraction of variables from sflux grib2 file(s) using a list file.
# Requirement: Needs wgrib2 module to be loaded.
#==============================================================================

exit_err() {
    echo "FATAL ERROR: ${1}" >&2
    exit 1
}

# 1. Usage
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <LIST_FILE> [CONFIG_FILE] [PURGE_GRIB (Default: False)] [RUN_PARALLEL (Default: True)]"
    echo "Defaults:"
    echo "  CONFIG_FILE:  ../parm/vars_GFSv16.3.txt"
    echo "  PURGE_GRIB:   False"
    echo "  RUN_PARALLEL: True"
    exit 1
fi

INPUT_LIST="${1}"

# Check that the list file is present and NOT empty
if [[ ! -f "${INPUT_LIST}" || ! -s "${INPUT_LIST}" ]]; then
    exit_err "Input list file '${INPUT_LIST}' is missing or empty."
fi

# 2. Configuration File (Arg 2)
VARS_ARG=${2:-"../parm/vars_GFSv16.3.txt"}

# 3. Purge and Parallel Toggles (Args 3 and 4)
PURGE_GRIB=${3:-"False"}
RUN_PARALLEL=${4:-"True"}

# Resolve and source the configuration (this provides GRIB_SEARCH)
if [[ -f "${VARS_ARG}" ]]; then
    VARS_CONFIG="${VARS_ARG}"
    source "${VARS_CONFIG}"
else
    exit_err "Configuration file ${VARS_ARG} not found."
fi

# FORCE wgrib2 to use only 1 thread per process to avoid OMP Resource Errors
export OMP_NUM_THREADS=1

# Define the processing logic
process_file() {
    local grib_file="$1"
    local GRIB_SEARCH="$2"
    local PURGE_GRIB="$3"

    export OMP_NUM_THREADS=1

    if [[ -f "${grib_file}" && -s "${grib_file}" ]]; then
      base_filename="${grib_file##*/}"
      dir_path="${grib_file%/*}"
      output_nc="${dir_path}/wgrib_extr_${base_filename%.grib2}.nc"

      echo "Processing: ${grib_file}"
      # Extraction using wgrib2
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
echo " CONFIGURATION: Processing list ${INPUT_LIST}"
echo " Config File:   $VARS_CONFIG"
echo " Purge GRIB:    $PURGE_GRIB"
echo " Run Parallel:  $RUN_PARALLEL | OMP_THREADS: $OMP_NUM_THREADS"
echo "----------------------------------------------------------"

# 4. Parse the list file:
# Skip the first line (the file count) and extract the second column (the file paths)
FILE_PATHS=$(tail -n +2 "${INPUT_LIST}" | awk '{print $2}')

if [[ "${RUN_PARALLEL^^}" == "TRUE" ]]; then
    echo "Starting Parallel Extraction (Jobs: 4)..."
    # Pass paths to GNU Parallel
    echo "${FILE_PATHS}" | parallel --jobs 4 "process_file {} '${GRIB_SEARCH}' '${PURGE_GRIB}'"
else
    echo "Starting Sequential Extraction..."
    for grib_file in ${FILE_PATHS}; do
        process_file "${grib_file}" "${GRIB_SEARCH}" "${PURGE_GRIB}" || exit_err "Processing failed for ${grib_file}"
    done
fi

echo "----------------------------------------------------------"
echo " Generating NetCDF List: ${INPUT_LIST%.dat}.nc.dat"
echo "----------------------------------------------------------"

NC_LIST="${INPUT_LIST%.dat}.nc.dat"
# Write the header (count)
head -n 1 "${INPUT_LIST}" > "$NC_LIST"

# Transform GRIB paths to NC paths: change extension and add prefix to filename
tail -n +2 "${INPUT_LIST}" | sed 's/\.grib2/\.nc/g; s|/rtofs\.|/wgrib_extr_rtofs\.|g' >> "$NC_LIST"

# Final verification: Ensure every file in the new list actually exists
echo "Verifying NetCDF file existence..."
error_count=0
while read -r line; do
    # Skip the first line (the count)
    [[ "$line" =~ ^[0-9]+$ ]] && continue
    
    nc_path=$(echo "$line" | awk '{print $2}')
    if [[ ! -s "$nc_path" ]]; then
        echo "ERROR: Missing or empty NetCDF: $nc_path" >&2
        ((error_count++))
    fi
done < "$NC_LIST"

if [ "$error_count" -gt 0 ]; then
    exit_err "Verification failed. $error_count files are missing or empty."
else
    echo "SUCCESS: All NetCDF files verified. List saved to: $NC_LIST"
fi

echo "Extraction Complete."

exit 0
