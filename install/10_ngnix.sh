#!/bin/bash
set -e

INSTALL_NGINX="${INSTALL_NGINX:-0}"
EMAIL_DEFAULT="info@mbaconsultings.com"

if [ "$INSTALL_NGINX" != "1" ]; then
  echo "Skipping Nginx install (set INSTALL_NGINX=1 to enable)."
  exit 0
fi

DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-$EMAIL_DEFAULT}"
ODOO_VER="${ODOO_VERSION:-19}"
ODOO_PORT="${ODOO_PORT:-8069}"
LONGPOLL_PORT="${LONGPOLL_PORT:-8072}"

if [ -z "$DOMAIN" ]; then
  echo "❌ DOMAIN is required when INSTALL_NGINX=1 (e.g., DOMAIN=trucksolutiongp.mbaconsultings.com)"
  exit 1
fi

echo "=== Nginx + SSL setup ==="
echo "Domain: $DOMAIN"
echo "Email:  $EMAIL"
echo "Upstream: 127.0.0.1:${ODOO_PORT} (longpolling ${LONGPOLL_PORT})"

# DNS preflight: ensure domain resolves before attempting certbot
if command -v dig >/dev/null 2>&1; then
  RESOLVED_IP="$(dig +short "$DOMAIN" | head -n 1 || true)"
  if [ -z "$RESOLVED_IP" ]; then
    echo "❌ DNS check failed: '$DOMAIN' does not resolve yet."
    echo "   Fix DNS A record, then retry."
    exit 1
  fi
  echo "✅ DNS resolves: $DOMAIN -> $RESOLVED_IP"
else
  echo "⚠️ 'dig' not found; installing dnsutils for DNS validation..."
  apt update -y
  apt install -y dnsutils
  RESOLVED_IP="$(dig +short "$DOMAIN" | head -n 1 || true)"
  if [ -z "$RESOLVED_IP" ]; then
    echo "❌ DNS check failed: '$DOMAIN' does not resolve yet."
    echo "   Fix DNS A record, then retry."
    exit 1
  fi
  echo "✅ DNS resolves: $DOMAIN -> $RESOLVED_IP"
fi

echo "Installing Nginx..."
apt update -y
apt install -y nginx

echo "Configuring Nginx site for Odoo..."
NGINX_SITE="/etc/nginx/sites-available/odoo${ODOO_VER}.conf"

cat > "$NGINX_SITE" <<EOF
upstream odoo_upstream_${ODOO_VER} {
    server 127.0.0.1:${ODOO_PORT};
}

server {
    listen 80;
    server_name ${DOMAIN};

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    access_log /var/log/nginx/odoo${ODOO_VER}_access.log;
    error_log  /var/log/nginx/odoo${ODOO_VER}_error.log;

    location / {
        proxy_pass http://odoo_upstream_${ODOO_VER};
    }

    location /longpolling/ {
        proxy_pass http://127.0.0.1:${LONGPOLL_PORT};
    }

    gzip on;
    gzip_types text/css text/plain text/xml application/xml application/json application/javascript;
}
EOF

ln -sf "$NGINX_SITE" "/etc/nginx/sites-enabled/odoo${ODOO_VER}.conf"

# Disable default site if present
if [ -f /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default
fi

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "✅ Nginx installed and configured."

echo "Installing Certbot..."
apt install -y certbot python3-certbot-nginx

# Certbot requires inbound 80 reachable from the internet for HTTP-01 challenge
echo "Requesting Let's Encrypt certificate for ${DOMAIN}..."
certbot --nginx -d "$DOMAIN" \
  --non-interactive --agree-tos \
  -m "$EMAIL" \
  --redirect

systemctl reload nginx

echo "✅ SSL enabled: https://${DOMAIN}"