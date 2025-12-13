#!/bin/bash
set -e

echo "Installing wkhtmltopdf (patched Qt) recommended by Odoo..."

# Remove distro version (if any)
apt remove --purge -y wkhtmltopdf || true
apt autoremove -y || true

# Common font deps used by wkhtmltopdf rendering
apt update -y
apt install -y fontconfig xfonts-75dpi xfonts-base

ARCH="$(dpkg --print-architecture)"
if [ "$ARCH" != "amd64" ]; then
  echo "❌ This script currently supports amd64 only. Detected: $ARCH"
  exit 1
fi

# Patched Qt build from wkhtmltopdf packaging releases (Jammy build commonly used on Debian/Ubuntu servers)
WK_DEB="wkhtmltox_0.12.6.1-2.jammy_amd64.deb"
WK_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/${WK_DEB}"

cd /tmp
wget -q "$WK_URL" -O "$WK_DEB"

apt install -y "./$WK_DEB" || dpkg -i "./$WK_DEB" && apt -f install -y

echo "wkhtmltopdf version:"
wkhtmltopdf --version
