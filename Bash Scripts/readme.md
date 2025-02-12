# SSL Certificate Migration Scripts

## Overview
This collection of bash scripts facilitates the migration of SSL certificates from Traefik's `acme.json` format to Certbot's directory structure. The scripts handle the extraction, conversion, and proper setup of certificates while maintaining the correct file permissions and directory structure.

## Prerequisites

### Required Software
- `jq` (for JSON parsing)
- `openssl` (for certificate operations)
- `python3` with the following modules:
  - `cryptography`
- `base64` (usually pre-installed)
- `curl` (for downloading intermediate certificates)

### Required Permissions
- Root access or sudo privileges
- Read access to `/etc/cloudpepper/acme.json`
- Write access to `/etc/letsencrypt/` directory

## Script Details

### 1. Extract Certificates (`1_Extract_certificates.sh`)
- Extracts certificates and keys from Traefik's `acme.json`
- Creates a temporary directory structure with extracted files
- Handles base64 decoding of certificates and keys
- Preserves domain information and certificate chains

### 2. Setup Certbot Structure (`2_Setup_certbot_structure.sh`)
- Sets up the Certbot directory structure
- Converts account keys to the format required by Certbot
- Creates necessary directory hierarchies
- Establishes the live and archive directory structure
- Sets up symbolic links for certificate files

### 3. Set Correct Permissions (`3_set_correct_permissions.sh`)
- Sets appropriate ownership and permissions for all files
- Secures private keys with restricted permissions
- Ensures proper access rights for Certbot operations
- Creates and configures renewal configuration files
- Sets up account metadata

### 4. Fix Missing Chain (`4_fix_missing_chain.sh`)
- Handles missing chain certificate files
- Extracts intermediate certificates from fullchain certificates
- Downloads Let's Encrypt R3 intermediate certificate if needed
- Rebuilds certificate chains with proper structure

## Usage

1. Place all scripts in a directory with execute permissions
2. Run the scripts in numerical order:

```bash
sudo ./1_Extract_certificates.sh
sudo ./2_Setup_certbot_structure.sh
sudo ./3_set_correct_permissions.sh
sudo ./4_fix_missing_chain.sh
```

## File Structure

### Input
- `/etc/cloudpepper/acme.json` - Traefik's certificate storage

### Temporary Files
- `/tmp/cert_migration/` - Temporary directory for certificate extraction
  - `account.key` - Extracted account key
  - `<domain>/` - Directory for each domain
    - `cert.pem` - Domain certificate
    - `privkey.pem` - Private key
    - `fullchain.pem` - Full certificate chain

### Output
- `/etc/letsencrypt/` - Certbot's certificate storage
  - `live/` - Symlinks to current certificates
  - `archive/` - Certificate storage
  - `renewal/` - Renewal configuration
  - `accounts/` - Account information

## Important Notes

1. **Backup**: Always backup your `acme.json` file before running these scripts
2. **Permissions**: Scripts must be run as root or with sudo
3. **Order**: Scripts must be executed in the correct numerical order
4. **Verification**: After migration, verify certificate paths and permissions
5. **Compatibility**: Scripts are designed for Let's Encrypt certificates managed by Traefik

## Troubleshooting

### Common Issues
1. **Permission Denied**: Ensure you're running scripts with sudo
2. **Missing Files**: Verify acme.json exists and is readable
3. **Conversion Errors**: Check Python dependencies are installed
4. **Chain Issues**: Ensure internet connectivity for downloading intermediate certificates

### Error Resolution
- Check script logs for detailed error messages
- Verify all prerequisites are installed
- Ensure proper file permissions on source files
- Confirm internet connectivity for chain certificate downloads