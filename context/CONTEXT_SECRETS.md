# Secrets Management and Security Context

## secrets.nix - SOPS Configuration

### Purpose
Encrypted secrets management using SOPS (Secrets OPerationS) with age/SSH key encryption for secure configuration storage.

### Current Status
**TEMPORARILY DISABLED** due to symlink conflict issue. The system works perfectly without this - it's only needed for certificate management.

### Configuration Structure
```nix
sops = {
  defaultSopsFile = ./secrets/secrets.yaml;     # Encrypted secrets file
  validateSopsFiles = false;                    # Skip validation during build
  age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];  # Decryption key
  secrets = {
    "home_certificate" = {
      path = "/run/secrets/home.crt";           # Runtime secret location
      owner = "root";                           # File ownership
      group = "root";
      mode = "0400";                            # Read-only permissions
    };
  };
};
```

### How SOPS Works
1. **Encryption**: Secrets encrypted with SSH host keys or age keys
2. **Storage**: Encrypted files safely stored in git repository
3. **Decryption**: Automatic decryption at runtime using host keys
4. **Access**: Secrets available at `/run/secrets/` during system operation

## secrets/ - Encrypted Storage

### secrets.yaml
Encrypted YAML file containing sensitive configuration data:
- **Certificates**: SSL/TLS certificates for services
- **API keys**: Service authentication tokens
- **Passwords**: Service passwords and credentials
- **Private keys**: Cryptographic private keys

### Security Features
- **Age encryption**: Modern, secure encryption algorithm
- **SSH key integration**: Uses existing SSH infrastructure
- **Git-safe**: Encrypted files can be committed to version control
- **Automatic rotation**: Keys can be rotated without manual intervention

## .sops.yaml - SOPS Configuration

### Purpose
SOPS configuration file that defines encryption keys and file patterns.

### Configuration Elements
- **Keys**: SSH public keys and age keys for encryption/decryption
- **Creation rules**: Which keys to use for new secrets
- **Path matching**: Different keys for different file paths
- **Key groups**: Multiple keys for redundancy

## setup-certificate.sh - Certificate Management

### Purpose
Script for setting up SSL/TLS certificates, likely for local services or development.

### Functionality
- **Certificate generation**: Creates self-signed or CA certificates
- **Installation**: Places certificates in correct system locations
- **Permission setting**: Ensures proper file permissions
- **Service integration**: Configures services to use certificates

## Security Architecture

### Key Management
- **SSH host keys**: Automatically generated during installation
- **Age keys**: Modern encryption keys for SOPS
- **Key backup**: SSH host keys backed up for disaster recovery
- **Key rotation**: Process for updating encryption keys

### Access Control
- **File permissions**: Strict permissions on secret files
- **User isolation**: Secrets only accessible to authorized users/services
- **Runtime decryption**: Secrets decrypted only when needed
- **Memory protection**: Secrets cleared from memory when not in use

### Threat Model
- **At-rest encryption**: Secrets encrypted in git repository
- **In-transit protection**: Secure key exchange and distribution
- **Access logging**: Audit trail for secret access
- **Compromise recovery**: Process for handling key compromise

## Current Issues and Workarounds

### Symlink Conflict
- **Issue**: "cannot rename ... file exists" error during secret deployment
- **Impact**: Certificate deployment fails, but system remains functional
- **Workaround**: Manual certificate management or alternative deployment
- **Status**: Under investigation, system works without SOPS

### Alternative Security
- **Manual secrets**: Direct file placement for critical secrets
- **Environment variables**: Runtime secret injection
- **External secret management**: Integration with external secret stores
- **Service-specific**: Individual service secret management

## Future Improvements
- **Fix symlink issue**: Resolve SOPS deployment conflict
- **External integration**: HashiCorp Vault or similar integration
- **Automated rotation**: Automatic key and secret rotation
- **Monitoring**: Secret access monitoring and alerting
