# GDAS DATM Forcing Staging Toolkit

Tools to automate the staging of GDAS `sflux` (surface flux) GRIB2 files.
These files are typically used to generate atmospheric forcing for ocean models
within the UFS (Unified Forecast System) framework.

The toolkit is designed to be platform-agnostic, automatically switching 
between tape archives (HPSS), cloud storage (AWS S3), and 
real-time servers (NOMADS) based on availability and location.

---

## 1. Script Descriptions

### `stage_gdas.py`
The core Python utility that manages the retrieval of GRIB2 data.
* **Tiered Retrieval:** It attempts to find data in order: **HPSS** (Archive) -> **AWS S3** (Cloud) -> **NOMADS** (Live).
* **Directory Flattening:** When retrieving from HPSS (which uses a nested directory 
structure inside tarbundles), the script automatically extracts and flattens 
the files into the target directory to maintain a clean structure.
* **Hourly vs. 3-Hourly:** It prioritizes the full hourly forecast suite ($f001$ through $f006$) 
when available (HPSS/NOMADS), but falls back to 3-hourly subsets on AWS.

### `run_stage_gdas.sh`
A Bash driver script used to process long time series. 
* Loops through a user-defined date range ($START$ to $END$).
* Iterates through all four standard GDAS cycles ($00Z, 06Z, 12Z, 18Z$).
* Creates isolated output directories for each cycle within a specified base path.

### Example Usage:
- WCOSS: ` ./run_stage_gdas.sh 20250801 20250805 WCOSS /lfs/h2/emc/stmp/santha.akella/TEST_FORCING/`
- C6: `./run_stage_gdas.sh 20260101 20260102 GAEA_C6 /autofs/ncrc-svm1_proj/sfs-cpu/Santha.Akella/TEST2/`
- URSA: `./run_stage_gdas.sh 20250601 20250602 URSA /scratch5/NCEPDEV/rstprod/Santha.Akella/TEST/`
---

## 2. Requirements & Setup

| Platform | Recommended Source | Prerequisites |
| :--- | :--- | :--- |
| **WCOSS / URSA** | HPSS (Tape) | `module load hpss` |
| **GAEA_C6** | AWS S3 | Python `boto3` library |
| **COLAB** | AWS S3 | Drive mounted, `pip install boto3` |

**Note:** Ensure both scripts have execution permissions: `chmod +x stage_gdas.py run_stage_gdas.sh`

