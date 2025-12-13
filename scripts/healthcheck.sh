#!/bin/bash

set -e

echo "=== Odoo 19 Healthcheck ==="
echo "Time: $(date)"
echo ""

echo "Service status:"
systemctl is-active odoo19 && echo "✅ odoo19 is active" || (echo "❌ odoo19 is not active"; exit 1)

echo ""
echo "Listening ports (8069/8072):"
ss -lntp | grep -E ':8069|:8072' || echo "⚠️ Ports not found yet (give it 10-30 seconds after restart)"

echo ""
echo "HTTP response (localhost:8069):"
curl -I --max-time 5 http://127.0.0.1:8069 | head -n 1 || echo "⚠️ No HTTP response yet"

echo ""
echo "Last 20 Odoo logs:"
journalctl -u odoo19 -n 20 --no-pager
