#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEFAULT_ODOO_VERSION="19"

read -r -p "Odoo version to install [${DEFAULT_ODOO_VERSION}]: " ODOO_VERSION
ODOO_VERSION="${ODOO_VERSION:-$DEFAULT_ODOO_VERSION}"

read -r -p "Domain name (e.g. erp.example.com): " DOMAIN_NAME
read -r -p "Email for Let's Encrypt notifications: " LE_EMAIL

export ODOO_VERSION
export DOMAIN_NAME
export LE_EMAIL

run() {
  local f="$1"
  echo "▶ Running $f"
  bash "$f"
  echo
}

run "$ROOT_DIR/install/00_system_update.sh"
run "$ROOT_DIR/install/01_dependencies.sh"
run "$ROOT_DIR/install/02_postgres.sh"
run "$ROOT_DIR/install/03_odoo_user_and_folders.sh"
run "$ROOT_DIR/install/04_clone_odoo.sh"
run "$ROOT_DIR/install/05_python_venv.sh"
run "$ROOT_DIR/install/06_python_dependencies.sh"
run "$ROOT_DIR/install/07_odoo_config.sh"
run "$ROOT_DIR/install/07_systemd_service.sh"
run "$ROOT_DIR/install/07b_init_database.sh"
run "$ROOT_DIR/install/08_ufw_firewall.sh"
run "$ROOT_DIR/install/09_install_oca_zips.sh"
run "$ROOT_DIR/install/10_nginx.sh"

run "$ROOT_DIR/post/00_health_check.sh"
run "$ROOT_DIR/post/10_summary.sh"

echo "✅ Odoo 19 Community installation completed."