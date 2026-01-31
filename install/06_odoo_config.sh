#!/bin/bash
set -e

ODOO_VER="${ODOO_VERSION:-19}"
DB_NAME="${DB_NAME:-odoo19}"

ODOO_CONF="/etc/odoo${ODOO_VER}.conf"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$SCRIPT_DIR/config/odoo19.conf.template"

ROOT_SECRET_FILE="/root/odoo${ODOO_VER}.master_password"

echo "Generating ${ODOO_CONF} from template..."

if [ ! -f "$TEMPLATE" ]; then
  echo "❌ Template not found at: $TEMPLATE"
  exit 1
fi

# Use provided admin passwd or generate secure random one
if [ -n "${ODOO_ADMIN_PASSWD:-}" ]; then
  ADMIN_PASSWD="$ODOO_ADMIN_PASSWD"
else
  ADMIN_PASSWD="$(openssl rand -hex 16)"
fi

# Save master password securely (do not print it, since installer logs everything)
umask 077
echo -n "$ADMIN_PASSWD" > "$ROOT_SECRET_FILE"
chmod 600 "$ROOT_SECRET_FILE"

# Substitute placeholders
sed -e "s/{{ADMIN_PASSWD}}/${ADMIN_PASSWD}/g" \
    -e "s/{{DB_NAME}}/${DB_NAME}/g" \
    -e "s/{{ODOO_VERSION}}/${ODOO_VER}/g" \
    "$TEMPLATE" > "$ODOO_CONF"

chown odoo:odoo "$ODOO_CONF"
chmod 640 "$ODOO_CONF"

echo "✅ Created $ODOO_CONF"
echo "✅ Master password saved to: $ROOT_SECRET_FILE"