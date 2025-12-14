#!/bin/bash
set -e

ODOO_USER="odoo"
TARGET_DIR="/opt/odoo/custom-addons"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ZIP_DIR="$SCRIPT_DIR/assets/oca-zips"
TMP_DIR="/tmp/oca_zip_extract"

echo "Installing OCA addons from ZIP files into custom-addons…"

# Ensure unzip is installed
if ! command -v unzip >/dev/null 2>&1; then
  echo "🔧 unzip missing — installing…"
  apt update -y
  apt install -y unzip
fi

mkdir -p "$TARGET_DIR"

if [ ! -d "$ZIP_DIR" ]; then
  echo "⚠️ ZIP directory not found: $ZIP_DIR"
  echo "Skipping OCA ZIP installation."
  exit 0
fi

for zip in "$ZIP_DIR"/*.zip; do
  [ -e "$zip" ] || continue

  echo "📦 Extracting $(basename "$zip")…"
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  unzip -o "$zip" -d "$TMP_DIR"

  for sub in "$TMP_DIR"/*; do
    [ -d "$sub" ] || continue
    echo "➡️ Moving addon directory: $(basename "$sub")"
    mv "$sub" "$TARGET_DIR"/
  done
done

echo "🔐 Setting permissions…"
chown -R $ODOO_USER:$ODOO_USER "$TARGET_DIR"

echo "🔄 Restarting Odoo…"
systemctl restart odoo19

if systemctl is-active --quiet odoo19; then
  echo "✅ Odoo19 service is running"
else
  echo "⚠️ Odoo19 did not start — check logs"
fi

echo "✅ OCA ZIP addons installed in /opt/odoo/custom-addons"
echo "Next: Update Apps List inside Odoo UI."
