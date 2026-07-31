#!/bin/sh
set -e

echo "Starting OblivionEdge Geographic Router..."
echo "Router Role: ${ROUTER_ROLE:-unknown}"
echo "Geographic Location: ${GEOGRAPHIC_LOCATION:-unknown}"

# Load kernel modules
if [ -f /lib/modules/router_kmod.ko ]; then
    echo "Loading router kernel module..."
    modprobe router_kmod || echo "Warning: Could not load router module"
fi

if [ -f /lib/modules/fw_kmod.ko ]; then
    echo "Loading firewall kernel module..."
    modprobe fw_kmod || echo "Warning: Could not load firewall module"
fi

# Configure based on router role
case "${ROUTER_ROLE}" in
    "primary")
        echo "Configuring as primary entry router..."
        /usr/local/bin/configure-primary.sh
        ;;
    "hop")
        echo "Configuring as geographic hop router..."
        /usr/local/bin/configure-hop.sh
        ;;
    "exit")
        echo "Configuring as exit router..."
        /usr/local/bin/configure-exit.sh
        ;;
    "backup")
        echo "Configuring as backup router..."
        /usr/local/bin/configure-backup.sh
        ;;
    *)
        echo "Error: Unknown router role: ${ROUTER_ROLE}"
        exit 1
        ;;
esac

# Enable IP forwarding (sysctls should handle this, but try gracefully)
echo "Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "IP forwarding handled by sysctls"
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || echo "IPv6 forwarding handled by sysctls"

# Start services via supervisor
echo "Starting OblivionEdge services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/oblivion.conf