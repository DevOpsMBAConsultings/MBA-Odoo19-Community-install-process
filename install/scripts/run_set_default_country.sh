#!/usr/bin/env bash
# Run set_default_country.py on an existing Odoo DB (company country + ir.default for res.partner.country_id).
# Use this when the DB was initialized before that step existed, or to re-apply the default.
# On the server, from the repo root (or with correct paths):
#   sudo -E bash install/scripts/run_set_default_country.sh
# Or: sudo ODOO_VERSION=19 ODOO_COUNTRY_CODE=PA bash install/scripts/run_set_default_country.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_VERSION="${ODOO_VERSION:-19}"
DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
COUNTRY_CODE="${ODOO_COUNTRY_CODE:-PA}"
SET_COUNTRY_SCRIPT="${SCRIPT_DIR}/set_default_country.py"

[[ -f "${ODOO_CONF}" ]] || { echo "Missing ${ODOO_CONF}"; exit 1; }
[[ -x "${ODOO_PY}" ]] || { echo "Missing ${ODOO_PY}"; exit 1; }
[[ -f "${SET_COUNTRY_SCRIPT}" ]] || { echo "Missing ${SET_COUNTRY_SCRIPT}"; exit 1; }

SET_COUNTRY_SCRIPT_RUN="/tmp/set_default_country_odoo.py"
sudo cp "${SET_COUNTRY_SCRIPT}" "${SET_COUNTRY_SCRIPT_RUN}"
sudo chown "${ODOO_USER}:${ODOO_USER}" "${SET_COUNTRY_SCRIPT_RUN}"
sudo -u "${ODOO_USER}" env \
  ODOO_HOME="${ODOO_HOME}" \
  ODOO_CONF="${ODOO_CONF}" \
  DB_NAME="${DB_NAME}" \
  ODOO_COUNTRY_CODE="${COUNTRY_CODE}" \
  "${ODOO_PY}" "${SET_COUNTRY_SCRIPT_RUN}"
sudo rm -f "${SET_COUNTRY_SCRIPT_RUN}"
echo "Done. New contacts will default to country ${COUNTRY_CODE}."
