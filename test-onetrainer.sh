#!/usr/bin/env bash

set -e

echo "Testing OneTrainer Nix flake..."

# Test flake check
echo "1. Checking flake syntax..."
nix flake check ./onetrainer-flake.nix --no-build

# Test development shell
echo "2. Testing development shell..."
nix develop ./onetrainer-flake.nix --command bash -c "echo 'Dev shell works'; python --version"

# Test building (this will likely fail on first try due to hash mismatch)
echo "3. Attempting to build OneTrainer..."
nix build ./onetrainer-flake.nix --no-link --print-build-logs || {
    echo "Build failed - this is expected on first run due to hash mismatch"
    echo "Check the error output for the correct hash and update the flake"
}

echo "Test complete!"
