#!/bin/bash
set -e

echo "Installing and configuring UFW firewall..."

apt update -y
apt install -y ufw

echo "Setting default policies..."
ufw default deny incoming
ufw default allow outgoing

echo "Allowing SSH..."
ufw allow OpenSSH

echo "Allowing HTTP/HTTPS..."
ufw allow 80/tcp
ufw allow 443/tcp

# Optional: Uncomment to allow direct Odoo access without reverse proxy
# ufw allow 8069/tcp

if ufw status | grep -q "Status: active"; then
  echo "UFW already enabled."
else
  ufw --force enable
fi

echo "✅ UFW configuration applied."
ufw status verbose
