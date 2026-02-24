#!/bin/bash
#==============================================================================
# Script: run_stage_gdas.sh
# Purpose: Loop through dates and cycles to run stage_gdas.py and create file list.
# Usage: ./run_stage_gdas.sh START END PLATFORM BASE_PATH
#==============================================================================

if [ "$#" -ne 4 ]; then
    echo " "
    echo "Usage: $0 <YYYYMMDD_START> <YYYYMMDD_END> <PLATFORM> <BASE_PATH>"
    echo "Valid choices for PLATFORM: WCOSS, GAEA_C6, URSA"
    echo " "
    echo "Note: It is recommended to add/subtract one (1) day to the START and END dates, for time-interpolation."
    echo " "
    exit 1
fi

SDATE=$1
EDATE=$2
PLATFORM=$3
BASE_PATH=$4

source "machine_modules.sh"

# Create the root base path if it doesn't exist
mkdir -p "$BASE_PATH"

# Convert dates to seconds for comparison (GNU date)
current_s=$(date -d "$SDATE" +%s)
end_s=$(date -d "$EDATE" +%s)

while [ "$current_s" -le "$end_s" ]; do
    PDY=$(date -d "@$current_s" +%Y%m%d)
    
    for CYC in 00 06 12 18; do
        echo "=========================================================="
        echo " PROCESSING: $PDY | CYCLE: $CYC | PLATFORM: $PLATFORM"
        echo " BASE DIRECTORY: $BASE_PATH"
        echo "=========================================================="
        
        # We pass the root BASE_PATH. 
        # stage_gdas.py will create hourly folders like BASE_PATH/2025122901/
        ./stage_gdas.py --pdy "$PDY" --cyc "$CYC" --out "$BASE_PATH" --platform "$PLATFORM"
        
        if [ $? -ne 0 ]; then
            echo "WARNING: Staging failed for cycle ${PDY}${CYC}"
            exit 2
        fi
    done
    
    current_s=$((current_s + 86400))
done

echo "----------------------------------------------------------"
echo " Generating File List: rtofs_glo.${SDATE}_${EDATE}.listflx.dat"
echo "----------------------------------------------------------"

# 1. Define the output filename
LIST_FILE="${BASE_PATH}/rtofs_glo.${SDATE}_${EDATE}.listflx.dat"
TMP_LIST=$(mktemp)

# 2. Find and sort staged files
# We search specifically for the RTOFS-prefixed grib2 files inside the date subfolders
find "$BASE_PATH" -mindepth 2 -maxdepth 2 -name "rtofs.*.grib2" | sort | while read -r filepath; do
    pdir=$(basename "$(dirname "$filepath")")
    echo "$pdir $filepath" >> "$TMP_LIST"
done

# 3. Validation and Final File Creation
if [[ -s "$TMP_LIST" ]]; then
    num_files=$(wc -l < "$TMP_LIST")
    echo "$num_files" > "$LIST_FILE"
    cat "$TMP_LIST" >> "$LIST_FILE"
    rm -f "$TMP_LIST"
else
    rm -f "$TMP_LIST"
    echo "FATAL ERROR: No staged files were found to populate $LIST_FILE." >&2
    exit 3
fi

# 4. Final Empty/Exist Check for the created LIST_FILE
if [[ ! -f "$LIST_FILE" || ! -s "$LIST_FILE" ]]; then
    echo "FATAL ERROR: $LIST_FILE was not created or is empty!" >&2
    exit 4
fi

echo "Batch processing completed successfully."
echo "List saved to: $LIST_FILE (Total files: $num_files)"
echo "----------------------------------------------------------"

exit 0
