#!/bin/bash
set -e

ODOO_USER="odoo"
ODOO_BASE="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_SRC="${ODOO_BASE}/odoo"
VENV_DIR="${ODOO_BASE}/venv"

echo "Setting up Python virtual environment for Odoo ${ODOO_VERSION}..."

mkdir -p "$ODOO_BASE"
chown -R $ODOO_USER:$ODOO_USER "$ODOO_BASE"

echo "Creating Python virtual environment…"
sudo -u $ODOO_USER python3 -m venv "$VENV_DIR"

echo "Upgrading pip, wheel, setuptools…"
sudo -u $ODOO_USER "$VENV_DIR/bin/pip" install --upgrade pip wheel setuptools

if [ ! -f "$ODOO_SRC/requirements.txt" ]; then
  echo "❌ Could not find requirements.txt at $ODOO_SRC"
  exit 1
fi

echo "Installing Odoo Python dependencies…"
sudo -u $ODOO_USER "$VENV_DIR/bin/pip" install -r "$ODOO_SRC/requirements.txt"

echo "Installing extra Python deps for custom addons..."
sudo -u $ODOO_USER "$VENV_DIR/bin/pip" install qifparse

echo "Python virtual environment and requirements installed."