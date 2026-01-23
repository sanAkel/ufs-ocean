#!/bin/bash

# A compile script based on test name

if [[ $# -lt 1 ]]; then
  echo " "
  echo "Usage: "
  echo "$0" "Full path to the location of the UFS Weather Model source code"
  echo " "
  echo "Example Inputs: "
  echo " /autofs/ncrc-svm1_home1/Santha.Akella/tmp/ufs-ocean/sorc/ufs-weather-model"
  echo " "
  echo " "
  exit 1
fi
echo " "

set -eux

UFSsrc=${1}

echo " "
echo " Building the UFS Weathe Model "
echo " "

APP="NG-GODAS"
CCPP_SUITES=""
PDLIB="OFF"
#
# Valid only for WCOSS2; enable parallel restart I/O
# TODO: Remove following option when parallel restart option _works_.
# ----
PARALLEL_RESTART="NO"

EXEC_NAME="ufs_model.x"
#
# D O  N O T  E D I T  B E L O W

cd ${UFSsrc} || false

source "./tests/detect_machine.sh"
source "./tests/module-setup.sh"

MAKE_OPT="-DAPP=${APP} -D32BIT=ON -DCCPP_SUITES=${CCPP_SUITES}"
if [[ ${PDLIB:-"OFF"} = "ON" ]]; then
    MAKE_OPT+=" -DPDLIB=ON"
fi
if [[ ${BUILD_TYPE:-"Release"} = "DEBUG" ]] ; then
    MAKE_OPT+=" -DDEBUG=ON"
elif [[ "${FASTER:-OFF}" == ON ]] ; then
    MAKE_OPT+=" -DFASTER=ON"
fi

case "${EXEC_NAME}" in
  "ufs_model.x") COMPILE_ID=0 ;;
  *) echo "Unsupported executable name: ${EXEC_NAME}"; exit 1 ;;
esac
CLEAN_BEFORE=YES
CLEAN_AFTER=NO

# The test/compile.sh script adds " -DENABLE_PARALLELRESTART=ON" when compiling on WCOSS2, which is causing issues
# TODO: when ufs-weather-model#2716 is fixed, return to using tests/compile.sh
if [[ "${MACHINE_ID}" == "wcoss2" && "${PARALLEL_RESTART:-}" == "NO" ]]; then
   set +x
   module use modulefiles
   module load "ufs_wcoss2.intel"
   module list
   set -x

   if [[ ${MAKE_OPT} == *-DDEBUG=ON* ]]; then
      MAKE_OPT+=" -DCMAKE_BUILD_TYPE=Debug"
   else
      MAKE_OPT+=" -DCMAKE_BUILD_TYPE=Release"
   fi

   MAKE_OPT+=" -DMPI=ON"

   BUILD_NAME="fv3_${COMPILE_ID}"
   BUILD_DIR="$(pwd)/build_${BUILD_NAME}"
   if [[ "${CLEAN_BEFORE}" == "YES" ]]; then
      rm -rf "${BUILD_DIR}"
   fi

   BUILD_DIR=${BUILD_DIR} BUILD_VERBOSE=1 BUILD_JOBS=${BUILD_JOBS:-8} CMAKE_FLAGS="${MAKE_OPT}" ./build.sh

   mv "${BUILD_DIR}/ufs_model" "tests/${BUILD_NAME}.exe"
   cp modulefiles/ufs_wcoss2.intel.lua "tests/modules.${BUILD_NAME}.lua"
   if [[ "${CLEAN_AFTER}" == "YES" ]]; then
      rm -rf "${BUILD_DIR}"
   fi
else
   MAKE_OPT+=" -DOpenMP_C_FLAGS=-qopenmp -DOpenMP_C_LIB_NAMES= -DOpenMP_CXX_FLAGS=-qopenmp -DOpenMP_CXX_LIB_NAMES= -DOpenMP_Fortran_FLAGS=-qopenmp -DOpenMP_Fortran_LIB_NAMES= -DCMAKE_EXE_LINKER_FLAGS=-qopenmp -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-multiple-definition"
   BUILD_JOBS=${BUILD_JOBS:-8} ./tests/compile.sh "${MACHINE_ID}" "${MAKE_OPT}" "${COMPILE_ID}" "intel" "${CLEAN_BEFORE}" "${CLEAN_AFTER}"
fi
mv "./tests/fv3_${COMPILE_ID}.exe" "./tests/${EXEC_NAME}"
if [[ ! -f "./tests/modules.ufs_model.lua" ]]; then mv "./tests/modules.fv3_${COMPILE_ID}.lua" "./tests/modules.ufs_model.lua"; fi
if [[ ! -f "./tests/ufs_common.lua" ]]; then cp "./modulefiles/ufs_common.lua" ./tests/ufs_common.lua; fi

echo " "
echo " "
echo "Find ${EXEC_NAME} at ${UFSsrc}/tests/"
echo "All done!"
exit 0

