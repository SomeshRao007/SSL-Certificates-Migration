#!/bin/bash
# Extract certificates from acme.json - Fixed for your structure

ACME_FILE="/etc/cloudpepper/acme.json"
TEMP_DIR="/tmp/cert_migration"
mkdir -p "$TEMP_DIR"

# Extract account information from letsencrypt resolver
echo "Extracting account information..."
jq -r '.letsencrypt.Account.PrivateKey' "$ACME_FILE" > "$TEMP_DIR/account.key"
ACCOUNT_ID=$(jq -r '.letsencrypt.Account.Registration.uri' "$ACME_FILE" | grep -o '[0-9]*$')
echo "Found Account ID: $ACCOUNT_ID"

# Extract certificates
echo "Extracting certificates..."
for domain in $(jq -r '.letsencrypt.Certificates[].domain.main' "$ACME_FILE"); do
    echo "Processing domain: $domain"
    mkdir -p "$TEMP_DIR/$domain"
    
    # Extract certificate
    jq -r ".letsencrypt.Certificates[] | select(.domain.main==\"$domain\") | .certificate" "$ACME_FILE" | base64 -d > "$TEMP_DIR/$domain/cert.pem"
    
    # Extract private key (the key field should exist in your acme.json)
    jq -r ".letsencrypt.Certificates[] | select(.domain.main==\"$domain\") | .key" "$ACME_FILE" | base64 -d > "$TEMP_DIR/$domain/privkey.pem"
    
    # Extract full chain (using certificate as it contains the full chain)
    jq -r ".letsencrypt.Certificates[] | select(.domain.main==\"$domain\") | .certificate" "$ACME_FILE" | base64 -d > "$TEMP_DIR/$domain/fullchain.pem"
    
    echo "Created certificate files for $domain"
done

echo "Extraction complete. Files are in $TEMP_DIR"

# Verify the extraction
echo "Verifying extracted files..."
ls -la "$TEMP_DIR"
for dir in "$TEMP_DIR"/*/ ; do
    if [ -d "$dir" ]; then
        echo "Contents of $dir:"
        ls -la "$dir"
    fi
done
