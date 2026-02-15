#!/usr/bin/env bash
# Run set_itbms_taxes_pa.py: create ITBMS 10% and 15% taxes (Ventas and Compras) for Panama if missing.
# Run after accounting and l10n_pa are installed. From repo root:
#   sudo -E bash install/scripts/run_set_itbms_taxes_pa.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_VERSION="${ODOO_VERSION:-19}"
DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
COUNTRY_CODE="${ODOO_COUNTRY_CODE:-PA}"
SET_SCRIPT="${SCRIPT_DIR}/set_itbms_taxes_pa.py"

[[ -f "${ODOO_CONF}" ]] || { echo "Missing ${ODOO_CONF}"; exit 1; }
[[ -x "${ODOO_PY}" ]] || { echo "Missing ${ODOO_PY}"; exit 1; }
[[ -f "${SET_SCRIPT}" ]] || { echo "Missing ${SET_SCRIPT}"; exit 1; }

RUN_SCRIPT="/tmp/set_itbms_taxes_pa_odoo.py"
sudo cp "${SET_SCRIPT}" "${RUN_SCRIPT}"
sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN_SCRIPT}"
sudo -u "${ODOO_USER}" env \
  ODOO_HOME="${ODOO_HOME}" \
  ODOO_CONF="${ODOO_CONF}" \
  DB_NAME="${DB_NAME}" \
  ODOO_COUNTRY_CODE="${COUNTRY_CODE}" \
  "${ODOO_PY}" "${RUN_SCRIPT}"
sudo rm -f "${RUN_SCRIPT}"
echo "Done. ITBMS 10% and 15% taxes (Ventas and Compras) for Panama are available."
