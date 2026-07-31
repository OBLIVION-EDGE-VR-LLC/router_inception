#!/bin/bash
# Geographic Hop Router Configuration Script
set -e

echo "Configuring Geographic Hop Router (${GEOGRAPHIC_LOCATION})..."

# Create necessary directories
mkdir -p /var/log/oblivion
mkdir -p /etc/wireguard

# Copy WireGuard configuration
cp /etc/oblivion/wg0.conf /etc/wireguard/wg0.conf

# Set up WireGuard interface
echo "Setting up WireGuard interface for ${GEOGRAPHIC_LOCATION}..."
wg-quick up wg0 || echo "WireGuard interface may already be up"

# Configure geographic IP simulation
echo "Configuring geographic IP simulation for ${SIMULATED_COUNTRY}..."
if [ -n "${SIMULATED_IP_RANGE}" ]; then
    # Add geographic IP range to loopback for simulation
    ip addr add ${SIMULATED_IP_RANGE%/*}/32 dev lo label lo:geo 2>/dev/null || echo "Geographic IP may already be configured"
fi

# Apply firewall rules
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
if [ -f /etc/oblivion/geographic.conf ]; then
    while IFS= read -r setting || [ -n "$setting" ]; do
        # Skip empty lines, comments, and INI section headers
        if [ -n "$setting" ] && [ "${setting#\#}" = "$setting" ] && [ "${setting#\[}" = "$setting" ]; then
            # Only process key=value pairs
            if [[ "$setting" == *"="* ]]; then
                echo "Applied setting: $setting"
                # Export the setting as environment variable for potential use
                export "$setting"
            fi
        fi
    done < /etc/oblivion/geographic.conf
else
    echo "No geographic configuration found, using defaults"
fi

# PATCHED-BY: Comprehensive WireGuard fixes - Default route now handled in wg0.conf PostUp
# Set up route forwarding for next hop
# echo "Configuring route forwarding to next hop: ${NEXT_HOP}"
# if [ -n "${NEXT_HOP}" ]; then
#     # Route unknown traffic to next hop
#     ip route add default via ${NEXT_HOP} dev wg0 metric 100 2>/dev/null || echo "Default route may already exist"
# fi

# Configure monitoring for this geographic location
echo "Starting geographic monitoring..."
if command -v oblivion_suspect_monitoring >/dev/null 2>&1; then
    oblivion_suspect_monitoring \
        --daemonize \
        --geographic-location "${GEOGRAPHIC_LOCATION}" \
        --country "${SIMULATED_COUNTRY:-Unknown}" \
        --asn "${SIMULATED_ASN:-Unknown}" \
        --log-file /var/log/oblivion/monitoring.log || echo "Warning: Could not start monitoring"
fi

echo "Geographic hop router configuration completed"
echo "Router (${GEOGRAPHIC_LOCATION}) ready - simulating traffic from ${SIMULATED_COUNTRY} (${SIMULATED_ASN})"