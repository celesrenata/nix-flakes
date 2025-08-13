#!/usr/bin/env bash
# Helper script to add the certificate to sops secrets

set -e

echo "Setting up certificate in sops secrets..."

# Check if home.crt exists
if [[ ! -f "home.crt" ]]; then
    echo "Error: home.crt not found in current directory"
    exit 1
fi

# Create a temporary file with the certificate content
TEMP_SECRETS=$(mktemp)
cat > "$TEMP_SECRETS" << EOF
# Encrypted secrets file
home_certificate: |
$(sed 's/^/  /' home.crt)

# Add more secrets as needed:
# api_keys:
#   github: "your_github_token"
#   aws_access_key: "your_aws_key"
EOF

echo "Certificate content prepared. Now encrypting with sops..."

# Encrypt the file with explicit age key
nix-shell -p sops --run "sops --config .sops.yaml -e '$TEMP_SECRETS' > secrets/secrets.yaml"

# Clean up
rm "$TEMP_SECRETS"

echo "✅ Certificate successfully encrypted and stored in secrets/secrets.yaml"
echo ""
echo "To edit the secrets file in the future, run:"
echo "  nix-shell -p sops --run 'sops secrets/secrets.yaml'"
echo ""
echo "To view the decrypted content (for debugging), run:"
echo "  nix-shell -p sops --run 'sops -d secrets/secrets.yaml'"
