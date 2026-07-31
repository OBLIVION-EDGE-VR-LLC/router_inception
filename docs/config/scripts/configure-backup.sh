#!/bin/bash
# Backup Router Configuration Script
set -e

echo "Configuring Backup Router..."

# Create necessary directories
mkdir -p /var/log/oblivion
mkdir -p /etc/wireguard

# Copy WireGuard configuration if available
if [ -f /etc/oblivion/wg0.conf ]; then
    cp /etc/oblivion/wg0.conf /etc/wireguard/wg0.conf
    echo "Setting up backup WireGuard interface..."
    wg-quick up wg0 || echo "WireGuard interface may already be up"
else
    echo "No WireGuard configuration found - backup router in standby mode"
fi

# Configure failover monitoring
if [ "${FAILOVER_ENABLED}" = "true" ]; then
    echo "Configuring failover monitoring..."

    # Monitor primary router health
    HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-30}
    echo "Health check interval: ${HEALTH_CHECK_INTERVAL} seconds"

    # Create health check script
    cat > /usr/local/bin/failover-monitor.sh << 'EOF'
#!/bin/bash
PRIMARY_IP="172.20.0.10"
RUSSIA_IP="172.20.0.20"
HEALTH_CHECK_INTERVAL=${HEALTH_CHECK_INTERVAL:-30}

echo "Starting failover monitoring for backup router..."

while true; do
    # Check primary router health
    if ! ping -c 1 -W 3 $PRIMARY_IP >/dev/null 2>&1; then
        echo "$(date): Primary router ($PRIMARY_IP) unreachable - potential failover needed"

        # Check Russia hop as secondary indicator
        if ! ping -c 1 -W 3 $RUSSIA_IP >/dev/null 2>&1; then
            echo "$(date): Russia hop ($RUSSIA_IP) also unreachable - network may be down"
        fi
    else
        echo "$(date): Primary router health OK"
    fi

    sleep $HEALTH_CHECK_INTERVAL
done
EOF

    chmod +x /usr/local/bin/failover-monitor.sh

    # Start failover monitoring in background
    /usr/local/bin/failover-monitor.sh > /var/log/oblivion/failover.log 2>&1 &
    echo $! > /var/run/failover-monitor.pid
fi

# Apply basic firewall rules
echo "Applying backup router firewall rules..."
if [ -f /etc/oblivion/firewall.rules ]; then
    /usr/bin/iptables-restore < /etc/oblivion/firewall.rules || echo "Warning: Could not apply firewall rules"
fi

# Configure monitoring
echo "Starting backup router monitoring..."
if command -v oblivion_suspect_monitoring >/dev/null 2>&1; then
    oblivion_suspect_monitoring \
        --daemonize \
        --role backup \
        --log-file /var/log/oblivion/monitoring.log || echo "Warning: Could not start monitoring"
fi

echo "Backup router configuration completed"
echo "Backup router ready for failover scenarios"