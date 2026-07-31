#!/bin/bash
# Host Routing Setup for OblivionEdge Geographic Router Network
# Run this script after: docker compose up -d
# Copyright © OBLIVION EDGE LLC, 2026

set -e

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

# Detect the active internet interface
detect_internet_interface() {
    # Get the default route interface
    local iface=$(ip route show default | awk '/default/ {print $5}' | head -1)

    if [ -z "$iface" ]; then
        log_error "Could not detect internet interface"
        echo "Please run: ip route show default"
        echo "And manually set INTERNET_IFACE in this script"
        exit 1
    fi

    echo "$iface"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run with sudo"
        echo "Usage: sudo $0"
        exit 1
    fi
}

# Enable IP forwarding
enable_ip_forwarding() {
    log_info "Enabling IP forwarding..."

    # Enable temporarily
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Make permanent (uncomment if you want it persistent across reboots)
    # if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    #     echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    # fi

    log_success "IP forwarding enabled"
}

# Clean up existing rules (optional)
cleanup_existing_rules() {
    log_info "Cleaning up existing OblivionEdge iptables rules..."

    # Detect Docker bridges for cleanup
    GEO_BRIDGE_IFACE=$(ip route | grep "172.20.0.0/16" | awk '{print $3}' | head -1)
    MGMT_BRIDGE_IFACE=$(ip route | grep "172.21.0.0/16" | awk '{print $3}' | head -1)

    # Remove any existing rules (ignore errors if they don't exist)
    iptables -t nat -D POSTROUTING -s 172.20.0.0/16 -o "$INTERNET_IFACE" -j MASQUERADE 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s 172.21.0.0/16 -o "$INTERNET_IFACE" -j MASQUERADE 2>/dev/null || true

    iptables -D FORWARD -s 172.20.0.0/16 -o "$INTERNET_IFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -s 172.21.0.0/16 -o "$INTERNET_IFACE" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$INTERNET_IFACE" -d 172.20.0.0/16 -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$INTERNET_IFACE" -d 172.21.0.0/16 -j ACCEPT 2>/dev/null || true

    # Remove Docker bridge forwarding rules
    if [ -n "$GEO_BRIDGE_IFACE" ]; then
        iptables -D FORWARD -i "$GEO_BRIDGE_IFACE" -o "$INTERNET_IFACE" -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -i "$INTERNET_IFACE" -o "$GEO_BRIDGE_IFACE" -j ACCEPT 2>/dev/null || true
    fi

    if [ -n "$MGMT_BRIDGE_IFACE" ]; then
        iptables -D FORWARD -i "$MGMT_BRIDGE_IFACE" -o "$INTERNET_IFACE" -j ACCEPT 2>/dev/null || true
        iptables -D FORWARD -i "$INTERNET_IFACE" -o "$MGMT_BRIDGE_IFACE" -j ACCEPT 2>/dev/null || true
    fi

    log_success "Cleanup completed"
}

# Detect Docker bridge interfaces
detect_docker_bridges() {
    GEO_BRIDGE=$(docker network inspect config_geo-labyrinth --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null | head -1)
    MGMT_BRIDGE=$(docker network inspect config_mgmt-network --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null | head -1)

    # Get the actual bridge interface names
    GEO_BRIDGE_IFACE=$(ip route | grep "172.20.0.0/16" | awk '{print $3}' | head -1)
    MGMT_BRIDGE_IFACE=$(ip route | grep "172.21.0.0/16" | awk '{print $3}' | head -1)

    log_info "Detected Docker bridges:"
    log_info "  geo-labyrinth: $GEO_BRIDGE_IFACE ($GEO_BRIDGE)"
    log_info "  mgmt-network: $MGMT_BRIDGE_IFACE ($MGMT_BRIDGE)"
}

# Setup NAT and forwarding rules
setup_nat_rules() {
    log_info "Setting up NAT rules for Docker networks..."
    log_info "Internet interface: $INTERNET_IFACE"

    # Detect Docker bridge interfaces
    detect_docker_bridges

    # NAT rules for Docker networks
    log_info "Adding MASQUERADE rules..."
    iptables -t nat -A POSTROUTING -s 172.20.0.0/16 -o "$INTERNET_IFACE" -j MASQUERADE
    iptables -t nat -A POSTROUTING -s 172.21.0.0/16 -o "$INTERNET_IFACE" -j MASQUERADE

    # Forward rules for IP ranges
    log_info "Adding FORWARD rules for IP ranges..."
    iptables -A FORWARD -s 172.20.0.0/16 -o "$INTERNET_IFACE" -j ACCEPT
    iptables -A FORWARD -s 172.21.0.0/16 -o "$INTERNET_IFACE" -j ACCEPT
    iptables -A FORWARD -i "$INTERNET_IFACE" -d 172.20.0.0/16 -j ACCEPT
    iptables -A FORWARD -i "$INTERNET_IFACE" -d 172.21.0.0/16 -j ACCEPT

    # Forward rules for Docker bridge interfaces (this is the key part we were missing!)
    if [ -n "$GEO_BRIDGE_IFACE" ]; then
        log_info "Adding FORWARD rules for Docker bridges..."
        iptables -A FORWARD -i "$GEO_BRIDGE_IFACE" -o "$INTERNET_IFACE" -j ACCEPT
        iptables -A FORWARD -i "$INTERNET_IFACE" -o "$GEO_BRIDGE_IFACE" -j ACCEPT
    fi

    if [ -n "$MGMT_BRIDGE_IFACE" ]; then
        iptables -A FORWARD -i "$MGMT_BRIDGE_IFACE" -o "$INTERNET_IFACE" -j ACCEPT
        iptables -A FORWARD -i "$INTERNET_IFACE" -o "$MGMT_BRIDGE_IFACE" -j ACCEPT
    fi

    log_success "NAT and forwarding rules configured"
}

# Test connectivity from containers
test_connectivity() {
    log_info "Testing internet connectivity from containers..."

    # Wait a moment for rules to take effect
    sleep 2

    # Test from exit router first
    log_info "Testing from exit router..."
    if docker compose exec oblivion-exit ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log_success "Exit router has internet connectivity!"
    else
        log_warning "Exit router still cannot reach internet"
    fi

    # Test from primary router
    log_info "Testing from primary router..."
    if docker compose exec oblivion-primary ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
        log_success "Primary router has internet connectivity!"
    else
        log_warning "Primary router still cannot reach internet"
    fi

    # Test DNS resolution
    log_info "Testing DNS resolution..."
    if docker compose exec oblivion-exit nslookup google.com >/dev/null 2>&1; then
        log_success "DNS resolution working!"
    else
        log_warning "DNS resolution still failing"
    fi
}

# Show current iptables rules
show_rules() {
    echo
    log_info "Current iptables NAT rules:"
    iptables -t nat -L POSTROUTING -n | grep -E "(172\.20\.|172\.21\.)" || echo "  No matching rules found"

    echo
    log_info "Current iptables FORWARD rules:"
    iptables -L FORWARD -n | grep -E "(172\.20\.|172\.21\.)" || echo "  No matching rules found"
}

# Main setup function
main_setup() {
    echo "OblivionEdge Host Routing Setup"
    echo "==============================="
    echo

    # Detect internet interface
    INTERNET_IFACE=$(detect_internet_interface)
    log_info "Detected internet interface: $INTERNET_IFACE"

    # Setup routing
    enable_ip_forwarding
    cleanup_existing_rules
    setup_nat_rules

    echo
    log_success "Host routing setup completed!"
    echo

    # Test connectivity
    test_connectivity

    # Show current rules
    show_rules

    echo
    log_info "Setup complete! You can now test with:"
    echo "  docker compose exec oblivion-primary traceroute 8.8.8.8"
    echo "  ./test-connectivity.sh"
}

# Cleanup function
cleanup_rules() {
    echo "OblivionEdge Host Routing Cleanup"
    echo "================================="
    echo

    INTERNET_IFACE=$(detect_internet_interface)
    log_info "Internet interface: $INTERNET_IFACE"

    cleanup_existing_rules

    log_success "Cleanup completed!"
}

# Usage information
show_usage() {
    echo "OblivionEdge Host Routing Setup"
    echo
    echo "Usage:"
    echo "  sudo $0                # Setup routing (default)"
    echo "  sudo $0 setup          # Setup routing"
    echo "  sudo $0 cleanup        # Remove routing rules"
    echo "  sudo $0 test           # Test connectivity only"
    echo "  sudo $0 show           # Show current rules"
    echo
    echo "Run this after: docker compose up -d"
}

# Check for Docker Compose file
check_docker_compose() {
    if [ ! -f "docker-compose.yml" ] && [ ! -f "docker-compose.yaml" ]; then
        log_warning "No docker-compose.yml found in current directory"
        log_info "Make sure you're in the directory with your docker-compose file"
    fi
}

# Main script logic
case "${1:-setup}" in
    "setup")
        check_root
        check_docker_compose
        main_setup
        ;;
    "cleanup")
        check_root
        cleanup_rules
        ;;
    "test")
        check_docker_compose
        test_connectivity
        ;;
    "show")
        check_root
        INTERNET_IFACE=$(detect_internet_interface)
        show_rules
        ;;
    "help"|"--help"|"-h")
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        echo
        show_usage
        exit 1
        ;;
esac