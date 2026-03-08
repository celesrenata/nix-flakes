#!/usr/bin/env python3
# =============================================================================
# Full Package Comparison Script (10,000+ Packages)
# =============================================================================
# Compares ALL packages between current esnixi system and experimental build.
# Uses nix-store --query --requisites to get full dependency trees.
#
# Input Files:
#   - current_esnixi_full.txt    (10,479 packages from current esnixi)
#   - experimental_full.txt      (11,325 packages from experimental build)
#
# Output: /home/celes/sources/nix-flakes-experimental/full_package_comparison.csv
# Format: program-name,current-version,experimental-version,status
# =============================================================================

import re
from pathlib import Path
from collections import defaultdict

def parse_nix_path(nix_path: str) -> tuple[str, str]:
    """Parse Nix store path to extract name and version."""
    nix_path = nix_path.strip()
    
    # Match pattern: /nix/store/hash-name-version-hash or hash-name-version
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

def read_paths(filepath: Path) -> list[str]:
    """Read package paths from file."""
    try:
        with open(filepath, 'r') as f:
            return [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        print(f"ERROR: File not found: {filepath}")
        return []

def main():
    # Define paths
    current_esnixi_path = Path('/home/celes/sources/nix-flakes-experimental/current_esnixi_full.txt')
    exp_system_path = Path('/home/celes/sources/nix-flakes-experimental/experimental_full.txt')
    output_csv = Path('/home/celes/sources/nix-flakes-experimental/full_package_comparison.csv')
    
    print("=" * 70)
    print("FULL PACKAGE COMPARISON (10,000+ PACKAGES)")
    print("=" * 70)
    print()
    
    # Read package paths using --requisites approach
    current_paths = read_paths(current_esnixi_path)
    exp_paths = read_paths(exp_system_path)
    
    if not current_paths:
        print(f"ERROR: No packages found in {current_esnixi_path}")
        return
    
    if not exp_paths:
        print(f"ERROR: No packages found in {exp_system_path}")
        return
    
    print(f"✓ Loaded {len(current_paths)} current esnixi system paths")
    print(f"✓ Loaded {len(exp_paths)} experimental build paths")
    print()
    
    # Build lookup dictionaries (lowercase key -> original name, version)
    current_pkgs = defaultdict(list)
    exp_pkgs = defaultdict(list)
    
    for path in current_paths:
        name, version = parse_nix_path(path)
        if name and not any(x in name.lower() for x in ['systemd', 'glibc', 'linux-', 'initrd']):
            current_pkgs[name.lower()].append((name, version))
    
    for path in exp_paths:
        name, version = parse_nix_path(path)
        if name and not any(x in name.lower() for x in ['systemd', 'glibc', 'linux-', 'initrd']):
            exp_pkgs[name.lower()].append((name, version))
    
    print(f"✓ Indexed {len(current_pkgs)} current system packages")
    print(f"✓ Indexed {len(exp_pkgs)} experimental packages")
    print()
    
    # Create comparison data - match by program name
    rows = []
    matches = 0
    versions_diff = 0
    
    for key in exp_pkgs.keys():
        if key in current_pkgs:
            curr_name, curr_ver = current_pkgs[key][0]  # Take first match
            exp_name, exp_ver = exp_pkgs[key][0]       # Take first match
            
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
    print("COMPARISON RESULTS (FULL 10,000+ PACKAGES)")
    print("=" * 70)
    print()
    print(f"✓ CSV written to: {output_csv}")
    print(f"✓ Packages compared: {len(rows)}")
    print(f"✓ Same versions: {matches} ({matches*100//max(len(rows),1)}%)")
    print(f"✓ Different versions: {versions_diff} ({versions_diff*100//max(len(rows),1)}%)")
    
    # Print version differences (sample)
    if versions_diff > 0:
        print()
        print("=== SAMPLE VERSION DIFFERENCES ===")
        count = 0
        for row in rows:
            if "DIFFERENT" in row['status'] and count < 15:
                print(f"{row['program']}: current={row['current']}, experimental={row['experimental']}")
                count += 1
    
    print()
    print("=" * 70)

if __name__ == '__main__':
    main()
