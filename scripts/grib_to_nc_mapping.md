# Mapping variables from GDAS/GFS (GRIB2) to UFS DATM (NetCDF) files

## What variables does the UFS DATM need?
  1. Start with the [ufs-weather-model](https://github.com/ufs-community/ufs-weather-model/blob/e68bc46fdcec881b8aed5e7fa1e9fbe6aa1cb7b7/tests/parm/datm.streams.IN#L15)
  2. Then modify the list based on what is actually used by [datm_datamode_gefs_mod.F90](https://github.com/NOAA-EMC/CDEPS/blob/9f53664ef2e607ad25d6b6c939f2eac9ec818ee6/datm/datm_datamode_gefs_mod.F90#L118-L156)
  3. Categorize (input) variables from GDAS/GFS based on their _level_: 
     `surface`, `1 hybrid level`, `2 m above ground`, `10 m above ground`. Note that the atmospheric model (used in GDAS/GFS) 
     [pressure levels are defined here.](https://www.emc.ncep.noaa.gov/gmb/wx24fy/misc/GFS127_profile/hyblev_gfsC128.txt)
     These pressure levels are relevant to `1 hybrid level`.
  4. Not all (output) variables used in the UFS DATM have a one-to-one mapping with inputs from GDAS/GFS.
     Those variables that are needed to construct outputs are marked with `N/A`.
  5. Some input variables are averaged over hours (0- 1, 0- 2, etc); they are marked `True` in `Avg forecast` column.
  6. Some input variables need to be checked for valid numbers; marked in `Checks and/or changes` column.

---

## Following is a listing of all input variables that are gathered from GDAS/GFS.
Surface, At the first hybrid (atmospheric pressure) level, 2 m and 10 m above ground

| GRIB2 variable name | wgrib2 to nc | Checks and/or changes | Avg forecast |
| :--- | :--- | :---  | :--- |
| **:LAND:surface:**  | `LAND_surface`  | None | False |
| **:PRES:surface:**  | `PRES_surface`  | None | False |
| **:TMP:surface:**   | `TMP_surface`   | None | False |
| **:DLWRF:surface:** | `DLWRF_surface` | None. Conform sign | True |
| **:VBDSF:surface:** | `VBDSF_surface` | where < 0 = 0. Confirm sign | True |
| **:VDDSF:surface:** | `VDDSF_surface` | where < 0 = 0. Confirm sign | True |
| **:NBDSF:surface:** | `NBDSF_surface` | where < 0 = 0. Confirm sign | True |
| **:NDDSF:surface:** | `NDDSF_surface` | where < 0 = 0. Confirm sign | True |
| **:CPOFP:surface:** | `CPOFP_surface` | Used to partition precip | False |
| **:PRATE:surface:** | `PRATE_surface` | Total precip. where < 0 = 0. | True |
| **:HGT:1 hybrid level:**  | `HGT_1hybridlevel`  | None | False |
| **:UGRD:1 hybrid level:** | `UGRD_1hybridlevel` | None | False |
| **:VGRD:1 hybrid level:** | `VGRD_1hybridlevel` | None | False |
| **:TMP:1 hybrid level:**  | `TMP_1hybridlevel`  | None | False |
| **:SPFH:1 hybrid level:** | `SPFH_1hybridlevel` | where < 0 = 0. | False |
| **:TMP:2 m above ground:**   | `TMP_2maboveground`   | Used for `t2m` calc | False |
| **:SPFH:2 m above ground:**  | `SPFH_2maboveground`  | where < 0 = 0. | False |
| **:UGRD:10 m above ground:** | `UGRD_10maboveground` | None | False |
| **:VGRD:10 m above ground:** | `VGRD_10maboveground` | None | False |

Use [run_extract_gdas.sh](https://github.com/sanAkel/ufs-ocean/blob/main/scripts/run_extract_gdas.sh) to gather above variables.

---


# Indirectely mapped variables
| GRIB2 | NetCDF forcing file variable name | Name in `datm_datamode_gefs_mod.F90`  | Checks and/or changes | Avg forecast | 
| :---  | :--- | :--- | :--- | :-- |
| N/A                      | precp       | Faxa_rain | PRATE * (1-CPOFP*0.01) | True |
| N/A                      | fprecp      | Faxa_snow | PRATE *    CPOFP*0.01  | True |


| :ICEC:surface:  | ICEC_surface  | N/A       | N/A        | None                         | False | 
| :PRES:surface:           | ?? pres_hyblev1 | Sa_pbot    | None | False |
| :PRES:surface:           | ?? psurf        | Sa_pslv    | None | False |
| ??                       | hgt_hyblev1 | Sa_z      | Do ?? with HGT_1hybridlevel | False |

| GRIB2 variable name | wgrib2 to nc | DATM nc file | Name in `datm_datamode_gefs_mod.F90`  | Checks and/or changes | Avg forecast | 
| :---  | :--- | :--- | :--- | :--- | :-- |
| :LAND:surface:  | LAND_surface  | slmsksfc  | Sa_mask    | None                         | False |
| :PRES:surface:  | PRES_surface  | N/A       | N/A        | None                         | False |
| :TMP:surface:   | TMP_surface   | N/A       | N/A        | None                         | False |
| :DLWRF:surface: | DLWRF_surface | DLWRF     | Faxa_lwdn  | None. Conform sign           | True |
| :VBDSF:surface: | VBDSF_surface | vbdsf_ave | Faxa_swvdr | where < 0 = 0. Confirm sign  | True | 
| :VDDSF:surface: | VDDSF_surface | vddsf_ave | Faxa_swvdf | where < 0 = 0. Confirm sign  | True | 
| :NBDSF:surface: | NBDSF_surface | nbdsf_ave | Faxa_swndr | where < 0 = 0. Confirm sign  | True | 
| :NDDSF:surface: | NDDSF_surface | nddsf_ave | Faxa_swndf | where < 0 = 0. Confirm sign  | True | 
| :CPOFP:surface: | CPOFP_surface | N/A       | N/A        | Used to calculate partition of liquid/frozen precip | False |
| :PRATE:surface: | PRATE_surface | N/A       | N/A        | Total precip. where < 0 = 0. | True |
