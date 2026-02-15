#!/bin/bash
set -e

ODOO_USER="odoo"
ODOO_DIR="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_SRC="$ODOO_DIR/odoo"

echo "Cloning or updating Odoo ${ODOO_VERSION} Community..."

mkdir -p "$ODOO_DIR"
chown -R "$ODOO_USER:$ODOO_USER" "$ODOO_DIR"

if [ -d "$ODOO_SRC/.git" ]; then
  echo "Odoo repo exists. Fetching latest..."
  sudo -u $ODOO_USER bash -c "cd '$ODOO_SRC' && git fetch --all --prune && git reset --hard origin/${ODOO_VERSION}.0"
else
  echo "Cloning Odoo ${ODOO_VERSION}.0..."
  sudo -u $ODOO_USER git clone --depth 1 --branch ${ODOO_VERSION}.0 https://github.com/odoo/odoo.git "$ODOO_SRC"
fi

echo "Current Odoo commit:"
sudo -u $ODOO_USER bash -c "cd '$ODOO_SRC' && git rev-parse HEAD"

echo "Odoo source ready at: $ODOO_SRC"