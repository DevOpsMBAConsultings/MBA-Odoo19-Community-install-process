#!/usr/bin/env bash
set -euo pipefail

echo "Installing systemd service for Odoo ${ODOO_VERSION}..."

ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
SERVICE_PATH="/etc/systemd/system/odoo${ODOO_VERSION}.service"
CONF_PATH="/etc/odoo${ODOO_VERSION}.conf"

# Sanity checks (fail fast with clear errors)
if ! id "${ODOO_USER}" >/dev/null 2>&1; then
  echo "ERROR: user '${ODOO_USER}' does not exist."
  exit 1
fi

if [[ ! -x "${ODOO_HOME}/venv/bin/python3" ]]; then
  echo "ERROR: missing python executable: ${ODOO_HOME}/venv/bin/python3"
  exit 1
fi

if [[ ! -f "${ODOO_HOME}/odoo/odoo-bin" ]]; then
  echo "ERROR: missing odoo-bin: ${ODOO_HOME}/odoo/odoo-bin"
  exit 1
fi

if [[ ! -f "${CONF_PATH}" ]]; then
  echo "ERROR: missing config file: ${CONF_PATH}"
  exit 1
fi

echo "Writing ${SERVICE_PATH} ..."

sudo tee "${SERVICE_PATH}" >/dev/null <<EOF
[Unit]
Description=Odoo ${ODOO_VERSION} Community
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=${ODOO_USER}
Group=${ODOO_USER}
WorkingDirectory=${ODOO_HOME}/odoo
ExecStart=${ODOO_HOME}/venv/bin/python3 ${ODOO_HOME}/odoo/odoo-bin -c ${CONF_PATH}
Restart=always
RestartSec=3
KillMode=mixed
TimeoutStopSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling odoo${ODOO_VERSION} service on boot..."
sudo systemctl enable "odoo${ODOO_VERSION}.service"

echo "Starting odoo${ODOO_VERSION} service..."
sudo systemctl restart "odoo${ODOO_VERSION}.service"

echo "✅ systemd service installed and started."