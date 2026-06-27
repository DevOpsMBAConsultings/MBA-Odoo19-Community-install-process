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
ufw allow 8069/tcp
ufw allow 8072/tcp
echo "Port 8069 (Odoo) allowed by default."

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

# 🔴 FALLBACK: Añadir reglas explícitas de iptables por si netfilter-persistent bloquea a UFW
echo "Adding direct iptables rules for strict environments..."
iptables -I INPUT 1 -p tcp -m state --state NEW -m tcp --dport 8069 -j ACCEPT || true
iptables -I INPUT 2 -p tcp -m state --state NEW -m tcp --dport 8072 -j ACCEPT || true

if command -v netfilter-persistent >/dev/null 2>&1; then
  echo "Saving iptables with netfilter-persistent..."
  netfilter-persistent save || true
elif command -v iptables-save >/dev/null 2>&1; then
  echo "Saving iptables with iptables-save..."
  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4 || true
fi

# Final verification
ufw status verbose

echo "✅ UFW configured and force-applied."
