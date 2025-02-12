#!/bin/bash
# Fix missing chain.pem files

CERTBOT_DIR="/etc/letsencrypt"

for domain_dir in "$CERTBOT_DIR/live"/*/ ; do
    if [ -d "$domain_dir" ]; then
        domain=$(basename "$domain_dir")
        echo "Fixing chain.pem for domain: $domain"

        # Try to extract the second certificate from fullchain1.pem
        awk '
        BEGIN {c=0}
        /BEGIN CERTIFICATE/{c++}
        {if(c==2) {print}}
        /END CERTIFICATE/{if(c==2) exit}
        ' "$CERTBOT_DIR/archive/$domain/fullchain1.pem" > "$CERTBOT_DIR/archive/$domain/chain1.pem"

        # If chain1.pem is empty, download the intermediate certificate
        if [ ! -s "$CERTBOT_DIR/archive/$domain/chain1.pem" ]; then
            echo "No intermediate certificate found; downloading Let's Encrypt R3 intermediate..."
            curl -s -o "$CERTBOT_DIR/archive/$domain/chain1.pem" https://letsencrypt.org/certs/letsencrypt-r3.pem
        fi

        # Rebuild fullchain1.pem as cert1.pem concatenated with chain1.pem
        cat "$CERTBOT_DIR/archive/$domain/cert1.pem" "$CERTBOT_DIR/archive/$domain/chain1.pem" > "$CERTBOT_DIR/archive/$domain/fullchain1.pem"

        # Create symlink in live directory
        ln -sf "../../archive/$domain/chain1.pem" "$CERTBOT_DIR/live/$domain/chain.pem"
        chmod 600 "$CERTBOT_DIR/archive/$domain/chain1.pem"
    fi
done

echo "Chain files created and linked"

