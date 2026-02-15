#!/usr/bin/env bash
# Run set_default_sales_journal.py on an existing Odoo DB (create or find FE journal, set as default for customer invoices).
# Run after accounting (and ideally l10n) is installed. From repo root:
#   sudo -E bash install/scripts/run_set_default_sales_journal.sh
# Or: sudo ODOO_VERSION=19 bash install/scripts/run_set_default_sales_journal.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_VERSION="${ODOO_VERSION:-19}"
DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
SET_JOURNAL_SCRIPT="${SCRIPT_DIR}/set_default_sales_journal.py"

[[ -f "${ODOO_CONF}" ]] || { echo "Missing ${ODOO_CONF}"; exit 1; }
[[ -x "${ODOO_PY}" ]] || { echo "Missing ${ODOO_PY}"; exit 1; }
[[ -f "${SET_JOURNAL_SCRIPT}" ]] || { echo "Missing ${SET_JOURNAL_SCRIPT}"; exit 1; }

RUN_SCRIPT="/tmp/set_default_sales_journal_odoo.py"
sudo cp "${SET_JOURNAL_SCRIPT}" "${RUN_SCRIPT}"
sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN_SCRIPT}"
sudo -u "${ODOO_USER}" env \
  ODOO_HOME="${ODOO_HOME}" \
  ODOO_CONF="${ODOO_CONF}" \
  DB_NAME="${DB_NAME}" \
  "${ODOO_PY}" "${RUN_SCRIPT}"
sudo rm -f "${RUN_SCRIPT}"
echo "Done. New customer invoices will use the default sales journal (e.g. Facturación electrónica)."
