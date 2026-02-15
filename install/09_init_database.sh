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
  if [[ -f "${SET_COUNTRY_SCRIPT}" ]]; then
    SET_COUNTRY_SCRIPT_RUN="/tmp/set_default_country_odoo.py"
    sudo cp "${SET_COUNTRY_SCRIPT}" "${SET_COUNTRY_SCRIPT_RUN}"
    sudo chown "${ODOO_USER}:${ODOO_USER}" "${SET_COUNTRY_SCRIPT_RUN}"
    sudo -u "${ODOO_USER}" env \
      ODOO_HOME="${ODOO_HOME}" \
      ODOO_CONF="${ODOO_CONF}" \
      DB_NAME="${DB_NAME}" \
      ODOO_COUNTRY_CODE="${COUNTRY_CODE}" \
      "${ODOO_PY}" "${SET_COUNTRY_SCRIPT_RUN}" || true
    sudo rm -f "${SET_COUNTRY_SCRIPT_RUN}"
  fi
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
  # 0% taxes for Panama when country is PA
  if [[ "${COUNTRY_CODE}" == "PA" ]] && [[ -f "${SET_TAXES_SCRIPT}" ]]; then
    echo "Setting 0% taxes for Panama..."
    SET_TAXES_SCRIPT_RUN="/tmp/set_default_taxes_pa_odoo.py"
    sudo cp "${SET_TAXES_SCRIPT}" "${SET_TAXES_SCRIPT_RUN}"
    sudo chown "${ODOO_USER}:${ODOO_USER}" "${SET_TAXES_SCRIPT_RUN}"
    sudo -u "${ODOO_USER}" env \
      ODOO_HOME="${ODOO_HOME}" \
      ODOO_CONF="${ODOO_CONF}" \
      DB_NAME="${DB_NAME}" \
      ODOO_COUNTRY_CODE="${COUNTRY_CODE}" \
      "${ODOO_PY}" "${SET_TAXES_SCRIPT_RUN}" || true
    sudo rm -f "${SET_TAXES_SCRIPT_RUN}"
  fi
  # ITBMS 10% and 15% taxes for Panama when country is PA
  if [[ "${COUNTRY_CODE}" == "PA" ]] && [[ -f "${SET_ITBMS_TAXES_SCRIPT}" ]]; then
    echo "Setting ITBMS 10% and 15% taxes for Panama..."
    RUN="/tmp/set_itbms_taxes_pa_odoo.py"
    sudo cp "${SET_ITBMS_TAXES_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" ODOO_COUNTRY_CODE="${COUNTRY_CODE}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  # Panama invoicing solution: default journals (Facturación electrónica, Notas de crédito) + fiscal position Exento de impuestos
  if [[ "${COUNTRY_CODE}" == "PA" ]]; then
    if [[ -f "${SET_SALES_JOURNAL_SCRIPT}" ]]; then
      echo "Setting default sales journal (Facturación electrónica)..."
      RUN="/tmp/set_default_sales_journal_odoo.py"
      sudo cp "${SET_SALES_JOURNAL_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
      sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
      sudo rm -f "${RUN}"
    fi
    if [[ -f "${SET_CREDIT_NOTES_JOURNAL_SCRIPT}" ]]; then
      echo "Setting default credit notes journal (Notas de Crédito)..."
      RUN="/tmp/set_default_credit_notes_journal_odoo.py"
      sudo cp "${SET_CREDIT_NOTES_JOURNAL_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
      sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
      sudo rm -f "${RUN}"
    fi
    if [[ -f "${SET_FISCAL_POSITION_SCRIPT}" ]]; then
      echo "Setting fiscal position Exento de impuestos (Detectar de forma automática)..."
      RUN="/tmp/set_fiscal_position_exento_odoo.py"
      sudo cp "${SET_FISCAL_POSITION_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
      sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
      sudo rm -f "${RUN}"
    fi
    if [[ -f "${SET_FISCAL_POSITION_RETENCION_SCRIPT}" ]]; then
      echo "Setting fiscal position Retención de impuestos..."
      RUN="/tmp/set_fiscal_position_retencion_odoo.py"
      sudo cp "${SET_FISCAL_POSITION_RETENCION_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
      sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
      sudo rm -f "${RUN}"
    fi
    if [[ -f "${SET_TAX_RETENCION_SCRIPT}" ]]; then
      echo "Setting tax Retención de Impuestos (group 7%) and fiscal position mapping..."
      RUN="/tmp/set_tax_retencion_impuestos_odoo.py"
      sudo cp "${SET_TAX_RETENCION_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
      sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" ODOO_COUNTRY_CODE="${COUNTRY_CODE}" "${ODOO_PY}" "${RUN}" || true
      sudo rm -f "${RUN}"
    fi
    if [[ -f "${SET_PANAMA_STATES_SCRIPT}" ]]; then
      echo "Loading Panama provinces/comarcas (PA-01 .. PA-13)..."
      RUN="/tmp/set_panama_states_odoo.py"
      sudo cp "${SET_PANAMA_STATES_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
      sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" ODOO_COUNTRY_CODE="${COUNTRY_CODE}" "${ODOO_PY}" "${RUN}" || true
      sudo rm -f "${RUN}"
    fi
    if [[ -f "${SET_PAYMENT_TERMS_SCRIPT}" ]]; then
      echo "Setting default payment terms (Efectivo, Crédito, etc.)..."
      RUN="/tmp/set_payment_terms_pa_odoo.py"
      sudo cp "${SET_PAYMENT_TERMS_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
      sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
      sudo rm -f "${RUN}"
    fi
  fi
  # Partner tags: create partner tags from list (runs for any country, after contacts module)
  if [[ -f "${SET_PARTNER_TAGS_SCRIPT}" ]]; then
    echo "Creating partner tags (Etiquetas)..."
    RUN="/tmp/set_partner_tags_odoo.py"
    sudo cp "${SET_PARTNER_TAGS_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  # Contacts: default view Kanban (runs for any country)
  if [[ -f "${SET_CONTACTS_VIEW_SCRIPT}" ]]; then
    echo "Setting Contacts default view to Kanban..."
    RUN="/tmp/set_contacts_default_view_kanban_odoo.py"
    sudo cp "${SET_CONTACTS_VIEW_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  # Sales: enable Unidades de medida y embalajes (runs when sale is installed)
  if [[ -f "${SET_SALE_UOM_SCRIPT}" ]]; then
    echo "Enabling Units of measure and packaging in Sales..."
    RUN="/tmp/set_sale_uom_packaging_odoo.py"
    sudo cp "${SET_SALE_UOM_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  # Default service products (Servicio de Acarreo, Otros Gastos, Seguro) with 0% tax when PA
  if [[ -f "${SET_PRODUCTS_SCRIPT}" ]] && [[ "${COUNTRY_CODE}" == "PA" ]]; then
    echo "Creating default service products (0% tax)..."
    RUN="/tmp/set_default_products_pa_odoo.py"
    sudo cp "${SET_PRODUCTS_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" ODOO_COUNTRY_CODE="${COUNTRY_CODE}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
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
if [[ -f "${SET_COUNTRY_SCRIPT}" ]]; then
  echo "Setting default country to ${COUNTRY_CODE}..."
  SET_COUNTRY_SCRIPT_RUN="/tmp/set_default_country_odoo.py"
  sudo cp "${SET_COUNTRY_SCRIPT}" "${SET_COUNTRY_SCRIPT_RUN}"
  sudo chown "${ODOO_USER}:${ODOO_USER}" "${SET_COUNTRY_SCRIPT_RUN}"
  sudo -u "${ODOO_USER}" env \
    ODOO_HOME="${ODOO_HOME}" \
    ODOO_CONF="${ODOO_CONF}" \
    DB_NAME="${DB_NAME}" \
    ODOO_COUNTRY_CODE="${COUNTRY_CODE}" \
    "${ODOO_PY}" "${SET_COUNTRY_SCRIPT_RUN}" || true
  sudo rm -f "${SET_COUNTRY_SCRIPT_RUN}"
else
  echo "⚠️ Script not found: ${SET_COUNTRY_SCRIPT}; skipping default country."
fi

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

# 0% taxes for Panama when country is PA (after account/l10n are installed)
if [[ "${COUNTRY_CODE}" == "PA" ]] && [[ -f "${SET_TAXES_SCRIPT}" ]]; then
  echo "Setting 0% taxes for Panama..."
  SET_TAXES_SCRIPT_RUN="/tmp/set_default_taxes_pa_odoo.py"
  sudo cp "${SET_TAXES_SCRIPT}" "${SET_TAXES_SCRIPT_RUN}"
  sudo chown "${ODOO_USER}:${ODOO_USER}" "${SET_TAXES_SCRIPT_RUN}"
  sudo -u "${ODOO_USER}" env \
    ODOO_HOME="${ODOO_HOME}" \
    ODOO_CONF="${ODOO_CONF}" \
    DB_NAME="${DB_NAME}" \
    ODOO_COUNTRY_CODE="${COUNTRY_CODE}" \
    "${ODOO_PY}" "${SET_TAXES_SCRIPT_RUN}" || true
  sudo rm -f "${SET_TAXES_SCRIPT_RUN}"
fi

# ITBMS 10% and 15% taxes for Panama when country is PA
if [[ "${COUNTRY_CODE}" == "PA" ]] && [[ -f "${SET_ITBMS_TAXES_SCRIPT}" ]]; then
  echo "Setting ITBMS 10% and 15% taxes for Panama..."
  RUN="/tmp/set_itbms_taxes_pa_odoo.py"
  sudo cp "${SET_ITBMS_TAXES_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
  sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" ODOO_COUNTRY_CODE="${COUNTRY_CODE}" "${ODOO_PY}" "${RUN}" || true
  sudo rm -f "${RUN}"
fi

# Panama invoicing solution: default journals (Facturación electrónica, Notas de crédito) + fiscal position Exento de impuestos
if [[ "${COUNTRY_CODE}" == "PA" ]]; then
  if [[ -f "${SET_SALES_JOURNAL_SCRIPT}" ]]; then
    echo "Setting default sales journal (Facturación electrónica)..."
    RUN="/tmp/set_default_sales_journal_odoo.py"
    sudo cp "${SET_SALES_JOURNAL_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  if [[ -f "${SET_CREDIT_NOTES_JOURNAL_SCRIPT}" ]]; then
    echo "Setting default credit notes journal (Notas de Crédito)..."
    RUN="/tmp/set_default_credit_notes_journal_odoo.py"
    sudo cp "${SET_CREDIT_NOTES_JOURNAL_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  if [[ -f "${SET_FISCAL_POSITION_SCRIPT}" ]]; then
    echo "Setting fiscal position Exento de impuestos (Detectar de forma automática)..."
    RUN="/tmp/set_fiscal_position_exento_odoo.py"
    sudo cp "${SET_FISCAL_POSITION_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  if [[ -f "${SET_FISCAL_POSITION_RETENCION_SCRIPT}" ]]; then
    echo "Setting fiscal position Retención de impuestos..."
    RUN="/tmp/set_fiscal_position_retencion_odoo.py"
    sudo cp "${SET_FISCAL_POSITION_RETENCION_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  if [[ -f "${SET_TAX_RETENCION_SCRIPT}" ]]; then
    echo "Setting tax Retención de Impuestos (group 7%) and fiscal position mapping..."
    RUN="/tmp/set_tax_retencion_impuestos_odoo.py"
    sudo cp "${SET_TAX_RETENCION_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" ODOO_COUNTRY_CODE="${COUNTRY_CODE}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  if [[ -f "${SET_PANAMA_STATES_SCRIPT}" ]]; then
    echo "Loading Panama provinces/comarcas (PA-01 .. PA-13)..."
    RUN="/tmp/set_panama_states_odoo.py"
    sudo cp "${SET_PANAMA_STATES_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" ODOO_COUNTRY_CODE="${COUNTRY_CODE}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
  if [[ -f "${SET_PAYMENT_TERMS_SCRIPT}" ]]; then
    echo "Setting default payment terms (Efectivo, Crédito, etc.)..."
    RUN="/tmp/set_payment_terms_pa_odoo.py"
    sudo cp "${SET_PAYMENT_TERMS_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
    sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
    sudo rm -f "${RUN}"
  fi
fi

# Partner tags: create partner tags from list (runs for any country, after contacts module)
if [[ -f "${SET_PARTNER_TAGS_SCRIPT}" ]]; then
  echo "Creating partner tags (Etiquetas)..."
  RUN="/tmp/set_partner_tags_odoo.py"
  sudo cp "${SET_PARTNER_TAGS_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
  sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
  sudo rm -f "${RUN}"
fi

# Contacts: default view Kanban (runs for any country)
if [[ -f "${SET_CONTACTS_VIEW_SCRIPT}" ]]; then
  echo "Setting Contacts default view to Kanban..."
  RUN="/tmp/set_contacts_default_view_kanban_odoo.py"
  sudo cp "${SET_CONTACTS_VIEW_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
  sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
  sudo rm -f "${RUN}"
fi

# Sales: enable Unidades de medida y embalajes (runs when sale is installed)
if [[ -f "${SET_SALE_UOM_SCRIPT}" ]]; then
  echo "Enabling Units of measure and packaging in Sales..."
  RUN="/tmp/set_sale_uom_packaging_odoo.py"
  sudo cp "${SET_SALE_UOM_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
  sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" "${ODOO_PY}" "${RUN}" || true
  sudo rm -f "${RUN}"
fi

# Default service products (Servicio de Acarreo, Otros Gastos, Seguro) with 0% tax when PA
if [[ -f "${SET_PRODUCTS_SCRIPT}" ]] && [[ "${COUNTRY_CODE}" == "PA" ]]; then
  echo "Creating default service products (0% tax)..."
  RUN="/tmp/set_default_products_pa_odoo.py"
  sudo cp "${SET_PRODUCTS_SCRIPT}" "${RUN}" && sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN}"
  sudo -u "${ODOO_USER}" env ODOO_HOME="${ODOO_HOME}" ODOO_CONF="${ODOO_CONF}" DB_NAME="${DB_NAME}" ODOO_COUNTRY_CODE="${COUNTRY_CODE}" "${ODOO_PY}" "${RUN}" || true
  sudo rm -f "${RUN}"
fi

# Start service
sudo systemctl start "${ODOO_SERVICE}"

echo "✅ Database '${DB_NAME}' initialized successfully."
