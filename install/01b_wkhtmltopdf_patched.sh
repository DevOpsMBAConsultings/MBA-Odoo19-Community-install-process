#!/bin/bash
set -e

echo "Installing wkhtmltopdf (patched Qt) recommended by Odoo..."

# Skip if already installed
if wkhtmltopdf --version 2>/dev/null | grep -q "0.12.6"; then
  echo "Patched wkhtmltopdf already installed, skipping."
  exit 0
fi

# Remove distro version if any
apt remove --purge -y wkhtmltopdf || true
apt autoremove -y || true

echo "Installing font dependencies..."
apt update -y
apt install -y fontconfig xfonts-75dpi xfonts-base wget

ARCH="$(dpkg --print-architecture)"
if [ "$ARCH" != "amd64" ]; then
  echo "❌ Only amd64 supported. Detected: $ARCH"
  exit 1
fi

WK_DEB="wkhtmltox_0.12.6.1-2.jammy_amd64.deb"
WK_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/${WK_DEB}"

cd /tmp
echo "Downloading $WK_URL..."
wget -q "$WK_URL" -O "$WK_DEB"

echo "Installing patched wkhtmltopdf..."
apt install -y "./$WK_DEB" || (dpkg -i "./$WK_DEB" && apt -f install -y)

echo "Cleaning up..."
rm -f "/tmp/$WK_DEB"

echo "wkhtmltopdf version:"
wkhtmltopdf --version
