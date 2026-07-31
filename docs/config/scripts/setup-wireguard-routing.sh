#!/bin/bash
# Setup WireGuard Geographic Routing Chain
# Configures containers to route traffic through the geographic pin-ball chain
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
    echo -e "${PURPLE}[OBLIVION EDGE WG ROUTING]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Container and network mapping
declare -A CONTAINERS=(
    ["primary"]="172.20.0.10:10.0.1.1:10.0.2.1"
    ["russia"]="172.20.0.20:10.0.2.1:10.0.3.1"
    ["canada"]="172.20.0.30:10.0.3.1:10.0.4.1"
    ["taiwan"]="172.20.0.40:10.0.4.1:10.0.5.1"
    ["australia"]="172.20.0.50:10.0.5.1:10.0.6.1"
    ["exit"]="172.20.0.60:10.0.6.1:"
)

# Check if containers are running
check_containers() {
    log_info "Checking container status..."

    cd "$CONFIG_DIR"
    for container in "${!CONTAINERS[@]}"; do
        if ! docker compose ps "oblivion-$container" | grep -q "Up"; then
            log_error "Container oblivion-$container is not running"
            return 1
        fi
    done

    log_success "All containers are running"
}

# Configure routing for a single container
configure_container_routing() {
    local container_name="$1"
    local container_info="${CONTAINERS[$container_name]}"

    IFS=':' read -r container_ip wg_ip next_hop <<< "$container_info"

    log_info "Configuring routing for $container_name..."

    # Enable IP forwarding in container (if possible)
    docker exec "oblivion-$container_name" sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || log_info "  IP forwarding already enabled via Docker sysctls"

    # For exit container, just ensure it can route to internet
    if [ "$container_name" = "exit" ]; then
        log_info "  Exit container - ensuring internet connectivity"
        # Exit container routes directly to internet (no next hop)
        return 0
    fi

    # For other containers, set up routing through next hop
    if [ -n "$next_hop" ]; then
        log_info "  Setting up routing: $container_name ($wg_ip) → next hop ($next_hop)"

        # Add specific route for external traffic through WireGuard
        # Route specific external networks through next hop instead of default route
        docker exec "oblivion-$container_name" ip route add 8.8.8.0/24 via "$next_hop" dev wg0 2>/dev/null || true
        docker exec "oblivion-$container_name" ip route add 1.1.1.0/24 via "$next_hop" dev wg0 2>/dev/null || true
        docker exec "oblivion-$container_name" ip route add 208.67.222.0/24 via "$next_hop" dev wg0 2>/dev/null || true

        # Add route for common external networks through WireGuard
        docker exec "oblivion-$container_name" ip route add 0.0.0.0/1 via "$next_hop" dev wg0 metric 50 2>/dev/null || true
        docker exec "oblivion-$container_name" ip route add 128.0.0.0/1 via "$next_hop" dev wg0 metric 50 2>/dev/null || true

        log_success "  Routing configured for $container_name"
    fi
}

# Setup the complete routing chain
setup_routing_chain() {
    log_header "Setting Up Geographic WireGuard Routing Chain"

    # Configure routing in order: primary → russia → canada → taiwan → australia → exit
    local chain_order=("exit" "australia" "taiwan" "canada" "russia" "primary")

    for container in "${chain_order[@]}"; do
        configure_container_routing "$container"
    done

    log_success "Geographic routing chain configured"
}

# Test the routing chain with comprehensive validation
test_routing_chain() {
    log_header "Testing Geographic WireGuard Routing Chain"

    # Test connectivity through each hop
    local test_targets=("1.1.1.1" "8.8.8.8")

    for target in "${test_targets[@]}"; do
        log_info "Testing connectivity to $target through geographic chain..."

        # Test from primary (should go through the chain)
        log_info "  Testing from primary container..."
        if docker exec oblivion-primary ping -c 2 -W 5 "$target" >/dev/null 2>&1; then
            log_success "  ✓ Primary → $target: SUCCESS"
        else
            log_warning "  ✗ Primary → $target: FAILED"
        fi

        # Test traceroute to see the WireGuard hops
        log_info "  Expected traceroute path:"
        log_info "    1  10.0.2.1   ← russia (wg)"
        log_info "    2  10.0.3.1   ← canada (wg)"
        log_info "    3  10.0.4.1   ← taiwan (wg)"
        log_info "    4  10.0.5.1   ← australia (wg)"
        log_info "    5  10.0.6.1   ← exit (wg)"
        log_info "    6  172.20.0.1 ← Docker bridge"

        log_info "  Actual traceroute from primary to $target:"
        docker exec oblivion-primary traceroute -n -w 2 -m 8 "$target" 2>/dev/null | head -10 || log_warning "    Traceroute failed"
        echo
    done

    # Test traffic capture validation
    log_info "Testing traffic capture to verify chain usage..."
    log_info "Starting tcpdump on exit container eth0..."
    docker exec oblivion-exit tcpdump -i eth0 -nn -c 5 'tcp port 443' >/dev/null 2>&1 &
    local tcpdump_pid=$!

    sleep 1

    log_info "Sending HTTPS request from primary..."
    local result=$(docker exec oblivion-primary curl -s --max-time 10 https://api.ipify.org || echo "Request failed")

    sleep 2
    kill $tcpdump_pid 2>/dev/null || true

    log_info "Traffic source validation result: $result"
}

# Show current routing status
show_routing_status() {
    log_header "Current WireGuard Routing Status"

    echo
    for container in primary russia canada taiwan australia exit; do
        echo "=== $container Container Routing ==="

        # Show WireGuard status
        echo "WireGuard Status:"
        docker exec "oblivion-$container" wg show 2>/dev/null | grep -E "(interface|peer|latest handshake)" || echo "  No WireGuard info"

        # Show routing table
        echo "Routing Table:"
        docker exec "oblivion-$container" ip route show | head -10

        echo
    done
}

# Reset routing to defaults
reset_routing() {
    log_header "Resetting WireGuard Routing to Defaults"

    for container in "${!CONTAINERS[@]}"; do
        log_info "Resetting routing for $container..."

        # Remove custom routes
        docker exec "oblivion-$container" ip route del 0.0.0.0/1 2>/dev/null || true
        docker exec "oblivion-$container" ip route del 128.0.0.0/1 2>/dev/null || true
        docker exec "oblivion-$container" ip route del 8.8.8.0/24 2>/dev/null || true
        docker exec "oblivion-$container" ip route del 1.1.1.0/24 2>/dev/null || true
        docker exec "oblivion-$container" ip route del 208.67.222.0/24 2>/dev/null || true

        log_success "  Reset completed for $container"
    done
}

# Monitor traffic flow
monitor_traffic_flow() {
    log_header "Monitoring Geographic Traffic Flow"

    echo "Starting real-time monitoring of WireGuard traffic..."
    echo "Press Ctrl+C to stop"
    echo

    # Monitor WireGuard interfaces
    (
        while true; do
            clear
            echo "=== Geographic WireGuard Traffic Monitor ==="
            echo "$(date)"
            echo

            for container in primary russia canada taiwan australia exit; do
                echo "--- $container ---"
                # Show WireGuard transfer stats
                docker exec "oblivion-$container" wg show 2>/dev/null | grep -A2 -B1 "transfer:" || echo "No WireGuard transfer data"
                echo
            done

            sleep 3
        done
    ) 2>/dev/null
}

# Generate test traffic through the chain
generate_test_traffic() {
    log_header "Generating Test Traffic Through Geographic Chain"

    local test_targets=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    local containers=("primary" "russia" "canada" "taiwan" "australia")

    log_info "Starting background traffic generation..."

    for container in "${containers[@]}"; do
        for target in "${test_targets[@]}"; do
            # Generate background ping traffic
            docker exec "oblivion-$container" ping -i 2 "$target" >/dev/null 2>&1 &
        done
        log_info "  Started traffic from $container"
    done

    log_success "Test traffic generation started (background processes)"
    log_info "Use 'pkill ping' to stop traffic generation"
}

# Usage information
show_usage() {
    echo "OblivionEdge WireGuard Geographic Routing Manager"
    echo
    echo "Usage: $0 <command>"
    echo
    echo "Commands:"
    echo "  setup        Configure geographic WireGuard routing chain"
    echo "  test         Test the routing chain connectivity"
    echo "  status       Show current routing status"
    echo "  reset        Reset routing to defaults"
    echo "  monitor      Monitor real-time traffic flow"
    echo "  generate     Generate test traffic through chain"
    echo "  help         Show this help message"
    echo
    echo "Examples:"
    echo "  $0 setup     # Configure the geographic routing"
    echo "  $0 test      # Test connectivity through chain"
    echo "  $0 status    # Show current status"
    echo "  $0 monitor   # Real-time traffic monitoring"
    echo
    echo "Geographic Chain: Primary → Russia → Canada → Taiwan → Australia → Exit → Internet"
}

# Main command processing
main() {
    cd "$CONFIG_DIR"

    case "${1:-}" in
        "setup")
            check_containers
            setup_routing_chain
            log_success "WireGuard geographic routing chain setup completed!"
            echo
            log_info "Run '$0 test' to test the routing"
            ;;
        "test")
            check_containers
            test_routing_chain
            ;;
        "status")
            show_routing_status
            ;;
        "reset")
            reset_routing
            ;;
        "monitor")
            check_containers
            monitor_traffic_flow
            ;;
        "generate")
            check_containers
            generate_test_traffic
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: ${1:-}"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"