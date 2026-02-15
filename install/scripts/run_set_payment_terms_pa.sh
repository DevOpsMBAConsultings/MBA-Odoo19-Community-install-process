#!/usr/bin/env bash
# Run set_payment_terms_pa.py: create default payment terms (Efectivo, Crédito, etc.) if missing.
# Run after account module is installed. From repo root:
#   sudo -E bash install/scripts/run_set_payment_terms_pa.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_VERSION="${ODOO_VERSION:-19}"
DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
SET_SCRIPT="${SCRIPT_DIR}/set_payment_terms_pa.py"

[[ -f "${ODOO_CONF}" ]] || { echo "Missing ${ODOO_CONF}"; exit 1; }
[[ -x "${ODOO_PY}" ]] || { echo "Missing ${ODOO_PY}"; exit 1; }
[[ -f "${SET_SCRIPT}" ]] || { echo "Missing ${SET_SCRIPT}"; exit 1; }

RUN_SCRIPT="/tmp/set_payment_terms_pa_odoo.py"
sudo cp "${SET_SCRIPT}" "${RUN_SCRIPT}"
sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN_SCRIPT}"
sudo -u "${ODOO_USER}" env \
  ODOO_HOME="${ODOO_HOME}" \
  ODOO_CONF="${ODOO_CONF}" \
  DB_NAME="${DB_NAME}" \
  "${ODOO_PY}" "${RUN_SCRIPT}"
sudo rm -f "${RUN_SCRIPT}"
echo "Done. Default payment terms (Efectivo, Crédito, etc.) are available."
