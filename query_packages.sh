#!/bin/bash
# =============================================================================
# Package Version Comparison Query Script
# =============================================================================
# Compare packages between current esnixi system and experimental flake build.
# 
# CSV Format: program-name,current-version,experimental-version,status
# Location: /home/celes/sources/nix-flakes-experimental/packages_comparison.csv
#
# Usage Examples:
#   ./query_packages.sh all          - Show ALL packages in comparison
#   ./query_packages.sh diff         - Show ONLY different versions
#   ./query_packages.sh same         - Show ONLY same versions  
#   ./query_packages.sh program X    - Info about specific package X
#   ./query_packages.sh stats        - Show comparison statistics
# =============================================================================

CSV_FILE="/home/celes/sources/nix-flakes-experimental/packages_comparison.csv"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "ERROR: CSV file not found at $CSV_FILE"
    echo "Please run the comparison script first to generate this file."
    exit 1
fi

# Function to show all packages
show_all() {
    echo "============================================================================="
    echo "ALL PACKAGES IN COMPARISON"
    echo "============================================================================="
    echo ""
    printf "%-30s %-20s %-20s %s\n" "PROGRAM NAME" "CURRENT VERSION" "EXPERIMENTAL VERSION" "STATUS"
    echo "--------------------------------------------------------------------------------"
    
    while IFS=',' read -r name current exp status; do
        if [ "$name" != "program-name" ]; then  # Skip header
            printf "%-30s %-20s %-20s %s\n" "$name" "$current" "$exp" "$status"
        fi
    done < "$CSV_FILE"
    
    echo ""
}

# Function to show only different versions
show_different() {
    echo "============================================================================="
    echo "PACKAGES WITH DIFFERENT VERSIONS"
    echo "============================================================================="
    echo ""
    printf "%-30s %-20s %-20s %s\n" "PROGRAM NAME" "CURRENT VERSION" "EXPERIMENTAL VERSION" "STATUS"
    echo "--------------------------------------------------------------------------------"
    
    grep ",DIFFERENT" "$CSV_FILE" | while IFS=',' read -r name current exp status; do
        printf "%-30s %-20s %-20s %s\n" "$name" "$current" "$exp" "$status"
    done
    
    echo ""
}

# Function to show only same versions
show_same() {
    echo "============================================================================="
    echo "PACKAGES WITH SAME VERSIONS"
    echo "============================================================================="
    echo ""
    printf "%-30s %-20s %-20s %s\n" "PROGRAM NAME" "CURRENT VERSION" "EXPERIMENTAL VERSION" "STATUS"
    echo "--------------------------------------------------------------------------------"
    
    grep ",SAME$" "$CSV_FILE" | while IFS=',' read -r name current exp status; do
        printf "%-30s %-20s %-20s %s\n" "$name" "$current" "$exp" "$status"
    done
    
    echo ""
}

# Function to show specific package info
show_program() {
    local program="$1"
    
    if [ -z "$program" ]; then
        echo "Usage: $0 program <package-name>"
        exit 1
    fi
    
    echo "============================================================================="
    echo "PACKAGE INFO: $program"
    echo "============================================================================="
    echo ""
    printf "%-30s %-20s %-20s %s\n" "PROGRAM NAME" "CURRENT VERSION" "EXPERIMENTAL VERSION" "STATUS"
    echo "--------------------------------------------------------------------------------"
    
    grep "^$program," "$CSV_FILE" | while IFS=',' read -r name current exp status; do
        printf "%-30s %-20s %-20s %s\n" "$name" "$current" "$exp" "$status"
    done
    
    if [ $(grep -c "^$program," "$CSV_FILE") -eq 0 ]; then
        echo "Package not found in comparison."
    fi
    
    echo ""
}

# Function to show statistics
show_stats() {
    local total=$(tail -n +2 "$CSV_FILE" | wc -l)
    local same=$(grep ",SAME$" "$CSV_FILE" | wc -l)
    local diff=$(grep ",DIFFERENT" "$CSV_FILE" | wc -l)
    
    echo "============================================================================="
    echo "COMPARISON STATISTICS"
    echo "============================================================================="
    echo ""
    echo "Total packages compared: $total"
    echo "Same versions:           $same"
    echo "Different versions:      $diff"
    echo ""
    
    if [ $total -gt 0 ]; then
        local same_pct=$((same * 100 / total))
        local diff_pct=$((diff * 100 / total))
        echo "Same version percentage: ${same_pct}%"
        echo "Different version pct:   ${diff_pct}%"
    fi
    
    echo ""
}

# Function to show help
show_help() {
    echo "============================================================================="
    echo "PACKAGE VERSION COMPARISON QUERY SCRIPT"
    echo "============================================================================="
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  all           - Show ALL packages in comparison"
    echo "  diff          - Show ONLY packages with DIFFERENT versions"
    echo "  same          - Show ONLY packages with SAME versions"
    echo "  program X     - Show info about specific package X (e.g., bash-interactive)"
    echo "  stats         - Show comparison statistics and percentages"
    echo "  help          - Show this help message"
    echo ""
    echo "CSV Location: $CSV_FILE"
    echo ""
}

# Main command processing
case "$1" in
    all)
        show_all
        ;;
    diff|DIFFERENT)
        show_different
        ;;
    same|SAME)
        show_same
        ;;
    program|PROGRAM)
        show_program "$2"
        ;;
    stats|STATS)
        show_stats
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        echo "ERROR: Unknown command '$1'"
        echo ""
        show_help
        exit 1
        ;;
esac

echo "============================================================================="
exit 0
