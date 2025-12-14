#!/bin/bash
set -e

SERVICE_FILE="/etc/systemd/system/odoo19.service"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$SCRIPT_DIR/config/odoo19.service.template"

echo "Installing systemd service..."

# Ensure service template exists
if [ ! -f "$TEMPLATE" ]; then
  echo "❌ Systemd service template not found at: $TEMPLATE"
  exit 1
fi

# Copy template to systemd
install -m 644 "$TEMPLATE" "$SERVICE_FILE"

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling odoo19 service on boot..."
systemctl enable odoo19

echo "Starting odoo19 service..."
systemctl restart odoo19

echo "Checking odoo19 status..."
if systemctl is-active --quiet odoo19; then
  echo "✅ odoo19 service is active and running."
else
  echo "⚠️ odoo19 service is NOT active. Check logs: journalctl -u odoo19"
fi

echo "Installation of systemd service completed."
