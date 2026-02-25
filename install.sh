#!/usr/bin/env bash
set -euo pipefail

# Always run from repo root, regardless of where user launched the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

cd "${REPO_ROOT}"

echo "============================================================"
echo " MBA - Odoo Community Install (v2)"
echo " Repo: ${REPO_ROOT}"
echo "============================================================"

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

wait_for_apt() {
  local max_seconds="${1:-300}"
  local interval="${2:-5}"

  echo "Checking for apt/dpkg locks (max ${max_seconds}s)..."

  local waited=0
  while true; do
    if sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
      || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
      || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
      || sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then

      if (( waited >= max_seconds )); then
        echo "ERROR: apt/dpkg locks still held after ${max_seconds}s."
        echo "Try waiting a bit more, or check what's running:"
        echo "  ps aux | egrep 'apt|dpkg|unattended|cloud-init' | grep -v egrep"
        exit 1
      fi

      echo "apt/dpkg is busy... waiting ${interval}s (waited ${waited}s)"
      sleep "${interval}"
      waited=$((waited + interval))
      continue
    fi

    if pgrep -x apt >/dev/null 2>&1 || pgrep -x dpkg >/dev/null 2>&1; then
      if (( waited >= max_seconds )); then
        echo "ERROR: apt/dpkg processes still running after ${max_seconds}s."
        echo "Check:"
        echo "  ps aux | egrep 'apt|dpkg|unattended|cloud-init' | grep -v egrep"
        exit 1
      fi
      echo "apt/dpkg processes detected... waiting ${interval}s (waited ${waited}s)"
      sleep "${interval}"
      waited=$((waited + interval))
      continue
    fi

    echo "apt/dpkg locks are free."
    break
  done
}

run_step() {
  local script_rel="$1"
  local title="$2"
  local needs_apt="${3:-0}"

  echo
  echo ">>> ${title}"
  echo "    Script: ${script_rel}"

  if [[ "${needs_apt}" == "1" ]]; then
    wait_for_apt 300 5
  fi

  ( cd "${REPO_ROOT}" && sudo -E bash "${REPO_ROOT}/${script_rel}" )
}

# -------------------------------------------------------------------
# Defaults / Input
# -------------------------------------------------------------------

DEFAULT_ODOO_VERSION="19"
ALLOW_ODOO_PORT="${ALLOW_ODOO_PORT:-0}"

read -r -p "Odoo version to install [${DEFAULT_ODOO_VERSION}]: " ODOO_VERSION
ODOO_VERSION="${ODOO_VERSION:-$DEFAULT_ODOO_VERSION}"

while [[ -z "${DOMAIN:-}" ]]; do
  read -r -p "Domain name (e.g. erp.example.com): " DOMAIN
  if [[ -z "${DOMAIN}" ]]; then
    # If running non-interactively, fail to avoid infinite loop
    if [[ ! -t 0 ]]; then echo "ERROR: DOMAIN is required."; exit 1; fi
    echo "❌ Domain is required."
  fi
done

while [[ -z "${LETSENCRYPT_EMAIL:-}" ]]; do
  read -r -p "Email for Let's Encrypt notifications: " LETSENCRYPT_EMAIL
  if [[ -z "${LETSENCRYPT_EMAIL}" ]]; then
    if [[ ! -t 0 ]]; then echo "ERROR: LETSENCRYPT_EMAIL is required."; exit 1; fi
    echo "❌ Email is required."
  fi
done

read -r -p "GitHub Token (Optional, for cloning private addons): " GITHUB_TOKEN

# -------------------------------------------------------------------
# Optional: remote SSL storage (certificates survive server reprovisioning)
# Prompt at runtime so the repo stays public without secrets.
# -------------------------------------------------------------------
echo ""
echo "Remote SSL storage (optional): store/restore certificates in S3/R2 so new servers reuse the cert."
read -r -p "Use remote SSL storage? (s3/url/no) [no]: " ODOO_SSL_STORAGE
ODOO_SSL_STORAGE="${ODOO_SSL_STORAGE:-no}"

if [[ "${ODOO_SSL_STORAGE}" == "s3" ]]; then
  read -r -p "S3/R2 bucket name [odoo-ssl-certs]: " ODOO_SSL_S3_BUCKET
  ODOO_SSL_S3_BUCKET="${ODOO_SSL_S3_BUCKET:-odoo-ssl-certs}"
  read -r -p "S3 endpoint URL (empty = AWS S3; for R2: https://ACCOUNT_ID.r2.cloudflarestorage.com): " ODOO_SSL_S3_ENDPOINT_URL
  read -r -p "Access Key ID: " AWS_ACCESS_KEY_ID
  read -s -r -p "Secret Access Key (hidden): " AWS_SECRET_ACCESS_KEY
  echo ""
  [[ -z "${AWS_ACCESS_KEY_ID}" || -z "${AWS_SECRET_ACCESS_KEY}" ]] && { echo "Access Key and Secret are required for S3. Skipping remote storage."; ODOO_SSL_STORAGE=""; }
  export ODOO_SSL_S3_BUCKET
  export ODOO_SSL_S3_ENDPOINT_URL
  export AWS_ACCESS_KEY_ID
  export AWS_SECRET_ACCESS_KEY
elif [[ "${ODOO_SSL_STORAGE}" == "url" ]]; then
  read -r -p "Restore URL (GET .tar.gz): " ODOO_SSL_RESTORE_URL
  read -r -p "Backup URL (PUT .tar.gz, optional): " ODOO_SSL_BACKUP_URL
  read -r -p "Backup token (optional): " ODOO_SSL_BACKUP_TOKEN
  export ODOO_SSL_RESTORE_URL
  export ODOO_SSL_BACKUP_URL
  export ODOO_SSL_BACKUP_TOKEN
else
  ODOO_SSL_STORAGE=""
  unset ODOO_SSL_S3_BUCKET ODOO_SSL_S3_ENDPOINT_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY 2>/dev/null || true
  unset ODOO_SSL_RESTORE_URL ODOO_SSL_BACKUP_URL ODOO_SSL_BACKUP_TOKEN 2>/dev/null || true
fi

# Odoo standard modules to install at init (default: sale,purchase,crm,stock,contacts,account). Leave empty for none.
read -r -p "Odoo standard modules to install [sale,purchase,crm,stock,contacts,account]: " ODOO_EXTRA_MODULES
ODOO_EXTRA_MODULES="${ODOO_EXTRA_MODULES:-sale,purchase,crm,stock,contacts,account}"

export ODOO_SSL_STORAGE
export ODOO_VERSION
export DOMAIN
export LETSENCRYPT_EMAIL
export GITHUB_TOKEN
export ODOO_EXTRA_MODULES
export ALLOW_ODOO_PORT
export REPO_ROOT

# -------------------------------------------------------------------
# Verify expected v2 filenames exist before running
# -------------------------------------------------------------------

REQUIRED_FILES=(
  "install/00_system_update.sh"
  "install/01_dependencies.sh"
  "install/02_postgres.sh"
  "install/02_wkhtmltopdf.sh"
  "install/03_odoo_user_and_folders.sh"
  "install/04_clone_odoo.sh"
  "install/05_python_venv.sh"
  "install/06_python_dependencies.sh"
  "install/07_odoo_config.sh"
  "install/07_systemd_service.sh"
  "install/08_clone_custom_addons.sh"
  "install/09_init_database.sh"
  "install/10_ufw_firewall.sh"
  "install/11_ngnix.sh"
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

# -------------------------------------------------------------------
# Run steps (with apt lock protection on apt-related ones)
# -------------------------------------------------------------------

run_step "install/00_system_update.sh"         "Installing system updates"                 1
run_step "install/01_dependencies.sh"          "Installing system dependencies"            1
run_step "install/02_postgres.sh"              "Installing PostgreSQL"                     1
run_step "install/02_wkhtmltopdf.sh"           "Installing wkhtmltopdf (patched)"          1
run_step "install/03_odoo_user_and_folders.sh" "Creating Odoo user and folders"            0
run_step "install/04_clone_odoo.sh"            "Cloning Odoo ${ODOO_VERSION}"              1
run_step "install/05_python_venv.sh"           "Creating Python venv"                      1
run_step "install/06_python_dependencies.sh"   "Installing Python dependencies"            1
run_step "install/07_odoo_config.sh"           "Configuring Odoo"                          0
run_step "install/07_systemd_service.sh"       "Creating systemd service"                  0
run_step "install/08_clone_custom_addons.sh"   "Cloning custom addons from Git"            1
run_step "install/09_init_database.sh"          "Initializing database"                     0
run_step "install/10_ufw_firewall.sh"          "Configuring firewall"                      1
run_step "install/11_ngnix.sh"                 "Installing Nginx + SSL"                    1
run_step "post/00_health_check.sh"             "Post install - health check"               0
run_step "post/10_summary.sh"                  "Summary"                                   0

echo
echo "✅ Done."
