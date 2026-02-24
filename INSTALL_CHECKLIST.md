# Odoo 19 Install – What the Script Does (Checklist)

Use this list to see everything the script does and to verify nothing is missing after a fresh install.

---

## Before You Run

| Item | Required | Notes |
|------|----------|--------|
| Ubuntu 24.04 server | ✅ | Fresh VM or bare metal |
| Domain name | ✅ | e.g. `erp.example.com` (for Nginx + SSL) |
| Email for Let's Encrypt | ✅ | Notifications and SSL |
| (Optional) Remote SSL storage | — | S3/R2 or URL for cert backup/restore |
| (Optional) `ALLOW_ODOO_PORT=1` | — | Only if you want port 8069 open (no Nginx) |

---

## Install Steps (in order)

| Step | Script | What it does |
|------|--------|---------------|
| 00 | `00_system_update.sh` | `apt update` / `apt upgrade` |
| 01 | `01_dependencies.sh` | System packages: git, wget, unzip, python3, build-essential, libpq-dev, libxml2-dev, libjpeg-dev, **libmagickwand-dev**, nodejs, npm, rtlcss, etc. |
| 02 | `02_postgres.sh` | Install PostgreSQL, create `odoo` user |
| 02 | `02_wkhtmltopdf.sh` | Install wkhtmltopdf (patched for PDF reports) |
| 03 | `03_odoo_user_and_folders.sh` | Create `odoo` user, `/opt/odoo/`, `/var/lib/odoo` |
| 04 | `04_clone_odoo.sh` | Clone Odoo source (e.g. 19) to `/opt/odoo/odoo19/odoo` |
| 05 | `05_python_venv.sh` | Python venv at `/opt/odoo/odoo19/venv` |
| 06 | `06_python_dependencies.sh` | Install Odoo `requirements.txt` + **wand** (for sale_product_image) |
| 07 | `07_odoo_config.sh` | Generate `/etc/odoo19.conf` from template (DB name, admin password, addons_path) |
| 07 | `07_systemd_service.sh` | Create and enable `odoo19` systemd service |
| 08 | `08_clone_custom_addons.sh` | See **Custom Addons (08)** below |
| 09 | `09_init_database.sh` | See **Init database (09)** below |
| 10 | `10_ufw_firewall.sh` | UFW: allow OpenSSH, 80, 443; optionally 8069 if `ALLOW_ODOO_PORT=1` |
| 11 | `11_ngnix.sh` | Nginx reverse proxy, Let's Encrypt SSL (certbot), proxy to Odoo on 127.0.0.1:8069 |
| — | `post/00_health_check.sh` | Check service, wkhtmltopdf, ports, addons_path, custom-addons |
| — | `post/10_summary.sh` | Summary output |

---

## Custom Addons (08) – in detail

**Script:** `install/08_clone_custom_addons.sh`

| Item | Detail |
|------|--------|
| **Source** | `custom_addons.txt` in the repo root. |
| **Target** | `/opt/odoo/custom-addons` – all addons end up here. |

**Process:**
1. Reads `custom_addons.txt` line by line.
2. Clones each repository into `/opt/odoo/custom-addons`.
3. Handles private repositories via standard SSH authentication (assumes SSH keys are loaded).
4. `chown -R odoo:odoo /opt/odoo/custom-addons`.
- List all `__manifest__.py` under `custom-addons` (maxdepth 2).
- If **zero** manifests found → script exits 1.
- `systemctl restart odoo19`; check service is active (or warn).

**Order:** ZIPs are processed in shell glob order (no guaranteed order). Odoo resolves module dependency order at install time in step 09.

---

## Init database (09) – in detail

**Script:** `install/09_init_database.sh`

**Paths and variables (from env or defaults):**

| Variable | Default | Meaning |
|----------|---------|---------|
| `DB_NAME` | `odoo${ODOO_VERSION}` | e.g. `odoo19` |
| `ODOO_LANG` | `es_PA` | Language loaded with base (e.g. Spanish Panama) |
| `ODOO_COUNTRY_CODE` | `PA` | Default company country + contact default (ISO code) |
| `ODOO_WITHOUT_DEMO` | `1` | No demo data |
| `ODOO_INIT_MODULES` | *(empty)* | If set: only these modules installed (comma-separated). If unset: see below. |
| `ODOO_EXTRA_MODULES` | `sale,purchase,crm,stock,contacts,account` | Standard Odoo apps always added to the install list unless set empty. |

**How `INIT_MODULES` is built (when `ODOO_INIT_MODULES` is not set):**

1. Scan `/opt/odoo/custom-addons/`: every directory that contains `__manifest__.py` is added (comma-separated).
2. If that list is empty → `INIT_MODULES=l10n_pa`.
3. Append `,${ODOO_EXTRA_MODULES}` (unless `ODOO_EXTRA_MODULES` is empty).

So the install list = **all addons from step 08** + **sale, purchase, crm, stock, contacts, account** (or whatever you set).

**Flow A – Database already exists and is initialized** (`ir_module_module` table present):

1. Run `set_default_country.py`: company country + `res.partner.country_id` default.
2. Stop Odoo; run `odoo-bin -c ... -d $DB_NAME -i "$INIT_MODULES" --stop-after-init` (install missing modules only). On failure script exits 1 and prints the error.
3. If `ODOO_COUNTRY_CODE=PA`: run `set_default_taxes_pa.py` (Exento 0% Venta / Compra), then `set_itbms_taxes_pa.py` (ITBMS 10% and 15% Ventas/Compras).
4. If PA: run **Panama invoicing solution** – sales journal (FE), credit notes journal (NC), fiscal positions Exento de impuestos and Retención de impuestos; then **set_panama_states.py** (PA-01 .. PA-13); then **set_payment_terms_pa.py** (Efectivo, Crédito, etc.).
5. Start Odoo; exit 0.

**Flow B – Fresh database (first time):**

1. Ensure `/var/lib/odoo` exists; owned by `odoo`; mode 750.
2. If DB does not exist: `createdb -O odoo $DB_NAME`.
3. Stop Odoo.
4. **Init base:** `odoo-bin -c ... -d $DB_NAME -i base --without-demo --load-language=$LANG_CODE --stop-after-init`.
5. Run `set_default_country.py` (company + contact default country).
6. **Install all modules:** `odoo-bin -c ... -d $DB_NAME -i "$INIT_MODULES" --stop-after-init` (no `|| true` – failure stops the script).
7. If `ODOO_COUNTRY_CODE=PA`: run `set_default_taxes_pa.py`, then `set_itbms_taxes_pa.py`.
8. If PA: run **Panama invoicing solution** – sales journal (FE), credit notes journal (NC), fiscal positions Exento de impuestos and Retención de impuestos; then **set_panama_states.py** (PA-01 .. PA-13); then **set_payment_terms_pa.py**.
9. Start Odoo.

**Scripts used (must be present under `install/scripts/`):**

- `set_default_country.py` – company country + `ir.default` for `res.partner.country_id`.
- `set_default_taxes_pa.py` – tax group “Exento 0%” and two 0% taxes (sale + purchase) for PA; only runs when country is PA.
- `set_default_sales_journal.py` – default journal for customer invoices (Facturación electrónica, code FE); runs when PA.
- `set_default_credit_notes_journal.py` – default journal for credit notes (Notas de Crédito, code NC, dedicated sequence); runs when PA.
- `set_fiscal_position_exento.py` – fiscal position "Exento de impuestos" with Detectar de forma automática; runs when PA.
- `set_fiscal_position_retencion.py` – fiscal position "Retención de impuestos" (auto_apply off by default); runs when PA.
- `set_tax_retencion_impuestos.py` – tax "Retención de Impuestos" (group with 7%), mapped on fiscal position Retención (0% Venta → Retención); runs when PA.
- `set_panama_states.py` – load Panama provinces/comarcas (PA-01 .. PA-13) into res.country.state; runs when PA.
- `set_itbms_taxes_pa.py` – tax groups ITBMS 10% and ITBMS 15%, four taxes (10% and 15% Ventas/Compras); runs when PA.
- `set_payment_terms_pa.py` – default payment terms (Efectivo, Crédito, Crédito a 30/60/90 días, Crédito Otro, Tarjeta Crédito, etc.) in order; credit terms use due 30/60/90 days; runs when PA.

---


## Add-ons installed by default (from `assets/oca-zips/`)

| Add-on | Purpose |
|--------|---------|
| accounting_pdf_reports | PDF accounting reports |
| main_menu | Main menu layout |
| mba_partner_phone_pa | Panama phone format on contacts |
| om_account_accountant | Accounting (OCA) |
| om_account_asset | Assets |
| om_account_budget | Budgets |
| om_account_daily_reports | Daily reports |
| om_account_followup | Follow-up |
| om_fiscal_year | Fiscal year |
| om_recurring_payments | Recurring payments |
| sale_product_image | Sale order line images (needs wand – installed in step 06) |

---

## After install – verify checklist

| Check | How to verify |
|-------|----------------|
| Odoo service running | `sudo systemctl status odoo19` |
| Can log in | Open https://YOUR_DOMAIN (or http://IP:8069 if no Nginx) |
| Default apps installed | Apps menu: Sale, Purchase, CRM, Inventory, Contacts, Invoicing (and custom addons) |
| Default country (e.g. PA) | Settings / Company / country; new contact default country |
| 0% taxes (if PA) | Invoicing → Configuration → Taxes: “Exento 0% Venta”, “Exento 0% Compra” |
| custom-addons in addons_path | `grep addons_path /etc/odoo19.conf` includes `/opt/odoo/custom-addons` |
| UFW | `sudo ufw status`: 22, 80, 443 (and 8069 only if you set ALLOW_ODOO_PORT=1) |
| Nginx + SSL | HTTPS works; certificate from Let's Encrypt |

---

## Optional (run manually only if needed)

| Item | When / how |
|------|------------|
| Default sales journal (FE), credit notes journal (NC), fiscal positions Exento de impuestos and Retención de impuestos | When **PA**: step 09 runs them automatically. For an existing DB or non-PA, run the scripts in `install/scripts/` if needed. |
| Update Apps list in UI | Apps → Update Apps List (if you add new addons later) |

---

## If something is missing

- **Can’t reach Odoo**: Open 8069 in UFW if not using Nginx: `sudo ufw allow 8069/tcp && sudo ufw reload`.
- **Module install failed**: See output of step 09 or run `09_init_database.sh` again with `--logfile` to capture the error.
- **Health check**: Run `post/00_health_check.sh` and fix any reported issues.

---

*Generated as a recap of the Odoo 19 install script.*
