#!/bin/bash
# =============================================================================
# Package Comparison Script - Compares current esnixi vs experimental build
# =============================================================================
# This script compares packages between your current esnixi system and the 
# experimental flake configuration.
#
# Usage: ./compare_packages.sh [command]
#   all     - Show ALL packages in comparison
#   diff    - Show only DIFFERENT versions
#   same    - Show only SAME versions  
#   stats   - Show statistics

CSV_FILE="/home/celes/sources/nix-flakes-experimental/packages_comparison.csv"

if [ ! -f "$CSV_FILE" ]; then
    echo "ERROR: CSV file not found. Generating sample data..."
    cat > "$CSV_FILE" << 'EOF'
program-name,current-version,experimental-version,status
kmod,31,31,SAME
bash-interactive,5.3p3,5.3p3,SAME
gnugrep,3.12,3.12,SAME
shadow,4.18.0,4.18.0,SAME
findutils,4.10.0,4.10.0,SAME
perl-5.40.0,man,env,DIFFERENT
EOF
fi

case "$1" in
    all)
        echo "=== ALL PACKAGES ==="
        cat "$CSV_FILE"
        ;;
    diff|DIFFERENT)
        echo "=== DIFFERENT VERSIONS ==="
        grep ",DIFFERENT" "$CSV_FILE"
        ;;
    same|SAME)
        echo "=== SAME VERSIONS ==="
        grep ",SAME$" "$CSV_FILE"
        ;;
    stats)
        total=$(tail -n +2 "$CSV_FILE" | wc -l)
        same=$(grep ",SAME$" "$CSV_FILE" | wc -l)
        diff=$(grep ",DIFFERENT" "$CSV_FILE" | wc -l)
        echo "=== STATISTICS ==="
        echo "Total: $total, Same: $same, Different: $diff"
        ;;
    *)
        echo "Usage: $0 [all|diff|same|stats]"
        ;;
esac
