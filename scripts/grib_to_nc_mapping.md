#
# Table of mapping variables from GFS (GRIB2) to UFS DATM (NetCDF) files
#
---

# How was it generated?
# 1. Start with the [ufs-weather-model](https://github.com/ufs-community/ufs-weather-model/blob/e68bc46fdcec881b8aed5e7fa1e9fbe6aa1cb7b7/tests/parm/datm.streams.IN#L15)
# 2. Then modify it based on what is actually used by [datm_datamode_gefs_mod.F90](https://github.com/NOAA-EMC/CDEPS/blob/9f53664ef2e607ad25d6b6c939f2eac9ec818ee6/datm/datm_datamode_gefs_mod.F90#L118-L156)

# Notes:
  - Most variables are mapped directly, i.e., GFS -> DATM.
  - A few of them need to calculated: TMP_SFC, PRATE, CPOFP.
  - [GFS pressure levels are defined here; see `HGT:1`.](https://www.emc.ncep.noaa.gov/gmb/wx24fy/misc/GFS127_profile/hyblev_gfsC128.txt)


# Directely mapped variables
| GRIB2 | NetCDF forcing file variable name | Name in `datm_datamode_gefs_mod.F90`  | Checks and/or changes | Avg forecast | 
| :--- | :--- | :--- | :--- | :-- |
| :LAND:surface:           | slmsksfc     | Sa_mask    | None | False |
| :HGT:1 hybrid level:     | hgt_hyblev1  | Sa_z       | None | False |
| :UGRD:1 hybrid level:    | ugrd_hyblev1 | Sa_u       | None | False |
| :VGRD:1 hybrid level:    | vgrd_hyblev1 | Sa_v       | None | False |
| :TMP:1 hybrid level:     | tmp_hyblev1  | Sa_tbot    | None | False |
| :PRES:1 hybrid level:    | pres_hyblev1 | Sa_pbot    | None | False |
| :SPFH:1 hybrid level:    | spfh_hyblev1 | Sa_shum    | where < 0 = 0. | False |
| :UGRD:10 m above ground: | u10m         | Sa_u10m    | None | False |
| :VGRD:10 m above ground: | v10m         | Sa_v10m    | None | False |
| :SPFH:2 m above ground:  | q2m          | Sa_q2m     | where <0 = 0. | False |
| PRES:surface             | psurf        | Sa_pslv    | None | False |
| DLWRF:surface            | DLWRF        | Faxa_lwdn  | None | False |
| VBDSF:surface            | vbdsf_ave    | Faxa_swvdr | where < 0 = 0. | True |
| VDDSF:surface            | vddsf_ave    | Faxa_swvdf | where < 0 = 0. | True |
| NBDSF:surface            | nbdsf_ave    | Faxa_swndr | where < 0 = 0. | True |
| NDDSF:surface            | nddsf_ave    | Faxa_swndf | where < 0 = 0. | True |

# Indirectely mapped variables
| GRIB2 | NetCDF forcing file variable name | Name in `datm_datamode_gefs_mod.F90`  | Checks and/or changes | Avg forecast | 
| :---  | :--- | :--- | :--- | :-- |
| :TMP:surface:          | N/A          | N/A        | None | False
| :TMP:2 m above ground: | t2m          | Sa_t2m     | where (TMP_SFC <= 271.35) t2m = 271.35 + t2m - TMP_SFC | False |
| PRATE:surface          | N/A          | N/A        | Total precip. where < 0 = 0. | True |
| CPOFP:surface          | N/A          | N/A        | Used to calculate partition of liquid/frozen precip |    
| N/A                    | precp        | Faxa_rain  | PRATE * (1-CPOFP*0.01) | True |
| N/A                    | frecp        | Faxa_snow  | PRATE *    CPOFP*0.01  | True |
