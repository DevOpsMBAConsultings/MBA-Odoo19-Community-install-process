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
  # Wait until apt/dpkg locks are free (cloud-init / unattended-upgrades, etc.)
  # Avoids: "Could not get lock /var/lib/apt/lists/lock"
  local max_seconds="${1:-300}"   # 5 minutes default
  local interval="${2:-5}"

  echo "Checking for apt/dpkg locks (max ${max_seconds}s)..."

  local waited=0
  while true; do
    # Any process holding common locks?
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

    # Also handle: apt is running but lock not detected via fuser (rare)
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
  # Runs a script ensuring:
  # - we execute from repo root (so relative paths inside scripts work)
  # - environment variables are preserved for scripts that need DOMAIN/EMAIL/etc.
  local script_rel="$1"
  local title="$2"
  local needs_apt="${3:-0}"   # 1 => run wait_for_apt before step

  echo
  echo ">>> ${title}"
  echo "    Script: ${script_rel}"

  if [[ "${needs_apt}" == "1" ]]; then
    wait_for_apt 300 5
  fi

  # Force execution from repo root so relative paths resolve correctly
  ( cd "${REPO_ROOT}" && sudo -E bash "${REPO_ROOT}/${script_rel}" )
}

# -------------------------------------------------------------------
# Defaults / Input
# -------------------------------------------------------------------

DEFAULT_ODOO_VERSION="19"
ALLOW_ODOO_PORT="${ALLOW_ODOO_PORT:-0}"

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
export REPO_ROOT   # allows scripts to use it if they want

# -------------------------------------------------------------------
# Verify expected v2 filenames exist before running
# -------------------------------------------------------------------

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

# -------------------------------------------------------------------
# Run steps (with apt lock protection on apt-related ones)
# -------------------------------------------------------------------

run_step "install/00_system_update.sh"        "Installing system updates"                1
run_step "install/01_dependencies.sh"         "Installing system dependencies"           1
run_step "install/02_postgres.sh"             "Installing PostgreSQL"                    1
run_step "install/03_odoo_user_and_folders.sh" "Creating Odoo user and folders"          0
run_step "install/04_clone_odoo.sh"           "Cloning Odoo ${ODOO_VERSION}"             1
run_step "install/05_python_venv.sh"          "Creating Python venv"                     1
run_step "install/06_python_dependencies.sh"  "Installing Python dependencies"           1
run_step "install/07_odoo_config.sh"          "Configuring Odoo"                         0
run_step "install/07_systemd_service.sh"      "Creating systemd service"                 0
run_step "install/07b_init_database.sh"       "Initializing database"                    0
run_step "install/08_ufw_firewall.sh"         "Configuring firewall"                     1
run_step "install/09_install_oca_zips.sh"     "Installing OCA zips (optional)"           0
run_step "install/10_ngnix.sh"                "Installing Nginx + SSL"                   1
run_step "post/00_health_check.sh"            "Post install - health check"              0
run_step "post/10_summary.sh"                 "Summary"                                  0

echo
echo "✅ Done."