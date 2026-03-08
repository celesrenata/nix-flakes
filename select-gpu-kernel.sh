#!/bin/bash
# GPU & Kernel Selection Script
# Supports NVIDIA/AMD GPUs and kernels 6.12, 6.18, 6.19, latest

CONFIG_FILE="/home/celes/sources/nix-flakes-experimental/esnixi/gpu-kernel-flags.nix"

case "${1:-show}" in
    nvidia)
        sed -i 's/enableNVIDIA = .*/enableNVIDIA = true;/' "$CONFIG_FILE"
        sed -i 's/enableROCM = .*/enableROCM = false;/' "$CONFIG_FILE"
        echo "✓ Set to NVIDIA GPU support"
        ;;
    rocm)
        sed -i 's/enableNVIDIA = .*/enableNVIDIA = false;/' "$CONFIG_FILE"
        sed -i 's/enableROCM = .*/enableROCM = true;/' "$CONFIG_FILE"
        echo "✓ Set to AMD ROCm support"  
        ;;
    latest)
        sed -i 's/kernelVersion = ".*/kernelVersion = "latest";/' "$CONFIG_FILE"
        echo "✓ Set to Linux 6.19+ (latest)"
        ;;
    "6_12")
        sed -i 's/kernelVersion = ".*/kernelVersion = "6_12";/' "$CONFIG_FILE"
        echo "✓ Set to Linux 6.12"
        ;;
    "6_18")
        sed -i 's/kernelVersion = ".*/kernelVersion = "6_18";/' "$CONFIG_FILE"
        echo "✓ Set to Linux 6.18"
        ;;
    "6_19")
        sed -i 's/kernelVersion = ".*/kernelVersion = "6_19";/' "$CONFIG_FILE"
        echo "✓ Set to Linux 6.19"
        ;;
    show|"") 
        echo "=== Current Configuration ==="
        grep -E "enableNVIDIA|enableROCM|kernelVersion" "$CONFIG_FILE" 2>/dev/null | head -3
        echo ""
        echo "Usage:"
        echo "  ./select-gpu-kernel.sh nvidia          # NVIDIA GPU (default)"
        echo "  ./select-gpu-kernel.sh rocm            # AMD ROCm support"
        echo "  ./select-gpu-kernel.sh latest          # Linux latest kernel"
        echo "  ./select-gpu-kernel.sh 6_12            # Linux 6.12 kernel"
        echo "  ./select-gpu-kernel.sh 6_18            # Linux 6.18 kernel"
        echo "  ./select-gpu-kernel.sh 6_19            # Linux 6.19 kernel (default)"
        echo ""
        ;;
    *) 
        echo "Unknown option: $1"
        echo "Use: nvidia, rocm, latest, 6_12, 6_18, or 6_19"
        ;;
esac
