#!/bin/bash
set -e

ODOO_USER="odoo"
ODOO_SRC="/opt/odoo/odoo19/odoo"
VENV_DIR="/opt/odoo/odoo19/venv"

echo "Creating Python virtual environment..."
sudo -u $ODOO_USER python3 -m venv $VENV_DIR

echo "Upgrading pip tools..."
sudo -u $ODOO_USER $VENV_DIR/bin/pip install --upgrade pip wheel setuptools

echo "Installing Odoo Python requirements..."
sudo -u $ODOO_USER $VENV_DIR/bin/pip install -r $ODOO_SRC/requirements.txt

echo "Python venv + requirements installed."
