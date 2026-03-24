#!/bin/bash
# System Configuration Deployment Script
# This script applies system-level configurations that require root privileges

set -e  # Exit on error

echo "⚙️  Applying system configurations..."

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run with sudo"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Apply Firewall Rules
if [ -f "$SCRIPT_DIR/firewall/nftables-pi5-fixed.conf" ]; then
    echo "🔥 Applying firewall rules..."
    cp "$SCRIPT_DIR/firewall/nftables-pi5-fixed.conf" /etc/nftables.conf
    systemctl reload nftables
    echo "✅ Firewall rules applied"
else
    echo "⚠️  Firewall config not found: $SCRIPT_DIR/firewall/nftables-pi5-fixed.conf"
fi

# Apply Docker Daemon Configuration
if [ -f "$SCRIPT_DIR/docker-daemon.json" ]; then
    echo "🐳 Applying Docker daemon configuration..."
    cp "$SCRIPT_DIR/docker-daemon.json" /etc/docker/daemon.json
    systemctl reload docker
    echo "✅ Docker daemon configuration applied"
else
    echo "⚠️  Docker daemon config not found: $SCRIPT_DIR/docker-daemon.json"
fi

# Apply Nginx Configuration (if nginx is installed)
if [ -d "/etc/nginx" ] && [ -f "$SCRIPT_DIR/nginx/nginx.conf" ]; then
    echo "🌐 Applying Nginx configuration..."
    cp "$SCRIPT_DIR/nginx/nginx.conf" /etc/nginx/nginx.conf
    nginx -t && systemctl reload nginx
    echo "✅ Nginx configuration applied"
else
    echo "ℹ️  Nginx not installed or config not found, skipping..."
fi

# Apply Logrotate Configuration
if [ -d "$SCRIPT_DIR/logrotate/configs" ]; then
    echo "🔄 Applying logrotate configurations..."
    cd "$SCRIPT_DIR/logrotate"
    ./scripts/setup-logrotate.sh
    echo "✅ Logrotate configurations applied"
else
    echo "ℹ️  Logrotate configs not found, skipping..."
fi

echo ""
echo "✅ System configuration deployment complete!"
echo ""
echo "Applied configurations:"
echo "  - Firewall rules (nftables)"
echo "  - Docker daemon settings"
echo "  - Nginx configuration (if applicable)"
echo "  - Logrotate configurations"

# Made with Bob
