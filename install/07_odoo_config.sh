#!/usr/bin/env bash
set -e

echo "Configuring Odoo ${ODOO_VERSION}..."

ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
ODOO_LOG="/var/log/odoo"
ODOO_DATA="/var/lib/odoo"
ODOO_USER="odoo"

# Ensure directories exist
mkdir -p "${ODOO_LOG}" "${ODOO_DATA}"
chown -R ${ODOO_USER}:${ODOO_USER} "${ODOO_LOG}" "${ODOO_DATA}"
chmod 750 "${ODOO_LOG}" "${ODOO_DATA}"

# Generate config from template
envsubst < templates/odoo.conf.template > "${ODOO_CONF}"

# Secure config
chown ${ODOO_USER}:${ODOO_USER} "${ODOO_CONF}"
chmod 640 "${ODOO_CONF}"

echo "Odoo config created at ${ODOO_CONF}"