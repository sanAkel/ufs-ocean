#!/usr/bin/env python3
#==============================================================================
# Script: stage_gdas.py
# Purpose: Stage GDAS sflux GRIB2 files from HPSS, AWS, or NOMADS.
#==============================================================================
import subprocess
import datetime
import os
import shutil
import argparse
import glob

def stage_gdas(PDY, CYC, destination, platform, skip_f000=True, hpss_latency=2, aws_latency=1, nThreads=4):
    print(f"--- Execution Platform: {platform} ---")
    run_date = datetime.datetime.strptime(PDY, '%Y%m%d').date()
    today = datetime.date.today()
    days_old = (today - run_date).days

    can_use_hpss = platform in ["WCOSS", "URSA"]
    
    # Tier 1: HPSS (Deep Archive)
    if can_use_hpss and days_old >= hpss_latency and shutil.which('htar'):
        print(f"--- Attempting HPSS Retrieval for {PDY} ---")
        if stage_hpss(PDY, CYC, destination, skip_f000, nThreads): return True
        print("HPSS failed. Trying fallback...")

    # Tier 2: AWS (Recent Archive)
    if days_old >= aws_latency:
        print(f"--- Attempting AWS S3 Retrieval (3-Hourly) for {PDY} ---")
        if stage_aws(PDY, CYC, destination, skip_f000): return True

    # Tier 3: NOMADS (Real-time)
    print(f"--- Attempting NOMADS Retrieval (Hourly) for {PDY} ---")
    return stage_nomads(PDY, CYC, destination, skip_f000)

def stage_hpss(PDY, CYC, destination, skip_f000, nThreads):
    """Retrieves files and recursively flattens the structure."""
    year, month = PDY[:4], PDY[:6]
    tar_path = f"/NCEPPROD/hpssprod/runhistory/rh{year}/{month}/{PDY}/com_gfs_v16.3_gdas.{PDY}_{CYC}.gdas_flux.tar"
    
    start = 1 if skip_f000 else 0
    members = [f"./gdas.{PDY}/{CYC}/atmos/gdas.t{CYC}z.sfluxgrbf00{f}.grib2" for f in range(start, 10)]
    
    if not os.path.exists(destination): os.makedirs(destination)
    abs_dest = os.path.abspath(destination)
    curr_dir = os.getcwd()
    os.chdir(abs_dest)
    
    subprocess.run(["htar", "-T", str(nThreads), "-xvf", tar_path] + members)
    
    # Find all grib2 files and move to root of destination
    grib_files = glob.glob("**/*.grib2", recursive=True)
    if grib_files:
        for fpath in grib_files:
            fname = os.path.basename(fpath)
            if os.path.dirname(fpath) != "":
                shutil.move(fpath, os.path.join(abs_dest, fname))
        
        # Cleanup nested folders
        subdirs = [d for d in os.listdir('.') if os.path.isdir(d) and d.startswith('gdas.')]
        for d in subdirs:
            shutil.rmtree(d)
        os.chdir(curr_dir)
        return True
    
    os.chdir(curr_dir)
    return False

def stage_aws(PDY, CYC, destination, skip_f000):
    try:
        import boto3
        from botocore import UNSIGNED
        from botocore.config import Config
    except ImportError: return False

    bucket_name = "noaa-gfs-bdp-pds"
    prefix = f"gdas.{PDY}/{CYC}/atmos"
    hours = [3, 6, 9] if skip_f000 else [0, 3, 6, 9]
    
    if not os.path.exists(destination): os.makedirs(destination)
    s3 = boto3.client('s3', config=Config(signature_version=UNSIGNED))
    
    found = False
    for f in hours:
        fname = f"gdas.t{CYC}z.sfluxgrbf00{f}.grib2"
        try:
            s3.download_file(bucket_name, f"{prefix}/{fname}", os.path.join(destination, fname))
            print(f"AWS Downloaded: {fname}")
            found = True
        except: continue
    return found

def stage_nomads(PDY, CYC, destination, skip_f000):
    try: import requests
    except: return False
    base_url = f"https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gdas.{PDY}/{CYC}/atmos"
    hours = range(1, 10) if skip_f000 else range(0, 10)
    if not os.path.exists(destination): os.makedirs(destination)
    
    found = False
    for f in hours:
        fname = f"gdas.t{CYC}z.sfluxgrbf00{f}.grib2"
        target = os.path.join(destination, fname)
        r = requests.get(f"{base_url}/{fname}", stream=True, timeout=15)
        if r.status_code == 200:
            with open(target, 'wb') as f_out: shutil.copyfileobj(r.raw, f_out)
            print(f"NOMADS Downloaded: {fname}")
            found = True
    return found

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Stage GDAS GRIB2 files.")
    parser.add_argument("-p", "--pdy", required=True)
    parser.add_argument("-c", "--cyc", required=True)
    parser.add_argument("-o", "--out", required=True)
    parser.add_argument("--platform", required=True, 
                        choices=["WCOSS", "GAEA_C6", "URSA", "HERCULES", "ORION", "COLAB"])
    parser.add_argument("--keep_f000", action="store_true")
    args = parser.parse_args()

    success = stage_gdas(args.pdy, args.cyc, args.out, args.platform.upper(), 
                         skip_f000=(not args.keep_f000))
    if not success: exit(1)
