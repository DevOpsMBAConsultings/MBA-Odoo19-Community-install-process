#!/usr/bin/env bash
set -euo pipefail

echo "Installing and configuring Nginx + SSL..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NGINX_TEMPLATE="${REPO_ROOT}/templates/nginx-odoo.conf.template"
NGINX_SITE="/etc/nginx/sites-available/${DOMAIN}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}"

if [[ -z "${DOMAIN:-}" ]]; then
  echo "ERROR: DOMAIN is missing."
  exit 1
fi

if [[ -z "${LETSENCRYPT_EMAIL:-}" ]]; then
  echo "ERROR: LETSENCRYPT_EMAIL is missing."
  exit 1
fi

if [[ ! -f "${NGINX_TEMPLATE}" ]]; then
  echo "ERROR: Missing template: ${NGINX_TEMPLATE}"
  exit 1
fi

sudo apt update -y
sudo apt install -y nginx certbot python3-certbot-nginx

# Render nginx site config
sudo bash -c "sed \
  -e 's|{{DOMAIN}}|${DOMAIN}|g' \
  -e 's|{{ODOO_PORT}}|8069|g' \
  '${NGINX_TEMPLATE}' > '${NGINX_SITE}'"

sudo ln -sf "${NGINX_SITE}" "${NGINX_ENABLED}"

sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

# Obtain/renew cert
sudo certbot --nginx \
  -d "${DOMAIN}" \
  -m "${LETSENCRYPT_EMAIL}" \
  --agree-tos \
  --non-interactive \
  --redirect || true

sudo systemctl reload nginx
echo "✅ Nginx + SSL configured for ${DOMAIN}"