#!/usr/bin/env python3
# =============================================================================
# Package Version Comparison Script
# =============================================================================
# Compares packages between current esnixi system and experimental flake build.
# Outputs a CSV file with format: program-name,current-version,experimental-version,status
# 
# Usage: ./compare_packages.py
# Output: /home/celes/sources/nix-flakes-experimental/packages_comparison.csv
# =============================================================================

import re
from pathlib import Path

def parse_nix_path(nix_path: str) -> tuple[str, str]:
    """Parse Nix store path to extract name and version."""
    nix_path = nix_path.strip()
    
    # Match pattern: /nix/store/hash-name-version-hash or hash-name
    match = re.match(r'/nix/store/[0-9a-z]{32}-(.+)', nix_path)
    if not match:
        return "", ""
    
    pkg_part = match.group(1)
    
    # Split from right to get name and version (last segment is usually version)
    parts = pkg_part.rsplit('-', 2)
    if len(parts) >= 2:
        name = '-'.join(parts[:-1])
        version = parts[-1]
    else:
        name = pkg_part
        version = "unknown"
    
    # Clean common suffixes
    name = re.sub(r'(-env|-dev|-man|-bin|-lib|-doc|-tests)$', '', name)
    
    return name.strip(), version

def read_paths(filepath: str) -> list[str]:
    """Read package paths from file."""
    try:
        with open(filepath, 'r') as f:
            return [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"ERROR: File not found: {filepath}")
        return []

def main():
    # Define paths
    current_esnixi_path = Path('/home/celes/sources/nix-flakes-experimental/current_esnixi_pkg_paths.txt')
    exp_system_path = Path('/home/celes/sources/nix-flakes-experimental/experimental_system_packages.txt')
    output_csv = Path('/home/celes/sources/nix-flakes-experimental/packages_comparison.csv')
    
    print("=" * 70)
    print("PACKAGE VERSION COMPARISON SCRIPT")
    print("=" * 70)
    print()
    
    # Read package paths
    current_paths = read_paths(str(current_esnixi_path))
    exp_paths = read_paths(str(exp_system_path))
    
    if not current_paths:
        print(f"WARNING: No packages found in {current_esnixi_path}")
    else:
        print(f"Loaded {len(current_paths)} current esnixi system paths")
    
    if not exp_paths:
        print(f"WARNING: No packages found in {exp_system_path}")
    else:
        print(f"Loaded {len(exp_paths)} experimental build paths")
    
    print()
    
    # Build lookup dictionaries (lowercase key -> original name, version)
    current_pkgs = {}
    exp_pkgs = {}
    
    for path in current_paths:
        name, version = parse_nix_path(path)
        if name and not any(x in name.lower() for x in ['systemd', 'glibc', 'linux-', 'initrd']):
            current_pkgs[name.lower()] = (name, version)
    
    for path in exp_paths:
        name, version = parse_nix_path(path)
        if name and not any(x in name.lower() for x in ['systemd', 'glibc', 'linux-', 'initrd']):
            exp_pkgs[name.lower()] = (name, version)
    
    print(f"Indexed {len(current_pkgs)} current system packages")
    print(f"Indexed {len(exp_pkgs)} experimental packages")
    print()
    
    # Create comparison data
    rows = []
    matches = 0
    versions_diff = 0
    
    for key in exp_pkgs.keys():
        if key in current_pkgs:
            curr_name, curr_ver = current_pkgs[key]
            exp_name, exp_ver = exp_pkgs[key]
            
            status = "SAME" if curr_ver == exp_ver else f"DIFFERENT (current:{curr_ver},exp:{exp_ver})"
            rows.append({
                'program': curr_name,
                'current': curr_ver,
                'experimental': exp_ver,
                'status': status
            })
            
            if "SAME" in status:
                matches += 1
            else:
                versions_diff += 1
    
    # Write CSV file
    with open(output_csv, 'w') as f:
        f.write("program-name,current-version,experimental-version,status\n")
        for row in rows:
            f.write(f"{row['program']},{row['current']},{row['experimental']},{row['status']}\n")
    
    print("=" * 70)
    print("COMPARISON RESULTS")
    print("=" * 70)
    print()
    print(f"CSV written to: {output_csv}")
    print(f"Matches found: {matches}")
    print(f"Version differences: {versions_diff}")
    
    # Print version differences
    if versions_diff > 0:
        print()
        print("=== VERSION DIFFERENCES ===")
        for row in rows:
            if "DIFFERENT" in row['status']:
                print(f"{row['program']}: current={row['current']}, experimental={row['experimental']}")
    
    print()
    print("=" * 70)

if __name__ == '__main__':
    main()
