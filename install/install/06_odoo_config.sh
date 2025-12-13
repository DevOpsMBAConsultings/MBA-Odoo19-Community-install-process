#!/bin/bash
set -e

ODOO_CONF="/etc/odoo19.conf"
TEMPLATE="/opt/odoo/odoo19-community-installer/config/odoo19.conf.template"

# When repo is cloned, it will live somewhere else.
# So we derive template path from current script location:
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$SCRIPT_DIR/config/odoo19.conf.template"

echo "Generating $ODOO_CONF from template..."

if [ ! -f "$TEMPLATE" ]; then
  echo "❌ Template not found at: $TEMPLATE"
  exit 1
fi

# Generate a strong default admin password if not provided
ADMIN_PASSWD=$(openssl rand -hex 16)

sed "s/{{ADMIN_PASSWD}}/$ADMIN_PASSWD/g" "$TEMPLATE" > "$ODOO_CONF"

chown odoo:odoo "$ODOO_CONF"
chmod 640 "$ODOO_CONF"

echo "✅ Created $ODOO_CONF"
echo "IMPORTANT: Your Odoo master password (admin_passwd) is:"
echo "$ADMIN_PASSWD"
echo "Save it somewhere safe."
