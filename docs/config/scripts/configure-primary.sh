#!/bin/bash
# Primary Router Configuration Script
set -e

echo "Configuring Primary Entry Router..."

# Create necessary directories
mkdir -p /var/log/oblivion
mkdir -p /etc/wireguard

# Copy WireGuard configuration
cp /etc/oblivion/wg0.conf /etc/wireguard/wg0.conf

# Set up WireGuard interface
echo "Setting up WireGuard interface..."
wg-quick up wg0 || echo "WireGuard interface may already be up"

# Configure firewall rules
echo "Applying firewall rules..."
if [ -f /etc/oblivion/firewall.rules ]; then
    if command -v iptables-restore >/dev/null 2>&1; then
        iptables-restore < /etc/oblivion/firewall.rules || echo "Warning: Could not apply firewall rules"
    else
        echo "Warning: iptables-restore not found, skipping firewall rules"
    fi
fi

# Configure geographic routing
echo "Setting up geographic routing..."
if [ -f /etc/oblivion/routes.conf ]; then
    while read -r route; do
        [ -n "$route" ] && [ "${route#\#}" = "$route" ] && ip route add $route || echo "Route may already exist: $route"
    done < /etc/oblivion/routes.conf
fi

# Configure ZTNA if enabled
if [ "${ZTNA_ENABLED}" = "true" ]; then
    echo "Configuring ZTNA (Zero Trust Network Access)..."
    if [ -f /etc/oblivion/ztna.conf ]; then
        mkdir -p /etc/ztna
        cp /etc/oblivion/ztna.conf /etc/ztna/config.conf || echo "Warning: Could not copy ZTNA config"
    else
        echo "No ZTNA configuration found, using defaults"
    fi
fi

# Set up monitoring
echo "Starting packet monitoring..."
if command -v oblivion_suspect_monitoring >/dev/null 2>&1; then
    oblivion_suspect_monitoring --daemonize --log-file /var/log/oblivion/monitoring.log || echo "Warning: Could not start monitoring"
fi

# IP forwarding is handled by sysctls in docker-compose.yml
echo "IP forwarding configured via container sysctls"

echo "Primary router configuration completed"
echo "Router ready to accept connections on port ${WIREGUARD_PORT:-51820}"