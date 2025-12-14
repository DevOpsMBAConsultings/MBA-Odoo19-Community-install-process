#!/bin/bash
set -e

ODOO_CONF="/etc/odoo19.conf"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$SCRIPT_DIR/config/odoo19.conf.template"

echo "Generating $ODOO_CONF from template..."

if [ ! -f "$TEMPLATE" ]; then
  echo "❌ Template not found at: $TEMPLATE"
  exit 1
fi

# Use provided admin passwd or generate secure random one
if [ -n "$ODOO_ADMIN_PASSWD" ]; then
  ADMIN_PASSWD="$ODOO_ADMIN_PASSWD"
else
  ADMIN_PASSWD=$(openssl rand -hex 16)
fi

sed "s/{{ADMIN_PASSWD}}/$ADMIN_PASSWD/g" "$TEMPLATE" > "$ODOO_CONF"

chown odoo:odoo "$ODOO_CONF"
chmod 640 "$ODOO_CONF"

echo "✅ Created $ODOO_CONF"
echo "IMPORTANT: Your Odoo master password (admin_passwd) is:"
echo "$ADMIN_PASSWD"
echo "Save it somewhere safe."
