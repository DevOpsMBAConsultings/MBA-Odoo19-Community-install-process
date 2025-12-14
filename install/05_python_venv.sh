#!/bin/bash
set -e

ODOO_USER="odoo"
ODOO_SRC="/opt/odoo/odoo19/odoo"
VENV_DIR="/opt/odoo/odoo19/venv"

echo "Setting up Python virtual environment..."

# Ensure parent folder exists and is owned
mkdir -p "$(dirname "$VENV_DIR")"
chown -R $ODOO_USER:$ODOO_USER "$(dirname "$VENV_DIR")"

echo "Creating Python virtual environment…"
sudo -u $ODOO_USER python3 -m venv "$VENV_DIR"

echo "Upgrading pip, wheel, setuptools…"
sudo -u $ODOO_USER "$VENV_DIR/bin/pip" install --upgrade pip wheel setuptools

# Check requirements file
if [ ! -f "$ODOO_SRC/requirements.txt" ]; then
  echo "❌ Could not find requirements.txt at $ODOO_SRC"
  exit 1
fi

echo "Installing Odoo Python dependencies…"
sudo -u $ODOO_USER "$VENV_DIR/bin/pip" install -r "$ODOO_SRC/requirements.txt"

echo "Installing extra Python deps for custom addons (OCA / community modules)..."
sudo -u $ODOO_USER $VENV_DIR/bin/pip install qifparse

echo "Python virtual environment and requirements installed."
