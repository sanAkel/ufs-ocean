#!/usr/bin/env python3
#==============================================================================
# Script: stage_gdas.py
# Purpose: Stage GDAS sflux GRIB2 files and organize by Valid-Time for RTOFS.
#          Logic: Uses f001-f006 to ensure balanced flux accumulation.
#==============================================================================
import subprocess
import datetime
import os
import shutil
import argparse
import glob

def organize_for_rtofs(PDY, CYC, fhr, source_path, base_dest):
    """
    Calculates Valid-Time and moves file to YYYYMMDDHH/rtofs.filename.
    This ensures that f006 from the previous cycle correctly 
    provides the analysis-hour forcing.
    """
    cycle_dt = datetime.datetime.strptime(f"{PDY}{CYC}", '%Y%m%d%H')
    valid_dt = cycle_dt + datetime.timedelta(hours=fhr)

    # Create the directory for the valid time (YYYYMMDDHH)
    valid_dir = os.path.join(base_dest, valid_dt.strftime('%Y%m%d%H'))
    os.makedirs(valid_dir, exist_ok=True)

    # Define the final target path with 'rtofs.' prefix
    target_path = os.path.join(valid_dir, f"rtofs.{os.path.basename(source_path)}")

    shutil.move(source_path, target_path)
    print(f"   -> Staged to: {target_path}")

def stage_gdas(PDY, CYC, destination, platform, max_fhr=6, threads=4):
    print(f"--- Execution Platform: {platform} (Threads: {threads}) ---")
    run_date = datetime.datetime.strptime(PDY, '%Y%m%d').date()
    today = datetime.date.today()
    days_old = (today - run_date).days

    # Tier 1: HPSS (WCOSS/URSA)
    if platform in ["WCOSS", "URSA"] and days_old >= 2 and shutil.which('htar'):
        print(f"--- Attempting HPSS Retrieval for {PDY} ---")
        return stage_hpss(PDY, CYC, destination, max_fhr, threads)

    # Tier 2: AWS (GAEA_C6/COLAB)
    if days_old >= 1:
        print(f"--- Attempting AWS S3 Retrieval for {PDY} ---")
        return stage_aws(PDY, CYC, destination, max_fhr)

    # Tier 3: NOMADS (Live fallback)
    print(f"--- Attempting NOMADS Retrieval for {PDY} ---")
    return stage_nomads(PDY, CYC, destination, max_fhr)

def stage_hpss(PDY, CYC, destination, max_fhr, threads):
    year, month = PDY[:4], PDY[:6]
    tar = f"/NCEPPROD/hpssprod/runhistory/rh{year}/{month}/{PDY}/com_gfs_v16.3_gdas.{PDY}_{CYC}.gdas_flux.tar"
    
    # RTOFS convention: Skip f000, take f001 through f006
    f_hours = list(range(1, max_fhr + 1))
    members = [f"./gdas.{PDY}/{CYC}/atmos/gdas.t{CYC}z.sfluxgrbf00{f}.grib2" for f in f_hours]
    
    # Create a local temporary extraction directory
    tmp_extract = os.path.join(destination, f"tmp_extract_{PDY}{CYC}")
    os.makedirs(tmp_extract, exist_ok=True)
    curr_dir = os.getcwd()
    os.chdir(tmp_extract)
    
    # Run retrieval
    subprocess.run(["htar", "-T", str(threads), "-xvf", tar] + members)
    
    # Locate and organize the files
    for fpath in glob.glob("**/*.grib2", recursive=True):
        fname = os.path.basename(fpath)
        # Extract forecast hour from filename for valid-time calculation
        fhr_str = fname.split('grbf')[1].split('.')[0]
        fhr = int(fhr_str)
        organize_for_rtofs(PDY, CYC, fhr, fpath, destination)
    
    os.chdir(curr_dir)
    shutil.rmtree(tmp_extract)
    return True

def stage_aws(PDY, CYC, destination, max_fhr):
    try:
        import boto3
        from botocore import UNSIGNED
        from botocore.config import Config
    except ImportError: return False

    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    bucket = "noaa-gfs-bdp-pds"
    prefix = f"gdas.{PDY}/{CYC}/atmos"
    
    # AWS has f003 and f006
    found = False
    for f in [3, 6]:
        if f > max_fhr: continue
        fname = f"gdas.t{CYC}z.sfluxgrbf00{f}.grib2"
        tmp_local = os.path.join(destination, fname)
        try:
            s3.download_file(bucket, f"{prefix}/{fname}", tmp_local)
            organize_for_rtofs(PDY, CYC, f, tmp_local, destination)
            found = True
        except: continue
    return found

def stage_nomads(PDY, CYC, destination, max_fhr):
    try: import requests
    except: return False
    base_url = f"https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gdas.{PDY}/{CYC}/atmos"
    
    found = False
    for f in range(1, max_fhr + 1):
        fname = f"gdas.t{CYC}z.sfluxgrbf00{f}.grib2"
        tmp_local = os.path.join(destination, fname)
        r = requests.get(f"{base_url}/{fname}", stream=True, timeout=20)
        if r.status_code == 200:
            with open(tmp_local, 'wb') as f_out:
                shutil.copyfileobj(r.raw, f_out)
            organize_for_rtofs(PDY, CYC, f, tmp_local, destination)
            found = True
    return found

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Stage GDAS for RTOFS.")
    parser.add_argument("-p", "--pdy", required=True, help="YYYYMMDD")
    parser.add_argument("-c", "--cyc", required=True, help="Cycle HH")
    parser.add_argument("-o", "--out", required=True, help="Base output directory")
    parser.add_argument("--platform",  required=True, help="Choices: WCOSS, GAEA_C6, URSA, COLAB")
    parser.add_argument("--max_fhr", type=int, default=6, help="Max forecast hour to stage")
    parser.add_argument("--threads", type=int, default=4, help="Number of parallel threads")

    args = parser.parse_args()

    # Ensure platform name is standardized for logic checks
    success = stage_gdas(args.pdy, args.cyc, args.out, args.platform.upper(), args.max_fhr, args.threads)
    if not success: exit(1)
