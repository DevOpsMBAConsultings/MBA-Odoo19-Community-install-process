#!/bin/bash
set -e

ODOO_VER="${ODOO_VERSION:-19}"

SERVICE_FILE="/etc/systemd/system/odoo${ODOO_VER}.service"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$SCRIPT_DIR/config/odoo19.service.template"

echo "Installing systemd service for Odoo ${ODOO_VER}..."

if [ ! -f "$TEMPLATE" ]; then
  echo "❌ Systemd service template not found at: $TEMPLATE"
  exit 1
fi

TMP_SERVICE="/tmp/odoo${ODOO_VER}.service"
sed -e "s/{{ODOO_VERSION}}/${ODOO_VER}/g" "$TEMPLATE" > "$TMP_SERVICE"

install -m 644 "$TMP_SERVICE" "$SERVICE_FILE"
rm -f "$TMP_SERVICE"

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling odoo${ODOO_VER} service on boot..."
systemctl enable "odoo${ODOO_VER}"

echo "Starting odoo${ODOO_VER} service..."
systemctl restart "odoo${ODOO_VER}"

echo "Checking odoo${ODOO_VER} status..."
if systemctl is-active --quiet "odoo${ODOO_VER}"; then
  echo "✅ odoo${ODOO_VER} service is active and running."
else
  echo "⚠️ odoo${ODOO_VER} service is NOT active. Check logs: journalctl -u odoo${ODOO_VER}"
fi

echo "Installation of systemd service completed."