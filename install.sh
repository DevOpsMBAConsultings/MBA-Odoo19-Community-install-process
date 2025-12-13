#!/bin/bash
set -e

LOG_FILE="/var/log/odoo19-install.log"

echo "===================================" | tee -a $LOG_FILE
echo " MBA Odoo 19 Community Installer"    | tee -a $LOG_FILE
echo " Started at: $(date)"                | tee -a $LOG_FILE
echo "===================================" | tee -a $LOG_FILE

if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (sudo ./install.sh)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for script in "$SCRIPT_DIR"/install/*.sh; do
  echo "▶ Running $script" | tee -a $LOG_FILE
  bash "$script" | tee -a $LOG_FILE
done

echo "===================================" | tee -a $LOG_FILE
echo " ✅ Odoo 19 install completed"       | tee -a $LOG_FILE
echo "===================================" | tee -a $LOG_FILE
