#!/bin/bash
# Exit Router Configuration Script (SOHO Gateway)
set -e

echo "Configuring Exit Router (SOHO Gateway)..."

# Create necessary directories
mkdir -p /var/log/oblivion
mkdir -p /etc/wireguard

# Copy WireGuard configuration
cp /etc/oblivion/wg0.conf /etc/wireguard/wg0.conf

# Set up WireGuard interface
echo "Setting up WireGuard interface..."
wg-quick up wg0 || echo "WireGuard interface may already be up"

# Configure NAT if enabled
if [ "${NAT_ENABLED}" = "true" ]; then
    echo "Configuring NAT for SOHO network access..."

    # Enable NAT for outbound traffic
    iptables -t nat -A POSTROUTING -s 10.0.0.0/8 -o eth0 -j MASQUERADE 2>/dev/null || echo "NAT rule may already exist"

    # Configure SOHO network access
    if [ -n "${SOHO_NETWORK}" ]; then
        echo "Configuring access to SOHO network: ${SOHO_NETWORK}"
        ip route add ${SOHO_NETWORK} via 172.20.0.1 dev eth0 2>/dev/null || echo "SOHO route may already exist"

        # Allow traffic to SOHO network
        iptables -A FORWARD -d ${SOHO_NETWORK} -j ACCEPT 2>/dev/null || echo "SOHO forward rule may already exist"
        iptables -A FORWARD -s ${SOHO_NETWORK} -j ACCEPT 2>/dev/null || echo "SOHO return rule may already exist"
    fi
fi

# Apply firewall rules
if [ "${FIREWALL_ENABLED}" = "true" ]; then
    echo "Applying exit router firewall rules..."
    if [ -f /etc/oblivion/firewall.rules ]; then
        if command -v iptables-restore >/dev/null 2>&1; then
            iptables-restore < /etc/oblivion/firewall.rules || echo "Warning: Could not apply firewall rules"
        else
            echo "Warning: iptables-restore not found, using iptables directly"
        fi
    fi

    # Default DROP policy for security
    iptables -P FORWARD DROP 2>/dev/null || echo "Forward policy may already be set"
    iptables -P INPUT DROP 2>/dev/null || echo "Input policy may already be set"

    # Allow established connections
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || echo "Established rule may exist"
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || echo "Input established rule may exist"

    # Allow WireGuard
    iptables -A INPUT -p udp --dport ${WIREGUARD_PORT:-51825} -j ACCEPT 2>/dev/null || echo "WireGuard input rule may exist"

    # Allow management access
    iptables -A INPUT -s 172.21.0.0/16 -j ACCEPT 2>/dev/null || echo "Management access may exist"
fi

# Configure DNS forwarding
echo "Setting up DNS forwarding..."
if command -v dnsmasq >/dev/null 2>&1; then
    # Configure DNS for the VPN
    echo "server=8.8.8.8" > /etc/dnsmasq.d/oblivion.conf
    echo "server=1.1.1.1" >> /etc/dnsmasq.d/oblivion.conf
    echo "interface=wg0" >> /etc/dnsmasq.d/oblivion.conf
    echo "bind-interfaces" >> /etc/dnsmasq.d/oblivion.conf

    # Start DNS service
    dnsmasq --conf-file=/etc/dnsmasq.d/oblivion.conf --pid-file=/var/run/dnsmasq-oblivion.pid || echo "DNS service may already be running"
fi

# Configure monitoring and logging
echo "Starting exit router monitoring..."
if command -v oblivion_suspect_monitoring >/dev/null 2>&1; then
    oblivion_suspect_monitoring \
        --daemonize \
        --role exit \
        --soho-network "${SOHO_NETWORK:-192.168.1.0/24}" \
        --log-file /var/log/oblivion/monitoring.log || echo "Warning: Could not start monitoring"
fi

echo "Exit router configuration completed"
echo "SOHO gateway ready - providing access to ${SOHO_NETWORK:-192.168.1.0/24}"