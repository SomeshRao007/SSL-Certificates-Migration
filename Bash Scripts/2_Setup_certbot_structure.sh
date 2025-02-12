#!/bin/bash
set -e

# Define paths
ACME_FILE="/etc/cloudpepper/acme.json"
TEMP_DIR="/tmp/cert_migration"
CERTBOT_DIR="/etc/letsencrypt"

# Extract the Account ID from the registration URI in acme.json.
# The account ID is assumed to be the trailing numeric portion of the URI.
ACCOUNT_ID=$(jq -r '.letsencrypt.Account.Registration.uri' "$ACME_FILE" | grep -o '[0-9]*$')
if [ -z "$ACCOUNT_ID" ]; then
  echo "Error: Could not extract ACCOUNT_ID from $ACME_FILE"
  exit 1
fi

# Define the account directory where Certbot expects to find account info.
ACCOUNT_DIR="$CERTBOT_DIR/accounts/acme-v02.api.letsencrypt.org/directory/$ACCOUNT_ID"

echo "Setting up certbot directory structure..."
mkdir -p "$CERTBOT_DIR/live" "$CERTBOT_DIR/archive" "$ACCOUNT_DIR"

echo "Converting account key to JWK format..."
# Use a bash heredoc to run a Python3 snippet that loads the full private key and outputs a JWK
jwk=$(python3 <<'EOF'
import json, base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')

with open("/tmp/cert_migration/account.key", "rb") as f:
    data = f.read()

# If the data is not PEM-formatted, assume it is base64 encoded and decode it.
if b"BEGIN" not in data:
    try:
        data = base64.b64decode(data)
    except Exception as e:
        raise ValueError("Failed to base64-decode account key data") from e

# Try loading the key as PEM; if that fails, try DER.
try:
    key = serialization.load_pem_private_key(data, password=None, backend=default_backend())
except ValueError:
    key = serialization.load_der_private_key(data, password=None, backend=default_backend())

# Extract full RSA private key numbers
numbers = key.private_numbers()
pub_numbers = numbers.public_numbers
n_int = pub_numbers.n
e_int = pub_numbers.e
d_int = numbers.d
p_int = numbers.p
q_int = numbers.q
dp_int = numbers.dmp1
dq_int = numbers.dmq1
qi_int = numbers.iqmp

jwk = {
    "kty": "RSA",
    "n": b64url(n_int.to_bytes((n_int.bit_length() + 7) // 8, 'big')),
    "e": b64url(e_int.to_bytes((e_int.bit_length() + 7) // 8, 'big')),
    "d": b64url(d_int.to_bytes((d_int.bit_length() + 7) // 8, 'big')),
    "p": b64url(p_int.to_bytes((p_int.bit_length() + 7) // 8, 'big')),
    "q": b64url(q_int.to_bytes((q_int.bit_length() + 7) // 8, 'big')),
    "dp": b64url(dp_int.to_bytes((dp_int.bit_length() + 7) // 8, 'big')),
    "dq": b64url(dq_int.to_bytes((dq_int.bit_length() + 7) // 8, 'big')),
    "qi": b64url(qi_int.to_bytes((qi_int.bit_length() + 7) // 8, 'big'))
}
print(json.dumps(jwk))
EOF
)

if [ -z "$jwk" ]; then
  echo "Error: Failed to convert account key to JWK format."
  exit 1
fi

echo "Saving converted account key to $ACCOUNT_DIR/private_key.json"
echo "$jwk" > "$ACCOUNT_DIR/private_key.json"

echo "Creating account registration file..."
cat > "$ACCOUNT_DIR/regr.json" <<EOF
{
  "body": {
    "status": "valid",
    "contact": [],
    "key": $jwk,
    "creation_host": "$(hostname -f)"
  },
  "uri": "https://acme-v02.api.letsencrypt.org/acme/acct/$ACCOUNT_ID"
}
EOF

echo "Setting up certificates for each domain..."
# For each domain extracted into /tmp/cert_migration, create archive and live directories
for domain_dir in "$TEMP_DIR"/*/ ; do
    if [ -d "$domain_dir" ]; then
        domain=$(basename "$domain_dir")
        echo "Processing domain: $domain"
        mkdir -p "$CERTBOT_DIR/live/$domain" "$CERTBOT_DIR/archive/$domain"
        
        # Extract the leaf certificate (first certificate from fullchain.pem)
        openssl x509 -in "$domain_dir/fullchain.pem" -out "$CERTBOT_DIR/archive/$domain/cert1.pem"
        
        # Copy the private key and fullchain as provided
        cp "$domain_dir/privkey.pem" "$CERTBOT_DIR/archive/$domain/privkey1.pem"
        cp "$domain_dir/fullchain.pem" "$CERTBOT_DIR/archive/$domain/fullchain1.pem"

        # Create symlinks in the live directory pointing to the corresponding archive files
        ln -sf "../../archive/$domain/privkey1.pem" "$CERTBOT_DIR/live/$domain/privkey.pem"
        ln -sf "../../archive/$domain/cert1.pem" "$CERTBOT_DIR/live/$domain/cert.pem"
        ln -sf "../../archive/$domain/fullchain1.pem" "$CERTBOT_DIR/live/$domain/fullchain.pem"
        echo "Created links for $domain"
    fi
done

echo "Certbot directory structure setup complete."

