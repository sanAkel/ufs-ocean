#!/bin/bash

# ==============================================================================
# machine_modules.sh
# Loads the UFS environment and machine-specific utilities.
# Usage: source machine_modules.sh
# ==============================================================================

# Ensure we have the base path
if [[ -z "${BASE:-}" ]]; then
    BASE=$(pwd)
fi

# Construct paths to UFS weather model components
dir_mods="$(dirname "${BASE}")"
ufs_wm_path="${dir_mods}/sorc/ufs-weather-model"

# 1. Detect Machine (Sets MACHINE_ID)
if [[ -f "${ufs_wm_path}/tests/detect_machine.sh" ]]; then
    source "${ufs_wm_path}/tests/detect_machine.sh"
    echo "Machine: ${MACHINE_ID}"
else
    echo "ERROR: detect_machine.sh not found at ${ufs_wm_path}/tests/"
    return 1 2>/dev/null || exit 1
fi

# 2. Setup Modules (Bootstrap Lmod and Purge)
if [[ -f "${ufs_wm_path}/tests/module-setup.sh" ]]; then
    source "${ufs_wm_path}/tests/module-setup.sh"
else
    echo "ERROR: module-setup.sh not found!"
    return 1 2>/dev/null || exit 1
fi

# 3. Use local modulefiles directory
if [[ -d "${ufs_wm_path}/modulefiles" ]]; then
    module use "${ufs_wm_path}/modulefiles"
else
    echo "WARNING: Local modulefiles directory not found at ${ufs_wm_path}/modulefiles"
fi

# 4. Load machine-specific Intel stack
if [[ "${MACHINE_ID}" != "UNKNOWN" ]]; then
    module load "ufs_${MACHINE_ID}.intel"
    [[ $? -eq 0 ]] && echo "Loaded core UFS stack for ${MACHINE_ID}"
else
    echo "ERROR: Machine ID is UNKNOWN. Core modules not loaded."
    return 1 2>/dev/null || exit 1
fi

# 5. Load Extra Machine-Specific Modules (Post-processing/Utilities)
echo "Loading extra utilities for ${MACHINE_ID}..."
case "${MACHINE_ID}" in
    "ursa")
        module load wgrib2/3.1.3_ncep
        # You can add more Ursa-specific tools here
        # module load nco/5.0.6
        ;;
    "wcoss2")
        module load wgrib2/2.0.8
        ;;
    "hera")
        module load wgrib2/3.1.1_ncep
        ;;
    *)
        echo "No extra modules defined for ${MACHINE_ID}."
        ;;
esac

# Verification
echo "------------------------------------------------"
module list
echo "------------------------------------------------"
