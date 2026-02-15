#!/usr/bin/env bash
set -euo pipefail

echo "Configuring UFW firewall..."

# Install ufw if missing
if ! command -v ufw >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y ufw
fi

# Reset and configure rules
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow OpenSSH
ufw allow 80
ufw allow 443
# Allow direct Odoo port only when not using Nginx (set ALLOW_ODOO_PORT=1 before running install)
if [[ "${ALLOW_ODOO_PORT:-0}" == "1" ]]; then
  ufw allow 8069/tcp
  echo "Port 8069 (Odoo) allowed for direct access."
fi

# Enable ufw (non-interactive)
ufw --force enable

# 🔴 CRITICAL: force netfilter + ufw to actually bind
echo "Forcing firewall rules to apply (cloud-init workaround)..."

systemctl stop ufw
iptables -F
iptables -X
ip6tables -F || true
ip6tables -X || true
systemctl start ufw

# Final verification
ufw status verbose

echo "✅ UFW configured and force-applied."
