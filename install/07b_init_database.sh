#!/bin/bash
set -e

ODOO_VER="${ODOO_VERSION:-19}"
DB_NAME="${DB_NAME:-odoo19}"

ODOO_BASE="/opt/odoo/odoo${ODOO_VER}"
ODOO_BIN="${ODOO_BASE}/odoo/odoo-bin"
PY_BIN="${ODOO_BASE}/venv/bin/python3"
CONF="/etc/odoo${ODOO_VER}.conf"

echo "Initializing database '${DB_NAME}' for Odoo ${ODOO_VER}..."

if [ ! -x "$PY_BIN" ]; then
  echo "❌ Python venv not found: $PY_BIN"
  exit 1
fi

if [ ! -f "$ODOO_BIN" ]; then
  echo "❌ odoo-bin not found: $ODOO_BIN"
  exit 1
fi

if [ ! -f "$CONF" ]; then
  echo "❌ Config not found: $CONF"
  exit 1
fi

# Initialize DB with base module and stop (non-interactive, safe for automation)
sudo -u odoo "$PY_BIN" "$ODOO_BIN" \
  -c "$CONF" \
  -d "$DB_NAME" \
  -i base \
  --without-demo=all \
  --stop-after-init

echo "✅ Database '${DB_NAME}' initialized."