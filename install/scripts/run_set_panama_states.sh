#!/usr/bin/env bash
# Run set_panama_states.py: load Panama provinces/comarcas (PA-01 .. PA-13) into res.country.state.
# Run after base (and ideally l10n) is installed. From repo root:
#   sudo -E bash install/scripts/run_set_panama_states.sh
# Or: sudo ODOO_VERSION=19 ODOO_COUNTRY_CODE=PA bash install/scripts/run_set_panama_states.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_VERSION="${ODOO_VERSION:-19}"
DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
SET_STATES_SCRIPT="${SCRIPT_DIR}/set_panama_states.py"

[[ -f "${ODOO_CONF}" ]] || { echo "Missing ${ODOO_CONF}"; exit 1; }
[[ -x "${ODOO_PY}" ]] || { echo "Missing ${ODOO_PY}"; exit 1; }
[[ -f "${SET_STATES_SCRIPT}" ]] || { echo "Missing ${SET_STATES_SCRIPT}"; exit 1; }

RUN_SCRIPT="/tmp/set_panama_states_odoo.py"
sudo cp "${SET_STATES_SCRIPT}" "${RUN_SCRIPT}"
sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN_SCRIPT}"
sudo -u "${ODOO_USER}" env \
  ODOO_HOME="${ODOO_HOME}" \
  ODOO_CONF="${ODOO_CONF}" \
  DB_NAME="${DB_NAME}" \
  ODOO_COUNTRY_CODE="${ODOO_COUNTRY_CODE:-PA}" \
  "${ODOO_PY}" "${RUN_SCRIPT}"
sudo rm -f "${RUN_SCRIPT}"
echo "Done. Panama states (PA-01 .. PA-13) are loaded in res.country.state."
