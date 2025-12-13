#!/bin/bash
set -e

echo "Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib

echo "Ensuring PostgreSQL service is running..."
systemctl enable postgresql
systemctl start postgresql

echo "Creating PostgreSQL superuser 'odoo' (if not exists)..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1 || sudo -u postgres createuser -s odoo

echo "PostgreSQL setup completed."
