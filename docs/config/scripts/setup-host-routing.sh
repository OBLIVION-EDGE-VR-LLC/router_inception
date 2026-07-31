#!/bin/bash
# Host Routing Setup for Geographic Pin-Ball Machine Effect
# Routes traffic through containers to simulate "around the world" routing
# Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}[OBLIVION EDGE HOST ROUTING]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Get the host's primary interface and IP
get_host_info() {
    HOST_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    HOST_IP=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+')
    GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -n1)

    log_info "Detected host interface: $HOST_INTERFACE"
    log_info "Detected host IP: $HOST_IP"
    log_info "Detected gateway IP: $GATEWAY_IP"
}

# Setup host routing for pin-ball effect
setup_host_routing() {
    log_header "Setting up Host Routing for Geographic Pin-Ball Machine"

    # Create routing tables for each geographic hop
    log_info "Creating custom routing tables..."

    # Add routing table entries (if not already present)
    grep -q "100 oblivion-primary" /etc/iproute2/rt_tables || echo "100 oblivion-primary" >> /etc/iproute2/rt_tables
    grep -q "101 oblivion-russia" /etc/iproute2/rt_tables || echo "101 oblivion-russia" >> /etc/iproute2/rt_tables
    grep -q "102 oblivion-canada" /etc/iproute2/rt_tables || echo "102 oblivion-canada" >> /etc/iproute2/rt_tables
    grep -q "103 oblivion-taiwan" /etc/iproute2/rt_tables || echo "103 oblivion-taiwan" >> /etc/iproute2/rt_tables
    grep -q "104 oblivion-australia" /etc/iproute2/rt_tables || echo "104 oblivion-australia" >> /etc/iproute2/rt_tables
    grep -q "105 oblivion-exit" /etc/iproute2/rt_tables || echo "105 oblivion-exit" >> /etc/iproute2/rt_tables

    # Container IPs in the geo-labyrinth network
    PRIMARY_IP="172.20.0.10"
    RUSSIA_IP="172.20.0.20"
    CANADA_IP="172.20.0.30"
    TAIWAN_IP="172.20.0.40"
    AUSTRALIA_IP="172.20.0.50"
    EXIT_IP="172.20.0.60"

    # Set up routes through the geographic chain
    log_info "Setting up routing through geographic containers..."

    # Route to primary router (entry point)
    ip route add $PRIMARY_IP/32 via $PRIMARY_IP dev docker0 table oblivion-primary 2>/dev/null || true

    # Chain routing: each hop routes to the next
    ip route add default via $PRIMARY_IP table oblivion-primary 2>/dev/null || true
    ip route add default via $RUSSIA_IP table oblivion-russia 2>/dev/null || true
    ip route add default via $CANADA_IP table oblivion-canada 2>/dev/null || true
    ip route add default via $TAIWAN_IP table oblivion-taiwan 2>/dev/null || true
    ip route add default via $AUSTRALIA_IP table oblivion-australia 2>/dev/null || true
    ip route add default via $EXIT_IP table oblivion-exit 2>/dev/null || true

    # Create policy routing rules for pin-ball effect
    log_info "Setting up policy routing rules..."

    # Mark packets for geographic routing
    iptables -t mangle -A OUTPUT -d 0.0.0.0/0 ! -d 172.20.0.0/16 ! -d 172.21.0.0/16 ! -d 127.0.0.0/8 ! -d 10.0.0.0/8 ! -d 192.168.0.0/16 -j MARK --set-mark 100 2>/dev/null || true

    # Route marked packets through the geographic chain
    ip rule add fwmark 100 table oblivion-primary 2>/dev/null || true

    log_success "Host routing for pin-ball effect configured"
}

# Create virtual interfaces for geographic simulation
setup_virtual_interfaces() {
    log_info "Setting up virtual interfaces for geographic simulation..."

    # Create virtual interfaces for each geographic location
    for location in russia canada taiwan australia; do
        IFACE="veth-$location"

        # Remove existing interface if present
        ip link delete $IFACE 2>/dev/null || true

        # Create veth pair
        ip link add $IFACE type veth peer name ${IFACE}-peer 2>/dev/null || true
        ip link set $IFACE up
        ip link set ${IFACE}-peer up

        log_info "Created virtual interface: $IFACE"
    done

    log_success "Virtual interfaces created"
}

# Setup IP forwarding and masquerading
setup_forwarding() {
    log_info "Setting up IP forwarding and masquerading..."

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Make it persistent
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

    # Set up masquerading for container networks
    iptables -t nat -A POSTROUTING -s 172.20.0.0/16 -o $HOST_INTERFACE -j MASQUERADE 2>/dev/null || true
    iptables -t nat -A POSTROUTING -s 172.21.0.0/16 -o $HOST_INTERFACE -j MASQUERADE 2>/dev/null || true

    # Allow forwarding between container networks
    iptables -A FORWARD -s 172.20.0.0/16 -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -d 172.20.0.0/16 -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -s 172.21.0.0/16 -j ACCEPT 2>/dev/null || true
    iptables -A FORWARD -d 172.21.0.0/16 -j ACCEPT 2>/dev/null || true

    log_success "IP forwarding and masquerading configured"
}

# Create traceroute test script
create_traceroute_test() {
    log_info "Creating traceroute test script..."

    cat > /tmp/test-geographic-routing.sh << 'EOF'
#!/bin/bash
# Test Geographic Routing Pin-Ball Effect
echo "=== OblivionEdge Geographic Routing Test ==="
echo "Testing routing through geographic containers..."
echo

# Test external connectivity through the chain
echo "1. Testing external connectivity:"
echo "   Pinging 8.8.8.8 through geographic chain..."
ping -c 3 8.8.8.8

echo
echo "2. Testing traceroute through containers:"
echo "   Traceroute to 8.8.8.8 (should show container hops)..."
traceroute -n 8.8.8.8

echo
echo "3. Testing geographic container accessibility:"
CONTAINERS=("172.20.0.10:primary" "172.20.0.20:russia" "172.20.0.30:canada" "172.20.0.40:taiwan" "172.20.0.50:australia" "172.20.0.60:exit")

for container in "${CONTAINERS[@]}"; do
    IP="${container%%:*}"
    NAME="${container##*:}"

    echo "   Testing $NAME ($IP)..."
    if ping -c 1 -W 2 $IP >/dev/null 2>&1; then
        echo "   ✓ $NAME is reachable"
    else
        echo "   ✗ $NAME is not reachable"
    fi
done

echo
echo "=== Test completed ==="
EOF

    chmod +x /tmp/test-geographic-routing.sh
    log_success "Traceroute test script created: /tmp/test-geographic-routing.sh"
}

# Remove existing routing configuration
cleanup_routing() {
    log_header "Cleaning up existing routing configuration..."

    # Remove policy routing rules
    ip rule delete fwmark 100 2>/dev/null || true

    # Remove iptables rules
    iptables -t mangle -D OUTPUT -d 0.0.0.0/0 ! -d 172.20.0.0/16 ! -d 172.21.0.0/16 ! -d 127.0.0.0/8 ! -d 10.0.0.0/8 ! -d 192.168.0.0/16 -j MARK --set-mark 100 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s 172.20.0.0/16 -o $HOST_INTERFACE -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s 172.21.0.0/16 -o $HOST_INTERFACE -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -s 172.20.0.0/16 -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -d 172.20.0.0/16 -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -s 172.21.0.0/16 -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -d 172.21.0.0/16 -j ACCEPT 2>/dev/null || true

    # Remove virtual interfaces
    for location in russia canada taiwan australia; do
        ip link delete veth-$location 2>/dev/null || true
    done

    log_success "Routing cleanup completed"
}

# Show current routing configuration
show_routing_status() {
    log_header "Current Geographic Routing Status"

    echo
    echo "=== Custom Routing Tables ==="
    grep oblivion /etc/iproute2/rt_tables || echo "No custom routing tables found"

    echo
    echo "=== Policy Routing Rules ==="
    ip rule list | grep -E "(oblivion|100)" || echo "No custom routing rules found"

    echo
    echo "=== Container Network Routes ==="
    ip route show table all | grep -E "(172\.20\.|172\.21\.)" || echo "No container routes found"

    echo
    echo "=== Geographic Virtual Interfaces ==="
    ip link show | grep -E "veth-(russia|canada|taiwan|australia)" || echo "No virtual interfaces found"

    echo
    echo "=== Geographic Containers Status ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep oblivion || echo "No OblivionEdge containers running"
}

# Main function
main() {
    case "${1:-}" in
        "setup")
            check_root
            get_host_info
            setup_host_routing
            setup_virtual_interfaces
            setup_forwarding
            create_traceroute_test
            log_success "Geographic pin-ball routing setup completed!"
            echo
            log_info "Run '/tmp/test-geographic-routing.sh' to test the routing"
            ;;
        "cleanup")
            check_root
            get_host_info
            cleanup_routing
            ;;
        "status")
            show_routing_status
            ;;
        "test")
            /tmp/test-geographic-routing.sh
            ;;
        *)
            echo "OblivionEdge Host Routing Manager"
            echo
            echo "Usage: $0 <command>"
            echo
            echo "Commands:"
            echo "  setup    - Set up geographic pin-ball routing"
            echo "  cleanup  - Remove geographic routing configuration"
            echo "  status   - Show current routing status"
            echo "  test     - Test geographic routing (run after setup)"
            echo
            echo "Example:"
            echo "  sudo $0 setup     # Set up the pin-ball routing"
            echo "  $0 test          # Test the routing configuration"
            ;;
    esac
}

# Execute main function
main "$@"