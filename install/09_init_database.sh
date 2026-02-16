# install/09_init_database.sh
#!/usr/bin/env bash
set -euo pipefail

: "${ODOO_VERSION:?ODOO_VERSION not set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_BIN="${ODOO_HOME}/odoo/odoo-bin"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
ODOO_SERVICE="odoo${ODOO_VERSION}"
ODOO_DATA_DIR="/var/lib/odoo"
CUSTOM_ADDONS="/opt/odoo/custom-addons"
SET_COUNTRY_SCRIPT="${SCRIPT_DIR}/scripts/set_default_country.py"
SET_TAXES_SCRIPT="${SCRIPT_DIR}/scripts/set_default_taxes_pa.py"
SET_SALES_JOURNAL_SCRIPT="${SCRIPT_DIR}/scripts/set_default_sales_journal.py"
SET_CREDIT_NOTES_JOURNAL_SCRIPT="${SCRIPT_DIR}/scripts/set_default_credit_notes_journal.py"
SET_FISCAL_POSITION_SCRIPT="${SCRIPT_DIR}/scripts/set_fiscal_position_exento.py"
SET_FISCAL_POSITION_RETENCION_SCRIPT="${SCRIPT_DIR}/scripts/set_fiscal_position_retencion.py"
SET_TAX_RETENCION_SCRIPT="${SCRIPT_DIR}/scripts/set_tax_retencion_impuestos.py"
SET_PANAMA_STATES_SCRIPT="${SCRIPT_DIR}/scripts/set_panama_states.py"
SET_ITBMS_TAXES_SCRIPT="${SCRIPT_DIR}/scripts/set_itbms_taxes_pa.py"
SET_PAYMENT_TERMS_SCRIPT="${SCRIPT_DIR}/scripts/set_payment_terms_pa.py"
SET_PARTNER_TAGS_SCRIPT="${SCRIPT_DIR}/scripts/set_partner_tags.py"
SET_CONTACTS_VIEW_SCRIPT="${SCRIPT_DIR}/scripts/set_contacts_default_view_kanban.py"
SET_SALE_UOM_SCRIPT="${SCRIPT_DIR}/scripts/set_sale_uom_packaging.py"
SET_PRODUCTS_SCRIPT="${SCRIPT_DIR}/scripts/set_default_products_pa.py"

# Defaults (es_PA = Spanish Panama; override with ODOO_LANG=es_ES etc. if needed)
LANG_CODE="${ODOO_LANG:-es_PA}"
WITHOUT_DEMO="${ODOO_WITHOUT_DEMO:-1}"
# Default country by ISO code (PA = Panama); override with ODOO_COUNTRY_CODE=US etc.
COUNTRY_CODE="${ODOO_COUNTRY_CODE:-PA}"
# Modules to install after base: if ODOO_INIT_MODULES is set, use it; otherwise install ALL add-ons
# present in custom-addons (so first login has everything from assets/oca-zips already installed).
if [[ -n "${ODOO_INIT_MODULES:-}" ]]; then
  INIT_MODULES="${ODOO_INIT_MODULES}"
else
  INIT_MODULES=""
  if [[ -d "${CUSTOM_ADDONS}" ]]; then
    for dir in "${CUSTOM_ADDONS}"/*/; do
      [[ -f "${dir}__manifest__.py" ]] || continue
      name="$(basename "$dir")"
      [[ -n "${INIT_MODULES}" ]] && INIT_MODULES="${INIT_MODULES},"
      INIT_MODULES="${INIT_MODULES}${name}"
    done
  fi
  [[ -z "${INIT_MODULES}" ]] && INIT_MODULES="l10n_pa"
fi
# Default Odoo standard modules to install (sale, purchase, crm, stock, contacts, account). Override with ODOO_EXTRA_MODULES or set empty to install none.
ODOO_EXTRA_MODULES="${ODOO_EXTRA_MODULES:-sale,purchase,crm,stock,contacts,account}"
if [[ -n "${ODOO_EXTRA_MODULES}" ]]; then
  INIT_MODULES="${INIT_MODULES},${ODOO_EXTRA_MODULES}"
fi

# Helper function to run post-install configuration scripts
run_config_script() {
  local script_path="$1"
  local description="$2"
  local require_pa="${3:-0}" # 0=Always run, 1=Run only if COUNTRY_CODE is PA

  if [[ "${require_pa}" == "1" ]] && [[ "${COUNTRY_CODE}" != "PA" ]]; then
    return 0
  fi

  if [[ -f "${script_path}" ]]; then
    echo "${description}"
    local script_name
    script_name="$(basename "${script_path}")"
    # Use a unique temp name to avoid collisions
    local run_path="/tmp/${script_name%.*}_odoo.py"
    
    sudo cp "${script_path}" "${run_path}"
    sudo chown "${ODOO_USER}:${ODOO_USER}" "${run_path}"
    
    # Pass common env vars used by the python scripts
    sudo -u "${ODOO_USER}" env \
      ODOO_HOME="${ODOO_HOME}" \
      ODOO_CONF="${ODOO_CONF}" \
      DB_NAME="${DB_NAME}" \
      ODOO_COUNTRY_CODE="${COUNTRY_CODE}" \
      "${ODOO_PY}" "${run_path}" || true
      
    sudo rm -f "${run_path}"
  else
    # Optional: Debug output if script missing
    :
  fi
}

echo "Initializing database '${DB_NAME}' for Odoo ${ODOO_VERSION}..."
echo "Defaults: LANG=${LANG_CODE}, COUNTRY=${COUNTRY_CODE}, WITHOUT_DEMO=${WITHOUT_DEMO}, INIT_MODULES=${INIT_MODULES}"

# Sanity checks
[[ -f "${ODOO_CONF}" ]] || { echo "Missing ${ODOO_CONF}"; exit 1; }
[[ -x "${ODOO_PY}" ]] || { echo "Missing venv python"; exit 1; }
[[ -x "${ODOO_BIN}" ]] || { echo "Missing odoo-bin"; exit 1; }

# Data dir
sudo mkdir -p "${ODOO_DATA_DIR}"
sudo chown -R "${ODOO_USER}:${ODOO_USER}" "${ODOO_DATA_DIR}"
sudo chmod 750 "${ODOO_DATA_DIR}"

# DB exists?
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  echo "Database '${DB_NAME}' already exists."
else
  sudo -u postgres createdb -O "${ODOO_USER}" "${DB_NAME}"
fi

# Already initialized?
INIT_OK="$(
  sudo -u postgres psql -d "${DB_NAME}" -tAc \
  "SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module'" \
  2>/dev/null || true
)"

if [[ "${INIT_OK}" == "1" ]]; then
  echo "Database already initialized. Applying default country, installing any missing modules, and (if PA) 0% taxes + journals + fiscal position."
  run_config_script "${SET_COUNTRY_SCRIPT}" "Setting default country to ${COUNTRY_CODE}..." 0

  # Install any missing modules (standard + custom) so first login has apps already installed
  if [[ -n "${INIT_MODULES}" ]]; then
    echo "Installing any missing modules: ${INIT_MODULES}..."
    echo "(If this step fails, see the Odoo error below; fix dependencies or remove problematic modules from custom-addons and re-run this script.)"
    sudo systemctl stop "${ODOO_SERVICE}" >/dev/null 2>&1 || true
    if ! sudo -u "${ODOO_USER}" "${ODOO_PY}" "${ODOO_BIN}" \
      -c "${ODOO_CONF}" \
      -d "${DB_NAME}" \
      -i "${INIT_MODULES}" \
      --stop-after-init; then
      echo "ERROR: Module install failed. Check the output above for the Odoo traceback."
      echo "You can re-run the install manually with: sudo -u odoo /opt/odoo/odoo19/venv/bin/python3 /opt/odoo/odoo19/odoo/odoo-bin -c /etc/odoo19.conf -d odoo19 -i \"<module_list>\" --stop-after-init"
      exit 1
    fi
  fi

  # Run all post-install configuration scripts
  run_config_script "${SET_TAXES_SCRIPT}" "Setting 0% taxes for Panama..." 1
  run_config_script "${SET_ITBMS_TAXES_SCRIPT}" "Setting ITBMS 10% and 15% taxes for Panama..." 1
  run_config_script "${SET_SALES_JOURNAL_SCRIPT}" "Setting default sales journal (Facturación electrónica)..." 1
  run_config_script "${SET_CREDIT_NOTES_JOURNAL_SCRIPT}" "Setting default credit notes journal (Notas de Crédito)..." 1
  run_config_script "${SET_FISCAL_POSITION_SCRIPT}" "Setting fiscal position Exento de impuestos (Detectar de forma automática)..." 1
  run_config_script "${SET_FISCAL_POSITION_RETENCION_SCRIPT}" "Setting fiscal position Retención de impuestos..." 1
  run_config_script "${SET_TAX_RETENCION_SCRIPT}" "Setting tax Retención de Impuestos (group 7%) and fiscal position mapping..." 1
  run_config_script "${SET_PANAMA_STATES_SCRIPT}" "Loading Panama provinces/comarcas (PA-01 .. PA-13)..." 1
  run_config_script "${SET_PAYMENT_TERMS_SCRIPT}" "Setting default payment terms (Efectivo, Crédito, etc.)..." 1
  
  run_config_script "${SET_PARTNER_TAGS_SCRIPT}" "Creating partner tags (Etiquetas)..." 0
  run_config_script "${SET_CONTACTS_VIEW_SCRIPT}" "Setting Contacts default view to Kanban..." 0
  run_config_script "${SET_SALE_UOM_SCRIPT}" "Enabling Units of measure and packaging in Sales..." 0
  run_config_script "${SET_PRODUCTS_SCRIPT}" "Creating default service products (0% tax)..." 1

  sudo systemctl start "${ODOO_SERVICE}" 2>/dev/null || true
  exit 0
fi

# Stop service
sudo systemctl stop "${ODOO_SERVICE}" >/dev/null 2>&1 || true

# INIT BASE (VALID FLAGS ONLY)
sudo -u "${ODOO_USER}" "${ODOO_PY}" "${ODOO_BIN}" \
  -c "${ODOO_CONF}" \
  -d "${DB_NAME}" \
  -i base \
  --without-demo \
  --load-language="${LANG_CODE}" \
  --stop-after-init

# Set default country for all companies (by ISO code, e.g. PA = Panama)
# Copy script to /tmp so user 'odoo' can read it (repo may be under /home/ubuntu with restricted perms)
run_config_script "${SET_COUNTRY_SCRIPT}" "Setting default country to ${COUNTRY_CODE}..." 0

# Install extra modules (e.g. l10n_pa, sale, purchase, custom add-ons); must be in addons_path (OCA zips run in 08 before this)
if [[ -n "${INIT_MODULES}" ]]; then
  echo "Installing modules: ${INIT_MODULES}..."
  echo "(RST/docstring warnings during load are usually harmless.)"
  sudo -u "${ODOO_USER}" "${ODOO_PY}" "${ODOO_BIN}" \
    -c "${ODOO_CONF}" \
    -d "${DB_NAME}" \
    -i "${INIT_MODULES}" \
    --stop-after-init
fi

# Run all post-install configuration scripts
run_config_script "${SET_TAXES_SCRIPT}" "Setting 0% taxes for Panama..." 1
run_config_script "${SET_ITBMS_TAXES_SCRIPT}" "Setting ITBMS 10% and 15% taxes for Panama..." 1
run_config_script "${SET_SALES_JOURNAL_SCRIPT}" "Setting default sales journal (Facturación electrónica)..." 1
run_config_script "${SET_CREDIT_NOTES_JOURNAL_SCRIPT}" "Setting default credit notes journal (Notas de Crédito)..." 1
run_config_script "${SET_FISCAL_POSITION_SCRIPT}" "Setting fiscal position Exento de impuestos (Detectar de forma automática)..." 1
run_config_script "${SET_FISCAL_POSITION_RETENCION_SCRIPT}" "Setting fiscal position Retención de impuestos..." 1
run_config_script "${SET_TAX_RETENCION_SCRIPT}" "Setting tax Retención de Impuestos (group 7%) and fiscal position mapping..." 1
run_config_script "${SET_PANAMA_STATES_SCRIPT}" "Loading Panama provinces/comarcas (PA-01 .. PA-13)..." 1
run_config_script "${SET_PAYMENT_TERMS_SCRIPT}" "Setting default payment terms (Efectivo, Crédito, etc.)..." 1

run_config_script "${SET_PARTNER_TAGS_SCRIPT}" "Creating partner tags (Etiquetas)..." 0
run_config_script "${SET_CONTACTS_VIEW_SCRIPT}" "Setting Contacts default view to Kanban..." 0
run_config_script "${SET_SALE_UOM_SCRIPT}" "Enabling Units of measure and packaging in Sales..." 0
run_config_script "${SET_PRODUCTS_SCRIPT}" "Creating default service products (0% tax)..." 1

# Start service
sudo systemctl start "${ODOO_SERVICE}"

echo "✅ Database '${DB_NAME}' initialized successfully."
