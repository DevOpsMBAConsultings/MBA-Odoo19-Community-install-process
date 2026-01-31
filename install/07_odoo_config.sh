#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Odoo ${ODOO_VERSION}..."

# Resolve repo root reliably (even if user runs from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ODOO_CONF_TEMPLATE="${REPO_ROOT}/config/odoo19.conf.template"
ODOO_CONF_OUT="/etc/odoo${ODOO_VERSION}.conf"

if [[ ! -f "${ODOO_CONF_TEMPLATE}" ]]; then
  echo "ERROR: Missing template: ${ODOO_CONF_TEMPLATE}"
  exit 1
fi

# --- Generate deterministic secrets if not provided by environment ---
ADMIN_PASSWD="${ADMIN_PASSWD:-$(openssl rand -hex 16)}"
DB_PASSWORD="${DB_PASSWORD:-}"
DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"

export ADMIN_PASSWD DB_PASSWORD DB_NAME

# Render template -> /etc/odooXX.conf
sudo install -m 0640 -o odoo -g odoo /dev/null "${ODOO_CONF_OUT}"

sudo bash -c "sed \
  -e 's|{{ADMIN_PASSWD}}|${ADMIN_PASSWD}|g' \
  -e 's|{{DB_PASSWORD}}|${DB_PASSWORD}|g' \
  -e 's|{{DB_NAME}}|${DB_NAME}|g' \
  -e 's|{{ODOO_VERSION}}|${ODOO_VERSION}|g' \
  '${ODOO_CONF_TEMPLATE}' > '${ODOO_CONF_OUT}'"

echo "✅ Wrote ${ODOO_CONF_OUT}"