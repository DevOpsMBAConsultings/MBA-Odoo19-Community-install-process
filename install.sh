#!/usr/bin/env bash
set -e

### ========= DEFAULTS =========
DEFAULT_ODOO_VERSION="19"
DEFAULT_HTTP_PORT="8069"

### ========= PROMPTS =========
read -rp "Odoo version to install [${DEFAULT_ODOO_VERSION}]: " ODOO_VERSION
ODOO_VERSION="${ODOO_VERSION:-$DEFAULT_ODOO_VERSION}"

read -rp "Domain name (e.g. erp.example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "ERROR: domain is required"
  exit 1
fi

read -rp "Email for Let's Encrypt notifications: " EMAIL
if [[ -z "$EMAIL" ]]; then
  echo "ERROR: email is required"
  exit 1
fi

### ========= EXPORTS =========
export ODOO_VERSION
export DOMAIN
export EMAIL
export ODOO_USER="odoo"
export ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
export DB_NAME="odoo${ODOO_VERSION}"
export HTTP_PORT="${DEFAULT_HTTP_PORT}"

### ========= EXECUTION =========
echo ">>> Installing system dependencies"
bash install/01-system.sh

echo ">>> Installing Odoo ${ODOO_VERSION}"
bash install/02-odoo.sh

echo ">>> Installing & configuring Nginx"
bash install/03-nginx.sh

echo
echo "========================================"
echo "Odoo ${ODOO_VERSION} installation done"
echo "URL: https://${DOMAIN}"
echo "========================================"