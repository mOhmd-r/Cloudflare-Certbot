#!/bin/bash
set -e

echo "Installing required system packages..."
sudo apt update
sudo apt install -y python3-pip python3-venv

# Prompt for domain and API token
read -p "Enter your full domain (e.g. sub.example.com): " FULL_DOMAIN
read -p "Enter your Cloudflare API token: " CF_TOKEN

# Validate domain format and extract root domain
IFS='.' read -r SUB1 SUB2 SUB3 <<< "$FULL_DOMAIN"
if [ -z "$SUB3" ]; then
  echo "Invalid domain format. Expected something like sub.example.com"
  exit 1
fi
DOMAIN="$SUB2.$SUB3"
SUBDOMAIN="$FULL_DOMAIN"

echo "Using domain: $DOMAIN"
echo "Using subdomain: $SUBDOMAIN"

# Prepare Cloudflare API credentials
CRED_DIR="$HOME/.secrets/certbot"
CRED_FILE="$CRED_DIR/cloudflare.ini"
mkdir -p "$CRED_DIR"
echo "# Cloudflare API token used by Certbot" > "$CRED_FILE"
echo "dns_cloudflare_api_token = $CF_TOKEN" >> "$CRED_FILE"
chmod 600 "$CRED_FILE"

# Create virtual environment
VENV_DIR="$HOME/certbot-venv"
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtual environment at $VENV_DIR..."
  python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment and install Certbot
source "$VENV_DIR/bin/activate"
echo "Upgrading pip inside virtual environment..."
pip install --upgrade pip

echo "Installing certbot and required plugins in virtualenv..."
pip install certbot certbot-dns-cloudflare pyopenssl josepy

# Run certbot inside virtual environment
echo "Running certbot to issue certificates..."
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials "$CRED_FILE" \
  --dns-cloudflare-propagation-seconds 30 \
  --cert-name "$FULL_DOMAIN" \
  -d "$DOMAIN" \
  -d "$FULL_DOMAIN"

echo "Certificate issuance completed successfully!"

# Deactivate virtualenv
deactivate
