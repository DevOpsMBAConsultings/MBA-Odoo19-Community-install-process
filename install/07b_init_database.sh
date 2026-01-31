#!/usr/bin/env bash
set -e

echo "Initializing database '${DB_NAME}' for Odoo ${ODOO_VERSION}..."

# Guards
: "${ODOO_VERSION:?ODOO_VERSION not set}"
: "${DB_NAME:?DB_NAME not set}"

ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_BIN="${ODOO_HOME}/odoo/odoo-bin"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
ODOO_SERVICE="odoo${ODOO_VERSION}"

# 1) Ensure Postgres DB exists (owned by odoo)
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  echo "Database '${DB_NAME}' already exists. Skipping creation."
else
  echo "Creating database '${DB_NAME}' (owner: ${ODOO_USER})..."
  sudo -u postgres createdb -O "${ODOO_USER}" "${DB_NAME}"
fi

# 2) Stop service to avoid race while initializing registry
echo "Stopping ${ODOO_SERVICE} before init..."
systemctl stop "${ODOO_SERVICE}" || true

# 3) Init base (creates all core tables)
echo "Running Odoo base init (this can take a minute)..."
sudo -u "${ODOO_USER}" "${ODOO_PY}" "${ODOO_BIN}" \
  -c "${ODOO_CONF}" \
  -d "${DB_NAME}" \
  -i base \
  --without-demo=all \
  --stop-after-init

# 4) Start service back
echo "Starting ${ODOO_SERVICE}..."
systemctl start "${ODOO_SERVICE}"

echo "Database initialization completed for '${DB_NAME}'."