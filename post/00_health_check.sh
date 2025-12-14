#!/bin/bash
set -e

CONF="/etc/odoo19.conf"
SERVICE="odoo19"
PORT="8069"
CUSTOM_ADDONS="/opt/odoo/custom-addons"

echo "==================================="
echo " ✅ Post-Install Health Check (Odoo 19)"
echo " Time: $(date)"
echo "==================================="

echo ""
echo "1) Odoo service status:"
if systemctl is-active --quiet "$SERVICE"; then
  echo "✅ $SERVICE is running"
else
  echo "❌ $SERVICE is NOT running"
  echo "   Check: sudo journalctl -u $SERVICE -n 200 --no-pager"
fi

echo ""
echo "2) wkhtmltopdf version:"
if command -v wkhtmltopdf >/dev/null 2>&1; then
  wkhtmltopdf --version || true
else
  echo "❌ wkhtmltopdf not found"
fi

echo ""
echo "3) Listening ports (local):"
if ss -lntp 2>/dev/null | grep -Eq ":(8069)\s"; then
  echo "✅ Port $PORT is LISTENING locally"
  ss -lntp 2>/dev/null | grep "$PORT" || true
else
  echo "⚠️ Port $PORT is NOT listening locally"
  echo "   Tip: check bind in $CONF (xmlrpc_interface / proxy mode) and logs: sudo journalctl -u $SERVICE -n 200 --no-pager"
fi

echo ""
echo "4) UFW status and port $PORT rule:"
if command -v ufw >/dev/null 2>&1; then
  ufw status | head -n 25
  if ufw status | grep -q "$PORT/tcp"; then
    echo "✅ UFW rule found for $PORT/tcp"
  else
    echo "⚠️ No UFW rule for $PORT/tcp (may be intentional)"
  fi
else
  echo "⚠️ ufw not installed"
fi

echo ""
echo "5) addons_path check:"
if [ -f "$CONF" ]; then
  grep -E "^addons_path" "$CONF" || true
  if grep -E "^addons_path" "$CONF" | grep -q "$CUSTOM_ADDONS"; then
    echo "✅ custom-addons is included in addons_path"
  else
    echo "❌ custom-addons is NOT in addons_path"
  fi
else
  echo "❌ Config not found: $CONF"
fi

echo ""
echo "6) OCA modules present in custom-addons:"
if [ -d "$CUSTOM_ADDONS" ]; then
  find "$CUSTOM_ADDONS" -maxdepth 2 -type f -name "__manifest__.py" | sort | head -n 100

  if [ -f "$CUSTOM_ADDONS/base_account_budget/__manifest__.py" ]; then
    echo "✅ base_account_budget detected"
  else
    echo "⚠️ base_account_budget NOT detected"
  fi

  if [ -f "$CUSTOM_ADDONS/base_accounting_kit/__manifest__.py" ]; then
    echo "✅ base_accounting_kit detected"
  else
    echo "⚠️ base_accounting_kit NOT detected"
  fi
else
  echo "❌ Directory not found: $CUSTOM_ADDONS"
fi

echo ""
echo "7) Odoo Master Password (admin_passwd):"
if [ -f "$CONF" ]; then
  ADMIN_PASSWD=$(grep -E "^\s*admin_passwd\s*=" "$CONF" | cut -d'=' -f2 | xargs || true)
  if [ -n "$ADMIN_PASSWD" ]; then
    echo "✅ Master password found:"
    echo "   admin_passwd = $ADMIN_PASSWD"
    echo "   (Stored in $CONF)"
  else
    echo "⚠️ admin_passwd not set in $CONF"
  fi
else
  echo "❌ Config not found: $CONF"
fi

echo ""
echo "==================================="
echo " ✅ Health check finished"
echo "==================================="
