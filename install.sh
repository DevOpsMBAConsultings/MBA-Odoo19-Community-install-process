#!/bin/bash
set -e

LOG_FILE="/var/log/odoo19-install.log"

echo "===================================" | tee -a "$LOG_FILE"
echo " MBA Odoo 19 Community Installer"    | tee -a "$LOG_FILE"
echo " Started at: $(date)"               | tee -a "$LOG_FILE"
echo "===================================" | tee -a "$LOG_FILE"

if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (sudo ./install.sh)"
  exit 1
fi

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
echo " ✅ Odoo 19 install + checks completed" | tee -a "$LOG_FILE"
echo "===================================" | tee -a "$LOG_FILE"
