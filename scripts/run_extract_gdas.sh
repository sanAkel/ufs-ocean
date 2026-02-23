#!/bin/bash
#==============================================================================
# Script: run_extract_gdas.sh
# Purpose: Extraction of variables from sflux grib2 file(s).
# Requirement: Needs wgrib2 module to be loaded.
#==============================================================================

exit_err() {
    echo "FATAL ERROR: ${1}" >&2
    exit 1
}

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <START_YYYYMMDD> <END_YYYYMMDD> <BASE_PATH> [CONFIG_FILE] [PURGE_GRIB (Default: False)] [RUN_PARALLEL (Default: True)]"
    echo "Defaults:"
    echo "  CONFIG_FILE:  ../parm/vars_GFSv16.3.txt"
    echo "  PURGE_GRIB:   False"
    echo "  RUN_PARALLEL: True"
    exit 1
fi

SDATE="${1}"
EDATE="${2}"
BASE_PATH="${3}"

# 1. Configuration File (Arg 4)
VARS_ARG=${4:-"../parm/vars_GFSv16.3.txt"}

# 2. Purge and Parallel Toggles (Args 5 and 6)
PURGE_GRIB=${5:-"False"}
RUN_PARALLEL=${6:-"True"}

# 1. GRIB2 variable names - Resolve and source the configuration
if [[ -f "${VARS_ARG}" ]]; then
    VARS_CONFIG="${VARS_ARG}"
    source "${VARS_CONFIG}"
else
    exit_err "Configuration file ${VARS_ARG} not found."
fi

# 2. FORCE wgrib2 to use only 1 thread per process to avoid OMP Resource Errors
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
echo " CONFIGURATION: $SDATE - $EDATE"
echo " Purge GRIB:    $PURGE_GRIB"
echo " Run Parallel:  $RUN_PARALLEL | OMP_THREADS: $OMP_NUM_THREADS"
echo "----------------------------------------------------------"

if [[ "${RUN_PARALLEL^^}" == "TRUE" ]]; then
    # --- Parallel Logic ---
    echo "Starting Parallel Extraction (Jobs: 4)..."

    # Find files and pass to parallel with quoted variables to protect pipes
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
