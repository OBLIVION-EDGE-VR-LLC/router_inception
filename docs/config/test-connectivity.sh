#!/bin/bash
# Test script for WireGuard connectivity through the router chain
# Copyright © OBLIVION EDGE LLC, 2026

set -e

DOCKER_COMPOSE_FILE="./docker-compose.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if containers are running
check_containers() {
    log_info "Checking container status..."
    docker compose -f "$DOCKER_COMPOSE_FILE" ps
    echo
}

# Test WireGuard interfaces
test_wireguard_interfaces() {
    log_info "Testing WireGuard interfaces on each router..."

    local routers=("primary" "russia" "canada" "taiwan" "australia" "exit")

    for router in "${routers[@]}"; do
        echo "=== $router ==="

        if docker compose -f "$DOCKER_COMPOSE_FILE" exec "oblivion-$router" ip addr show wg0 2>/dev/null; then
            log_success "WireGuard interface wg0 is up on $router"
        else
            log_warning "WireGuard interface wg0 not found on $router"
        fi

        if docker compose -f "$DOCKER_COMPOSE_FILE" exec "oblivion-$router" wg show 2>/dev/null; then
            log_success "WireGuard status available on $router"
        else
            log_warning "WireGuard not running on $router"
        fi
        echo
    done
}

# Test ping between hops
test_ping_chain() {
    log_info "Testing ping connectivity through the chain..."

    # Test ping from primary to each subsequent hop
    local hops=("russia:172.20.0.20" "canada:172.20.0.30" "taiwan:172.20.0.40" "australia:172.20.0.50" "exit:172.20.0.60")

    for hop in "${hops[@]}"; do
        local hop_name="${hop%%:*}"
        local hop_ip="${hop##*:}"

        log_info "Pinging $hop_name ($hop_ip) from primary..."

        if docker compose -f "$DOCKER_COMPOSE_FILE" exec oblivion-primary ping -c 2 -W 2 "$hop_ip" 2>/dev/null; then
            log_success "Can reach $hop_name from primary"
        else
            log_warning "Cannot reach $hop_name from primary"
        fi
        echo
    done
}

# Test WireGuard tunnel connectivity
test_wireguard_tunnels() {
    log_info "Testing WireGuard tunnel connectivity..."

    # Test ping through WireGuard tunnels
    local wg_tests=(
        "primary:10.0.2.1:russia WG tunnel"
        "russia:10.0.3.1:canada WG tunnel"
        "canada:10.0.4.1:taiwan WG tunnel"
        "taiwan:10.0.5.1:australia WG tunnel"
        "australia:10.0.6.1:exit WG tunnel"
    )

    for test in "${wg_tests[@]}"; do
        IFS=':' read -r src_router target_ip description <<< "$test"

        log_info "Testing $description from $src_router to $target_ip..."

        if docker compose -f "$DOCKER_COMPOSE_FILE" exec "oblivion-$src_router" ping -c 2 -W 2 "$target_ip" 2>/dev/null; then
            log_success "$description working"
        else
            log_warning "$description not working"
        fi
        echo
    done
}

# Test internet connectivity from each router
test_internet_access() {
    log_info "Testing internet connectivity from each router..."

    local routers=("primary" "russia" "canada" "taiwan" "australia" "exit")

    for router in "${routers[@]}"; do
        log_info "Testing internet from $router..."

        # Try ping to 8.8.8.8
        if docker compose -f "$DOCKER_COMPOSE_FILE" exec "oblivion-$router" ping -c 2 -W 3 8.8.8.8 2>/dev/null; then
            log_success "$router has internet connectivity"
        else
            log_warning "$router cannot reach internet"
        fi

        # Try DNS resolution
        if docker compose -f "$DOCKER_COMPOSE_FILE" exec "oblivion-$router" nslookup google.com 2>/dev/null >/dev/null; then
            log_success "$router DNS resolution working"
        else
            log_warning "$router DNS resolution failed"
        fi
        echo
    done
}

# Test full chain traceroute
test_traceroute_chain() {
    log_info "Testing full chain traceroute from primary to internet..."

    echo "Traceroute to 8.8.8.8 from primary router:"
    docker compose -f "$DOCKER_COMPOSE_FILE" exec oblivion-primary traceroute -n -w 3 -m 10 8.8.8.8 2>/dev/null || {
        log_warning "Traceroute failed, trying ping instead..."
        docker compose -f "$DOCKER_COMPOSE_FILE" exec oblivion-primary ping -c 3 8.8.8.8
    }
    echo
}

# Monitor WireGuard peer connections
monitor_wireguard_peers() {
    log_info "Monitoring WireGuard peer connections..."

    local routers=("primary" "russia" "canada" "taiwan" "australia" "exit")

    for router in "${routers[@]}"; do
        echo "=== WireGuard peers on $router ==="
        docker compose -f "$DOCKER_COMPOSE_FILE" exec "oblivion-$router" wg show all 2>/dev/null || {
            log_warning "WireGuard not running on $router"
        }
        echo
    done
}

# Capture traffic on exit router
capture_exit_traffic() {
    local duration="${1:-10}"
    log_info "Capturing traffic on exit router for $duration seconds..."

    echo "Starting tcpdump on exit router wg0 interface..."
    docker compose -f "$DOCKER_COMPOSE_FILE" exec oblivion-exit timeout "$duration" tcpdump -i wg0 -n -c 20 2>/dev/null || {
        log_warning "Traffic capture failed or no traffic detected"
    }
    echo
}

# Main test function
run_all_tests() {
    log_info "Starting comprehensive connectivity tests..."
    echo

    check_containers
    test_wireguard_interfaces
    test_ping_chain
    test_wireguard_tunnels
    test_internet_access
    test_traceroute_chain
    monitor_wireguard_peers

    log_success "All tests completed!"
}

# Main execution
case "${1:-all}" in
    "containers")
        check_containers
        ;;
    "wireguard")
        test_wireguard_interfaces
        ;;
    "ping")
        test_ping_chain
        ;;
    "tunnels")
        test_wireguard_tunnels
        ;;
    "internet")
        test_internet_access
        ;;
    "traceroute")
        test_traceroute_chain
        ;;
    "peers")
        monitor_wireguard_peers
        ;;
    "capture")
        capture_exit_traffic "${2:-10}"
        ;;
    "all"|*)
        run_all_tests
        ;;
esac