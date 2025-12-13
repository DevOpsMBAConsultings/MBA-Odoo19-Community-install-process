#!/bin/bash
set -e

echo "Installing and configuring UFW firewall..."

apt install -y ufw

# Allow SSH (critical: do this BEFORE enabling ufw)
ufw allow OpenSSH

# Allow HTTP/HTTPS (for future Nginx reverse proxy)
ufw allow 80/tcp
ufw allow 443/tcp

# Optional: If you plan to access Odoo directly without Nginx
# ufw allow 8069/tcp

ufw --force enable

echo "✅ UFW enabled."
ufw status verbose
