#!/bin/bash
# OblivionEdge WireGuard Chain Fix Script
# Addresses the three root causes preventing proper geographic routing
# Based on analysis of AllowedIPs, default routing, and rp_filter issues

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

log_header() {
    echo -e "${PURPLE}[OBLIVION EDGE CHAIN FIX]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/docs/config/router_configs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Backup original configurations
backup_configs() {
    log_header "Backing up original configurations"

    for location in primary russia canada taiwan australia exit; do
        if [ -f "$CONFIG_DIR/$location/wg0.conf" ]; then
            cp "$CONFIG_DIR/$location/wg0.conf" "$CONFIG_DIR/$location/wg0.conf.bak.$TIMESTAMP"
            log_info "Backed up $location/wg0.conf"
        fi
    done

    if [ -f "$SCRIPT_DIR/docs/config/scripts/configure-hop.sh" ]; then
        cp "$SCRIPT_DIR/docs/config/scripts/configure-hop.sh" "$SCRIPT_DIR/docs/config/scripts/configure-hop.sh.bak.$TIMESTAMP"
        log_info "Backed up configure-hop.sh"
    fi
}

# Extract existing keys from current configs
extract_keys() {
    log_info "Extracting existing WireGuard keys..."

    declare -A private_keys
    declare -A public_keys

    for location in primary russia canada taiwan australia exit; do
        if [ -f "$CONFIG_DIR/$location/wg0.conf" ]; then
            private_key=$(grep "PrivateKey" "$CONFIG_DIR/$location/wg0.conf" | cut -d= -f2 | tr -d ' ')
            private_keys[$location]=$private_key

            # Generate public key from private key if needed
            public_key=$(echo "$private_key" | wg pubkey)
            public_keys[$location]=$public_key

            log_info "Extracted keys for $location"
        fi
    done

    # Export for use in other functions
    export primary_private="${private_keys[primary]}"
    export russia_private="${private_keys[russia]}"
    export canada_private="${private_keys[canada]}"
    export taiwan_private="${private_keys[taiwan]}"
    export australia_private="${private_keys[australia]}"
    export exit_private="${private_keys[exit]}"

    export primary_public="${public_keys[primary]}"
    export russia_public="${public_keys[russia]}"
    export canada_public="${public_keys[canada]}"
    export taiwan_public="${public_keys[taiwan]}"
    export australia_public="${public_keys[australia]}"
    export exit_public="${public_keys[exit]}"
}

# Generate corrected WireGuard configurations
generate_primary_config() {
    log_info "Generating corrected primary configuration..."

    cat > "$CONFIG_DIR/primary/wg0.conf" << EOF
[Interface]
PrivateKey = $primary_private
Address = 10.0.1.1/24
ListenPort = 51820
Table = off
PostUp = wg set %i fwmark 51820
PostUp = ip rule add not fwmark 51820 table 51820
PostUp = ip rule add table main suppress_prefixlength 0
PostUp = ip route add default dev %i table 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip rule del not fwmark 51820 table 51820
PostDown = ip rule del table main suppress_prefixlength 0
PostDown = ip route del default dev %i table 51820
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $russia_public
AllowedIPs = 0.0.0.0/0
Endpoint = 172.20.0.20:51821
PersistentKeepalive = 25
EOF

    log_success "Generated primary configuration with 0.0.0.0/0 AllowedIPs"
}

generate_russia_config() {
    log_info "Generating corrected russia configuration..."

    cat > "$CONFIG_DIR/russia/wg0.conf" << EOF
[Interface]
PrivateKey = $russia_private
Address = 10.0.2.1/24
ListenPort = 51821
Table = off
PostUp = wg set %i fwmark 51820
PostUp = ip rule add not fwmark 51820 table 51820
PostUp = ip rule add table main suppress_prefixlength 0
PostUp = ip route add default dev %i table 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip rule del not fwmark 51820 table 51820
PostDown = ip rule del table main suppress_prefixlength 0
PostDown = ip route del default dev %i table 51820
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $primary_public
AllowedIPs = 10.0.1.0/24
Endpoint = 172.20.0.10:51820
PersistentKeepalive = 25

[Peer]
PublicKey = $canada_public
AllowedIPs = 0.0.0.0/0
Endpoint = 172.20.0.30:51822
PersistentKeepalive = 25
EOF

    log_success "Generated russia configuration with asymmetric AllowedIPs"
}

generate_canada_config() {
    log_info "Generating corrected canada configuration..."

    cat > "$CONFIG_DIR/canada/wg0.conf" << EOF
[Interface]
PrivateKey = $canada_private
Address = 10.0.3.1/24
ListenPort = 51822
Table = off
PostUp = wg set %i fwmark 51820
PostUp = ip rule add not fwmark 51820 table 51820
PostUp = ip rule add table main suppress_prefixlength 0
PostUp = ip route add default dev %i table 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip rule del not fwmark 51820 table 51820
PostDown = ip rule del table main suppress_prefixlength 0
PostDown = ip route del default dev %i table 51820
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $russia_public
AllowedIPs = 10.0.1.0/24, 10.0.2.0/24
Endpoint = 172.20.0.20:51821
PersistentKeepalive = 25

[Peer]
PublicKey = $taiwan_public
AllowedIPs = 0.0.0.0/0
Endpoint = 172.20.0.40:51823
PersistentKeepalive = 25
EOF

    log_success "Generated canada configuration"
}

generate_taiwan_config() {
    log_info "Generating corrected taiwan configuration..."

    cat > "$CONFIG_DIR/taiwan/wg0.conf" << EOF
[Interface]
PrivateKey = $taiwan_private
Address = 10.0.4.1/24
ListenPort = 51823
Table = off
PostUp = wg set %i fwmark 51820
PostUp = ip rule add not fwmark 51820 table 51820
PostUp = ip rule add table main suppress_prefixlength 0
PostUp = ip route add default dev %i table 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip rule del not fwmark 51820 table 51820
PostDown = ip rule del table main suppress_prefixlength 0
PostDown = ip route del default dev %i table 51820
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $canada_public
AllowedIPs = 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
Endpoint = 172.20.0.30:51822
PersistentKeepalive = 25

[Peer]
PublicKey = $australia_public
AllowedIPs = 0.0.0.0/0
Endpoint = 172.20.0.50:51824
PersistentKeepalive = 25
EOF

    log_success "Generated taiwan configuration"
}

generate_australia_config() {
    log_info "Generating corrected australia configuration..."

    cat > "$CONFIG_DIR/australia/wg0.conf" << EOF
[Interface]
PrivateKey = $australia_private
Address = 10.0.5.1/24
ListenPort = 51824
Table = off
PostUp = wg set %i fwmark 51820
PostUp = ip rule add not fwmark 51820 table 51820
PostUp = ip rule add table main suppress_prefixlength 0
PostUp = ip route add default dev %i table 51820
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = ip rule del not fwmark 51820 table 51820
PostDown = ip rule del table main suppress_prefixlength 0
PostDown = ip route del default dev %i table 51820
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $taiwan_public
AllowedIPs = 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24, 10.0.4.0/24
Endpoint = 172.20.0.40:51823
PersistentKeepalive = 25

[Peer]
PublicKey = $exit_public
AllowedIPs = 0.0.0.0/0
Endpoint = 172.20.0.60:51825
PersistentKeepalive = 25
EOF

    log_success "Generated australia configuration"
}

generate_exit_config() {
    log_info "Generating corrected exit configuration..."

    cat > "$CONFIG_DIR/exit/wg0.conf" << EOF
[Interface]
PrivateKey = $exit_private
Address = 10.0.6.1/24
ListenPort = 51825
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -A FORWARD -i %i -o eth0 -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -D FORWARD -i %i -o eth0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $australia_public
AllowedIPs = 0.0.0.0/0
Endpoint = 172.20.0.50:51824
PersistentKeepalive = 25
EOF

    log_success "Generated exit configuration (no default route override)"
}

# Fix Docker Compose sysctls
fix_docker_compose() {
    log_info "Updating Docker Compose with rp_filter sysctls..."

    local compose_file="$SCRIPT_DIR/docs/config/docker-compose.yml"

    # Check if rp_filter is already in sysctls
    if ! grep -q "net.ipv4.conf.default.rp_filter=2" "$compose_file"; then
        # Add rp_filter to all router containers
        sed -i '/net\.ipv4\.conf\.all\.src_valid_mark=1/a\      - net.ipv4.conf.default.rp_filter=2\      - net.ipv4.conf.all.rp_filter=2' "$compose_file"
        log_success "Added rp_filter sysctls to Docker Compose"
    else
        log_info "rp_filter sysctls already present in Docker Compose"
    fi
}

# Comment out broken default route in configure-hop.sh
fix_configure_hop() {
    log_info "Patching configure-hop.sh default route handling..."

    local script_file="$SCRIPT_DIR/docs/config/scripts/configure-hop.sh"

    if ! grep -q "PATCHED-BY:" "$script_file"; then
        # Comment out the broken default route section
        sed -i '/# Set up route forwarding for next hop/,/fi/s/^/# PATCHED-BY: fix_wireguard_chain.sh - /' "$script_file"
        log_success "Commented out broken default route handling in configure-hop.sh"
    else
        log_info "configure-hop.sh already patched"
    fi
}

# Main execution
main() {
    log_header "OblivionEdge WireGuard Chain Comprehensive Fix"
    echo
    echo "This script addresses the three root causes:"
    echo "1. AllowedIPs missing 0.0.0.0/0 for forward peers"
    echo "2. Malformed default route configuration"
    echo "3. rp_filter blocking return path traffic"
    echo

    # Execute fixes
    backup_configs
    extract_keys

    generate_primary_config
    generate_russia_config
    generate_canada_config
    generate_taiwan_config
    generate_australia_config
    generate_exit_config

    fix_docker_compose
    fix_configure_hop

    log_header "Fix Complete"
    echo
    log_success "All configurations have been updated with the comprehensive fixes"
    log_info "Backups saved with timestamp: $TIMESTAMP"
    echo
    log_warning "Next steps:"
    echo "1. Restart containers: docker compose down && docker compose up -d"
    echo "2. Test with: docker exec oblivion-primary traceroute -n -m 8 1.1.1.1"
    echo "3. Verify chain: docker exec oblivion-exit tcpdump -i eth0 -nn -c 5 'tcp port 443' &"
    echo "4. Test traffic: docker exec oblivion-primary curl -s https://api.ipify.org"
    echo
    log_info "Expected traceroute should show:"
    echo "  1  10.0.2.1   ← russia (wg)"
    echo "  2  10.0.3.1   ← canada (wg)"
    echo "  3  10.0.4.1   ← taiwan (wg)"
    echo "  4  10.0.5.1   ← australia (wg)"
    echo "  5  10.0.6.1   ← exit (wg)"
    echo "  6  172.20.0.1 ← Docker bridge"
    echo "  7+ WAN hops..."
}

# Execute main function
main "$@"