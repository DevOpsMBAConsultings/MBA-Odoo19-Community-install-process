#!/usr/bin/env bash
set -e

echo "Installing system and Python dependencies for Odoo ${ODOO_VERSION}..."

# --- System packages required by Odoo ---
apt update -y
apt install -y \
  python3 \
  python3-venv \
  python3-dev \
  python3-full \
  build-essential \
  libxml2-dev \
  libxslt1-dev \
  libldap2-dev \
  libsasl2-dev \
  libpq-dev \
  libjpeg-dev \
  zlib1g-dev \
  libssl-dev \
  libffi-dev \
  git \
  curl

ODOO_DIR="/opt/odoo/odoo${ODOO_VERSION}"
VENV_DIR="${ODOO_DIR}/venv"
VENV_PY="${VENV_DIR}/bin/python3"
VENV_PIP="${VENV_DIR}/bin/pip"
REQ_FILE="${ODOO_DIR}/odoo/requirements.txt"

# --- Create virtual environment as odoo user ---
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating Python virtual environment..."
  sudo -u odoo python3 -m venv "$VENV_DIR"
fi

# Always run pip using the venv python/pip (no "activate")
if [ ! -x "$VENV_PY" ] || [ ! -x "$VENV_PIP" ]; then
  echo "ERROR: venv binaries not found at ${VENV_DIR}"
  exit 1
fi

if [ ! -f "$REQ_FILE" ]; then
  echo "ERROR: requirements.txt not found at ${REQ_FILE}"
  exit 1
fi

echo "Installing Python requirements inside venv..."

# Run pip from a safe directory to avoid PermissionError: '.'
cd /tmp

# Upgrade pip tooling inside venv (run as odoo to avoid root-owned site-packages)
sudo -u odoo "$VENV_PY" -m pip install --upgrade pip wheel setuptools

# Install Odoo requirements inside venv
sudo -u odoo "$VENV_PIP" install -r "$REQ_FILE"

# Hard-ensure babel exists (your crash is exactly this)
sudo -u odoo "$VENV_PIP" install Babel

# Quick verification
sudo -u odoo "$VENV_PY" - <<'EOF'
import babel, lxml, werkzeug
print("OK: babel/lxml/werkzeug import successful")
EOF

echo "✅ Python dependencies installed successfully."