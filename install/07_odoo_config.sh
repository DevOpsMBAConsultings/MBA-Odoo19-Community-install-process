#!/usr/bin/env bash
set -euo pipefail

echo "Configuring Odoo ${ODOO_VERSION}..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ODOO_CONF_TEMPLATE="${REPO_ROOT}/config/odoo19.conf.template"
ODOO_CONF_OUT="/etc/odoo${ODOO_VERSION}.conf"

if [[ ! -f "${ODOO_CONF_TEMPLATE}" ]]; then
  echo "ERROR: Missing template: ${ODOO_CONF_TEMPLATE}"
  exit 1
fi

ADMIN_PASSWD="${ADMIN_PASSWD:-$(openssl rand -hex 16)}"
DB_NAME="odoo${ODOO_VERSION}"

export ADMIN_PASSWD DB_NAME ODOO_VERSION

sudo install -m 0640 -o odoo -g odoo /dev/null "${ODOO_CONF_OUT}"

sudo bash -c "sed \
  -e 's|{{ADMIN_PASSWD}}|${ADMIN_PASSWD}|g' \
  -e 's|{{DB_NAME}}|${DB_NAME}|g' \
  -e 's|{{ODOO_VERSION}}|${ODOO_VERSION}|g' \
  '${ODOO_CONF_TEMPLATE}' > '${ODOO_CONF_OUT}'"

echo "✅ Wrote ${ODOO_CONF_OUT}"
echo "🔑 Odoo master password:"
echo "    ${ADMIN_PASSWD}"
