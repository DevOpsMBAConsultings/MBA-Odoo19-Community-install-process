#!/usr/bin/env bash
set -euo pipefail

# Always run from repo root, regardless of where user launched the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

cd "${REPO_ROOT}"

echo "============================================================"
echo " MBA - Odoo Community Install"
echo " Repo: ${REPO_ROOT}"
echo "============================================================"

# --- Defaults ---
DEFAULT_ODOO_VERSION="19"
ALLOW_ODOO_PORT="${ALLOW_ODOO_PORT:-0}"

# --- Collect input ---
read -r -p "Odoo version to install [${DEFAULT_ODOO_VERSION}]: " ODOO_VERSION
ODOO_VERSION="${ODOO_VERSION:-$DEFAULT_ODOO_VERSION}"

read -r -p "Domain name (e.g. erp.example.com): " DOMAIN
DOMAIN="${DOMAIN:-}"

read -r -p "Email for Let's Encrypt notifications: " LETSENCRYPT_EMAIL
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"

if [[ -z "${DOMAIN}" ]]; then
  echo "ERROR: DOMAIN is required."
  exit 1
fi

if [[ -z "${LETSENCRYPT_EMAIL}" ]]; then
  echo "ERROR: LETSENCRYPT_EMAIL is required."
  exit 1
fi

export ODOO_VERSION
export DOMAIN
export LETSENCRYPT_EMAIL
export ALLOW_ODOO_PORT

# --- Verify expected v2 filenames exist before running ---
REQUIRED_FILES=(
  "install/00_system_update.sh"
  "install/01_dependencies.sh"
  "install/02_postgres.sh"
  "install/03_odoo_user_and_folders.sh"
  "install/04_clone_odoo.sh"
  "install/05_python_venv.sh"
  "install/06_python_dependencies.sh"
  "install/07_odoo_config.sh"
  "install/07_systemd_service.sh"
  "install/07b_init_database.sh"
  "install/08_ufw_firewall.sh"
  "install/09_install_oca_zips.sh"
  "install/10_ngnix.sh"
  "post/00_health_check.sh"
  "post/10_summary.sh"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "${REPO_ROOT}/${f}" ]]; then
    echo "ERROR: Missing required file: ${f}"
    echo "You are not on the expected v2 layout, or the repo is incomplete."
    exit 1
  fi
done

chmod +x "${REPO_ROOT}"/install/*.sh "${REPO_ROOT}"/post/*.sh || true

echo ">>> Installing system updates"
sudo bash "${REPO_ROOT}/install/00_system_update.sh"

echo ">>> Installing system dependencies"
sudo bash "${REPO_ROOT}/install/01_dependencies.sh"

echo ">>> Installing PostgreSQL"
sudo bash "${REPO_ROOT}/install/02_postgres.sh"

echo ">>> Creating Odoo user and folders"
sudo bash "${REPO_ROOT}/install/03_odoo_user_and_folders.sh"

echo ">>> Cloning Odoo ${ODOO_VERSION}"
sudo bash "${REPO_ROOT}/install/04_clone_odoo.sh"

echo ">>> Creating Python venv"
sudo bash "${REPO_ROOT}/install/05_python_venv.sh"

echo ">>> Installing Python dependencies"
sudo bash "${REPO_ROOT}/install/06_python_dependencies.sh"

echo ">>> Configuring Odoo"
sudo bash "${REPO_ROOT}/install/07_odoo_config.sh"

echo ">>> Creating systemd service"
sudo bash "${REPO_ROOT}/install/07_systemd_service.sh"

echo ">>> Initializing database"
sudo bash "${REPO_ROOT}/install/07b_init_database.sh"

echo ">>> Configuring firewall"
sudo bash "${REPO_ROOT}/install/08_ufw_firewall.sh"

echo ">>> Installing OCA zips (optional)"
sudo bash "${REPO_ROOT}/install/09_install_oca_zips.sh"

echo ">>> Installing Nginx + SSL"
sudo bash "${REPO_ROOT}/install/10_ngnix.sh"

echo ">>> Post install - health check"
sudo bash "${REPO_ROOT}/post/00_health_check.sh"

echo ">>> Summary"
sudo bash "${REPO_ROOT}/post/10_summary.sh"

echo "✅ Done."