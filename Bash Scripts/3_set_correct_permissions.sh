#!/bin/bash
# Set correct permissions for Certbot files

# Define the Traefik acme.json file location (as used in extraction)
ACME_FILE="/etc/cloudpepper/acme.json"
CERTBOT_DIR="/etc/letsencrypt"

# Extract the Account ID from the registration URI in acme.json.
# This assumes the URI ends with the numeric account ID.
ACCOUNT_ID=$(jq -r '.letsencrypt.Account.Registration.uri' "$ACME_FILE" | grep -o '[0-9]*$')
ACCOUNT_DIR="$CERTBOT_DIR/accounts/acme-v02.api.letsencrypt.org/directory/$ACCOUNT_ID"

echo "Setting directory permissions..."

# Set permissions on the main Certbot directories.
chmod 755 "$CERTBOT_DIR"
chmod 755 "$CERTBOT_DIR/live"
chmod 755 "$CERTBOT_DIR/archive"
chmod -R 755 "$CERTBOT_DIR/renewal"

echo "Setting account directory permissions..."
# Set permissions for the account directory and its files.
chmod 700 "$ACCOUNT_DIR"
chmod 600 "$ACCOUNT_DIR/private_key.json"
chmod 600 "$ACCOUNT_DIR/regr.json"

echo "Creating meta.json if it does not exist..."
META_FILE="$ACCOUNT_DIR/meta.json"
if [ ! -f "$META_FILE" ]; then
    creation_dt=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    creation_host=$(hostname -f)
    cat > "$META_FILE" <<EOF
{
  "creation_dt": "$creation_dt",
  "creation_host": "$creation_host",
  "registration": {
    "body": {
      "status": "valid",
      "contact": []
    },
    "uri": "https://acme-v02.api.letsencrypt.org/acme/acct/$ACCOUNT_ID"
  },
  "account": "$ACCOUNT_ID"
}
EOF
    chmod 600 "$META_FILE"
    echo "Created meta.json for account $ACCOUNT_ID."
fi

echo "Setting certificate file permissions..."
for domain_dir in "$CERTBOT_DIR/live"/*/ ; do
    if [ -d "$domain_dir" ]; then
        domain=$(basename "$domain_dir")
        echo "Setting permissions for domain: $domain"
        chmod 755 "$CERTBOT_DIR/archive/$domain"
        chmod 600 "$CERTBOT_DIR/archive/$domain"/*.pem
        chmod 755 "$CERTBOT_DIR/live/$domain"
    fi
done

echo "Creating renewal configuration..."
for domain_dir in "$CERTBOT_DIR/live"/*/ ; do
    if [ -d "$domain_dir" ]; then
        domain=$(basename "$domain_dir")
        mkdir -p "$CERTBOT_DIR/renewal"
        cat > "$CERTBOT_DIR/renewal/$domain.conf" <<EOF
# renew_before_expiry = 30 days
version = 2.1.0
archive_dir = $CERTBOT_DIR/archive/$domain
cert = $CERTBOT_DIR/live/$domain/cert.pem
privkey = $CERTBOT_DIR/live/$domain/privkey.pem
chain = $CERTBOT_DIR/live/$domain/chain.pem
fullchain = $CERTBOT_DIR/live/$domain/fullchain.pem

[renewalparams]
account = $ACCOUNT_ID
authenticator = webroot
server = https://acme-v02.api.letsencrypt.org/directory
EOF
        chmod 600 "$CERTBOT_DIR/renewal/$domain.conf"
    fi
done

echo "Permission setting complete"
