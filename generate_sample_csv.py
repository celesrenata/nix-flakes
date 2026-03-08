#!/usr/bin/env python3
# =============================================================================
# Package Version Comparison Script (Sample Data)
# =============================================================================
# This script generates a CSV file comparing packages between current esnixi 
# system and experimental flake build. Uses sample data for demonstration.
#
# Output: /home/celes/sources/nix-flakes-experimental/packages_comparison.csv
# Format: program-name,current-version,experimental-version,status
# =============================================================================

def main():
    # Sample package comparison data based on actual analysis
    packages = [
        {'program': 'kmod', 'current': '31', 'experimental': '31'},
        {'program': 'bash-interactive', 'current': '5.3p3', 'experimental': '5.3p3'},
        {'program': 'gnugrep', 'current': '3.12', 'experimental': '3.12'},
        {'program': 'shadow', 'current': '4.18.0', 'experimental': '4.18.0'},
        {'program': 'findutils', 'current': '4.10.0', 'experimental': '4.10.0'},
        {'program': 'perl-5.40.0', 'current': 'man', 'experimental': 'env'},
    ]
    
    # Write CSV file
    output_file = '/home/celes/sources/nix-flakes-experimental/packages_comparison.csv'
    
    with open(output_file, 'w') as f:
        # Write header
        f.write("program-name,current-version,experimental-version,status\n")
        
        # Write data rows
        for pkg in packages:
            status = "SAME" if pkg['current'] == pkg['experimental'] else "DIFFERENT"
            f.write(f"{pkg['program']},{pkg['current']},{pkg['experimental']},{status}\n")
    
    print("=" * 70)
    print("PACKAGE COMPARISON CSV GENERATED")
    print("=" * 70)
    print()
    print(f"Output file: {output_file}")
    print()
    print("CSV Content:")
    print("-" * 70)
    
    with open(output_file, 'r') as f:
        for line in f:
            print(line.strip())
    
    print("-" * 70)
    print()
    print("=" * 70)

if __name__ == '__main__':
    main()
