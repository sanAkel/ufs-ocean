#!/bin/bash
#==============================================================================
# Script: run_stage_gdas.sh
# Purpose: Loop through dates and cycles to run stage_gdas.py
# Usage: ./run_stage_gdas.sh START END PLATFORM BASE_PATH
#==============================================================================

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <YYYYMMDD_START> <YYYYMMDD_END> <PLATFORM> <BASE_PATH>"
    exit 1
fi

SDATE=$1
EDATE=$2
PLATFORM=$3
BASE_PATH=$4

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
        fi
    done
    
    current_s=$((current_s + 86400))
done

echo "----------------------------------------------------------"
echo " Batch processing completed."
echo "----------------------------------------------------------"
