#!/bin/bash
#==============================================================================
# Script: run_stage_gdas.sh
# Purpose: Loop through dates and cycles to run stage_gdas.py
# Usage: ./run_stage_gdas.sh START END PLATFORM BASE_PATH
#==============================================================================

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <YYYYMMDD_START> <YYYYMMDD_END> <PLATFORM> <BASE_PATH>"
    echo "Example: $0 20241201 20241231 URSA /path/to/storage"
    exit 1
fi

SDATE=$1
EDATE=$2
PLATFORM=$3
BASE_PATH=$4

# Create base path if it doesn't exist
mkdir -p "$BASE_PATH"

# Convert dates to seconds for comparison (GNU date)
current_s=$(date -d "$SDATE" +%s)
end_s=$(date -d "$EDATE" +%s)

while [ "$current_s" -le "$end_s" ]; do
    PDY=$(date -d "@$current_s" +%Y%m%d)
    
    for CYC in 00 06 12 18; do
        # Individual directory for each date/cycle
        OUTDIR="${BASE_PATH}/${PDY}${CYC}"
        
        echo "=========================================================="
        echo " PROCESSING: $PDY | CYCLE: $CYC | PLATFORM: $PLATFORM"
        echo " TARGET: $OUTDIR"
        echo "=========================================================="
        
        # Execute the python staging tool
        ./stage_gdas.py --pdy "$PDY" --cyc "$CYC" --out "$OUTDIR" --platform "$PLATFORM"
        
        # Check if python exited with error
        if [ $? -ne 0 ]; then
            echo "WARNING: Staging failed for ${PDY}${CYC}"
            # Clean up if directory is empty
            rmdir "$OUTDIR" 2>/dev/null
        fi
    done
    
    # Increment day by 24 hours
    current_s=$((current_s + 86400))
done

echo "----------------------------------------------------------"
echo " Batch processing completed."
echo "----------------------------------------------------------"
