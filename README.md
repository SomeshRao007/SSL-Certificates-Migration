# Ansible Role: Traefik to Certbot Certificate Migration

This Ansible role facilitates the migration of SSL certificates from Traefik's ACME storage to Certbot's directory structure. It handles the extraction, conversion, and proper setup of certificates while maintaining all necessary metadata and permissions.

## Requirements

- Python 3.x
- Ansible 2.1 or higher
- Required Python packages:
  - cryptography
  - pyOpenSSL
- System requirements:
  - openssl
  - curl

## Role Variables

The role primarily works with Traefik's ACME configuration file and doesn't require many variables to be set. However, you can customize the following paths if needed:

```yaml
# defaults/main.yml
acme_file_path: "/etc/cloudpepper/acme.json"  # Path to Traefik's ACME file
certbot_dir: "/etc/letsencrypt"               # Certbot's root directory
temp_migration_dir: "/tmp/cert_migration"      # Temporary directory for migration
```

## Dependencies

This role has no external dependencies on other Ansible roles.

## Directory Structure

```
certificates_migration/
├── defaults/
│   └── main.yml
├── tasks/
│   ├── main.yml                     # Main task file
│   ├── 1_extract_certs.yml          # Certificate extraction tasks
│   ├── 2_setup_certbot_dir.yml      # Certbot directory setup
│   ├── 3_set_permissions.yml        # Permission configuration
│   ├── 4_set_chain_files.yml        # Chain file setup
│   └── files/
│       ├── domain_chain_tasks.yml   # Domain-specific chain tasks
│       ├── domain_permissions.yml   # Domain-specific permissions
│       ├── loop_extract_cert.yml    # Certificate extraction loop
│       ├── process_domain_certs.yml # Certbot setup loop
│       └── renewal_config.yml       # Renewal configuration tasks
```

## Role Tasks Overview

1. **main.yml**: Orchestrates the entire migration process by including other task files in sequence.
2. **1_extract_certs.yml**: Extracts certificates from Traefik's ACME storage.
3. **2_setup_certbot_dir.yml**: Sets up Certbot's directory structure and converts keys.
4. **3_set_permissions.yml**: Configures proper permissions for all certificate files.
5. **4_set_chain_files.yml**: Handles certificate chain files and symlinks.


## Example Playbook

```yaml
- hosts: servers
  become: yes
  roles:
    - role: certificates_migration
```

## Usage

1. Ensure your Traefik ACME file exists at the specified path.
2. Run the playbook:
   ```bash
   ansible all -i <IP>, -u root -b -m include_role -a name=certificates_migration
   ```

3. Verify the migration:
   ```bash
   certbot certificates
   ```
      ```bash
   certbot show_account
   ```

## Task Flow
```
1. INITIALIZATION (main.yml)
   ├── Create temporary directory (/tmp/cert_migration)
   ├── Read Traefik's acme.json file
   ├── Parse acme.json content
   ├── Extract account key
   └── Extract Account ID from registration URI

2. CERTIFICATE EXTRACTION (1_extract_certs.yml)
   ├── Set certificate list from acme.json
   └── For each certificate:
       ├── Create domain-specific directory
       ├── Write cert.pem
       ├── Write privkey.pem
       └── Write fullchain.pem

3. CERTBOT DIRECTORY SETUP (2_setup_certbot_dir.yml)
   ├── Create base Certbot directories
   ├── Convert account key to JWK format using Python
   ├── Save converted account key
   ├── Create account registration file
   └── For each domain:
       ├── Create live and archive directories
       ├── Extract leaf certificate
       ├── Copy private key
       ├── Copy fullchain certificate
       └── Create certificate symlinks

4. PERMISSION CONFIGURATION (3_set_permissions.yml)
   ├── Get list of domains from /etc/letsencrypt/live
   ├── Create renewal directory
   ├── Set main directory permissions
   ├── For each domain:
       ├── Set archive directory permissions
       ├── Set PEM file permissions
       └── Set live directory permissions
   ├── Configure account directory permissions
   ├── Create meta.json if not exists
   └── For each domain:
       └── Create renewal configuration

5. CHAIN FILE SETUP (4_set_chain_files.yml)
   ├── Find live domain directories
   └── For each domain:
       ├── Extract chain1.pem from fullchain1.pem
       ├── Check if chain1.pem is empty
       ├── Download Let's Encrypt R3 intermediate if needed
       ├── Rebuild fullchain1.pem
       ├── Create chain.pem symlink
       └── Set chain1.pem permissions
```
## Common Issues and Solutions

1. **Python Cryptography Module Missing**
   ```bash
   pip3 install cryptography
   ```

2. **Permission Denied Errors**
   - Ensure the playbook is run with sufficient privileges (become: yes)
   - Check SELinux context if applicable

3. **Invalid Certificate Chain**
   - The role automatically downloads the Let's Encrypt R3 intermediate if needed
   - Verify chain files manually using:
     ```bash
     openssl verify -CAfile chain.pem cert.pem
     ```

## Author Information

Somesh Rao Coka

