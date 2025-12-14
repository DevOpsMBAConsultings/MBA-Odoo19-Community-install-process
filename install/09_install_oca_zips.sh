#!/bin/bash
set -e

ODOO_USER="odoo"
TARGET_DIR="/opt/odoo/custom-addons"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ZIP_DIR="$SCRIPT_DIR/assets/oca-zips"

echo "Installing OCA addons from ZIP files into custom-addons…"

mkdir -p "$TARGET_DIR"

if [ ! -d "$ZIP_DIR" ]; then
  echo "⚠️ ZIP directory not found: $ZIP_DIR"
  echo "Skipping ZIP-based OCA install."
  exit 0
fi

for zip in "$ZIP_DIR"/*.zip; do
  [ -e "$zip" ] || continue

  echo "Extracting $(basename "$zip")…"
  unzip -o "$zip" -d "$TARGET_DIR"
done

echo "Setting permissions…"
chown -R $ODOO_USER:$ODOO_USER "$TARGET_DIR"

echo "Restarting Odoo…"
systemctl restart odoo19

echo "✅ OCA ZIP addons installed in /opt/odoo/custom-addons"
echo "Next: Update Apps List inside Odoo UI."
