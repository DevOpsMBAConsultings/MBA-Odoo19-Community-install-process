#!/bin/bash
set -e

LOG_FILE="/var/log/odoo19-install.log"

echo "===================================" | tee -a "$LOG_FILE"
echo " MBA Odoo Community Installer"       | tee -a "$LOG_FILE"
echo " Started at: $(date)"               | tee -a "$LOG_FILE"
echo "===================================" | tee -a "$LOG_FILE"

if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (sudo ./install.sh)" | tee -a "$LOG_FILE"
  exit 1
fi

# -------------------------
# Version selection
# -------------------------
# Non-interactive default is 19. You can override:
#   sudo ODOO_VERSION=18 ./install.sh
if [ -z "${ODOO_VERSION:-}" ]; then
  ODOO_VERSION="19"
fi

# Optional interactive prompt only if running in a real TTY
if [ -t 0 ] && [ -z "${ODOO_VERSION_SET_BY_USER:-}" ]; then
  # If user explicitly sets ODOO_VERSION, we do not prompt.
  if [ "${ODOO_VERSION:-}" = "19" ]; then
    read -r -p "Enter Odoo major version to install [default: 19]: " INPUT_VER || true
    if [ -n "${INPUT_VER:-}" ]; then
      ODOO_VERSION="$INPUT_VER"
    fi
  fi
fi

# Standardize database name per version
DB_NAME="odoo${ODOO_VERSION}"

export ODOO_VERSION
export DB_NAME

echo "▶ Target: Odoo ${ODOO_VERSION} | Database: ${DB_NAME}" | tee -a "$LOG_FILE"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# -------------------------
# Install steps
# -------------------------
for script in $(ls -1 "$SCRIPT_DIR"/install/*.sh 2>/dev/null | sort); do
  echo "▶ Running $script" | tee -a "$LOG_FILE"
  bash "$script" 2>&1 | tee -a "$LOG_FILE"
done

# -------------------------
# Post-install checks
# -------------------------
POST_DIR="$SCRIPT_DIR/post"
if [ -d "$POST_DIR" ]; then
  for script in $(ls -1 "$POST_DIR"/*.sh 2>/dev/null | sort); do
    echo "▶ Running $script" | tee -a "$LOG_FILE"
    bash "$script" 2>&1 | tee -a "$LOG_FILE"
  done
fi

echo "===================================" | tee -a "$LOG_FILE"
echo " ✅ Odoo install + checks completed" | tee -a "$LOG_FILE"
echo "===================================" | tee -a "$LOG_FILE"