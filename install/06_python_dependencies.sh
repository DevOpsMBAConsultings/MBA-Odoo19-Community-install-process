#!/usr/bin/env bash
set -euo pipefail

: "${ODOO_VERSION:?ODOO_VERSION not set}"

echo "Installing Python dependencies for Odoo ${ODOO_VERSION}..."

ODOO_DIR="/opt/odoo/odoo${ODOO_VERSION}"
VENV_DIR="${ODOO_DIR}/venv"
VENV_PY="${VENV_DIR}/bin/python3"
REQ_FILE="${ODOO_DIR}/odoo/requirements.txt"

if [[ ! -x "${VENV_PY}" ]]; then
  echo "ERROR: venv python not found at ${VENV_DIR}"
  exit 1
fi

if [[ ! -f "${REQ_FILE}" ]]; then
  echo "ERROR: requirements.txt not found at ${REQ_FILE}"
  exit 1
fi

# Always run pip from a safe directory
cd /tmp

echo "Upgrading pip tooling..."
sudo -u odoo "${VENV_PY}" -m pip install --upgrade pip setuptools wheel

echo "Installing Odoo Python requirements (STANDARD MODE)..."
sudo -u odoo "${VENV_PY}" -m pip install -r "${REQ_FILE}"

echo "Installing wand (for sale_product_image addon)..."
sudo -u odoo "${VENV_PY}" -m pip install wand

# Minimal sanity check
sudo -u odoo "${VENV_PY}" - <<'EOF'
import werkzeug, lxml
print("OK: core imports successful")
EOF

echo "✅ Python dependencies installed successfully."
