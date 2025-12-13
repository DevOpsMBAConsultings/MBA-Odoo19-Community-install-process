#!/bin/bash
set -e

ODOO_USER="odoo"
ODOO_DIR="/opt/odoo/odoo19"
ODOO_SRC="/opt/odoo/odoo19/odoo"

echo "Cloning Odoo 19 Community (or updating if already exists)..."

if [ -d "$ODOO_SRC/.git" ]; then
  echo "Odoo repo already exists. Pulling latest..."
  sudo -u $ODOO_USER bash -c "cd $ODOO_SRC && git pull"
else
  sudo -u $ODOO_USER git clone --depth 1 --branch 19.0 https://github.com/odoo/odoo.git $ODOO_SRC
fi

echo "Odoo source ready at: $ODOO_SRC"
