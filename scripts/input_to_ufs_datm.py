#!/usr/bin/env python3

import xarray as xr
import argparse
import os
import sys

def load_individual_file(file_path, timestamp, index):
    """
    Opens a single NetCDF file and handles errors.
    """
    if not os.path.exists(file_path):
        print(f"  WARNING: File not found: {file_path}")
        return None

    print(f"[{index}] Opening: {timestamp} -> {os.path.basename(file_path)}")
    
    try:
        # Open individual dataset
        ds = xr.open_dataset(file_path)
        
        # if wgrib2 netcdf files lack a 'time' dimension,
        # concatenation will fail, then uncomment the lines below:
        # ds = ds.expand_dims('time')
        # ds = ds.assign_coords(time=[timestamp])
        
        # Load into memory to avoid 'too many open files' error during concat
        ds.load()

        return ds
    except Exception as e:
        print(f"  FAILED to open {file_path}: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Convert (GDAS/GFS) wgrib2 generated NetCDF (sflux) files to inputs for UFS DATM.")
    parser.add_argument("-i", "--input_list", required=True, 
                        help="Path to the ascii list file (e.g., rtofs_glo.20251229_20251231.listflx.nc.dat)")
    
    args = parser.parse_args()

    if not os.path.exists(args.input_list):
        print(f"FATAL ERROR: List file {args.input_list} not found.")
        sys.exit(1)

    # 1. Read ascii file that lists path to grib2 files
    datasets = []
    
    print(f"Reading file list from: {args.input_list}")
    
    with open(args.input_list, 'r') as f:
        lines = f.readlines()

    # 2. Iterate through each of the grib2 files
    for i, line in enumerate(lines):
        parts = line.split()
        
        # Skip header line (usually a single integer count)
        if len(parts) < 2:
            continue
            
        timestamp = parts[0]
        file_path = parts[1]

        # load each file 
        ds = load_individual_file(file_path, timestamp, i)
        
        if ds is not None:
            datasets.append(ds)

    # 3. Final Concatenation
    if datasets:
        print(f"\nConcatenating {len(datasets)} files...")
        combined = xr.concat(datasets, dim='time')
        print("Done.")
    else:
        print("No datasets were successfully loaded.")

if __name__ == "__main__":
    main()
