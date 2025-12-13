#!/bin/bash
set -e

SERVICE_FILE="/etc/systemd/system/odoo19.service"

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$SCRIPT_DIR/config/odoo19.service.template"

echo "Installing systemd service..."

cp "$TEMPLATE" "$SERVICE_FILE"
chmod 644 "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable odoo19
systemctl restart odoo19

echo "✅ Odoo 19 service installed and started."
echo "Check status with: systemctl status odoo19"
