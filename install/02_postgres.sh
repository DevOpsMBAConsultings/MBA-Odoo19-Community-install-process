#!/bin/bash
set -e

echo "Installing PostgreSQL..."
apt update -y
apt install -y postgresql postgresql-contrib

echo "Ensuring PostgreSQL service is running..."
systemctl enable postgresql
systemctl start postgresql

echo "Checking for existing PostgreSQL role 'odoo'..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
  echo "Role 'odoo' already exists — skipping creation."
else
  echo "Creating PostgreSQL superuser 'odoo'..."
  sudo -u postgres createuser -s odoo
fi

echo "Validating PostgreSQL access for 'odoo'..."
sudo -u odoo psql -c "\l" >/dev/null

echo "PostgreSQL setup completed successfully."
