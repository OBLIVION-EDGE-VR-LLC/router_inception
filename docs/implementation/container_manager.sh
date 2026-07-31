#!/bin/bash
# Container Manager for Geographic Router Labyrinth
# Manages the complete multi-hop network infrastructure
# Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$PROJECT_DIR/docs/config"
DOCKER_COMPOSE_FILE="$CONFIG_DIR/docker-compose.yml"

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
    echo -e "${PURPLE}[OBLIVION EDGE]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check if user is in docker group
    if ! groups $USER | grep -q '\bdocker\b'; then
        log_warning "User is not in docker group. You may need to use sudo."
    fi

    # Check if required directories exist
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_error "Docker Compose file not found: $DOCKER_COMPOSE_FILE"
        exit 1
    fi

    log_success "Prerequisites check completed"
}

# Initialize the geographic router network
init_network() {
    log_header "Initializing Geographic Router Labyrinth"

    # Create necessary directories
    log_info "Creating configuration directories..."
    mkdir -p "$CONFIG_DIR/router_configs/"{primary,russia,canada,taiwan,australia,exit,monitor,backup}
    mkdir -p "$CONFIG_DIR/scripts"
    mkdir -p "$PROJECT_DIR/logs"
    mkdir -p "$PROJECT_DIR/data/monitoring"

    # Generate WireGuard keys for all hops
    log_info "Generating WireGuard keys..."
    generate_wireguard_keys

    # Create router configurations
    log_info "Creating router configurations..."
    create_router_configs

    # Set proper permissions
    log_info "Setting permissions..."
    chmod +x "$CONFIG_DIR/scripts/"*.sh 2>/dev/null || true

    log_success "Network initialization completed"
}

# Generate WireGuard keys for peer authentication
generate_wireguard_keys() {
    local key_dir="$CONFIG_DIR/router_configs/keys"
    mkdir -p "$key_dir"

    local routers=("primary" "russia" "canada" "taiwan" "australia" "exit")

    for router in "${routers[@]}"; do
        if [ ! -f "$key_dir/${router}.key" ]; then
            log_info "Generating keys for $router..."
            wg genkey > "$key_dir/${router}.key"
            wg pubkey < "$key_dir/${router}.key" > "$key_dir/${router}.pub"
        fi
    done

    log_success "WireGuard keys generated"
}

# Create individual router configurations
create_router_configs() {
    local config_base="$CONFIG_DIR/router_configs"

    # Create peer key references for each router
    create_peer_keys "$config_base"

    # Primary router configuration
    cat > "$config_base/primary/config.env" << EOF
ROUTER_ROLE=primary
GEOGRAPHIC_LOCATION=entry
WIREGUARD_PORT=51820
ZTNA_ENABLED=true
TPM_ENABLED=false
NEXT_HOP=172.20.0.20
EOF

    # Russia hop configuration
    cat > "$config_base/russia/config.env" << EOF
ROUTER_ROLE=hop
GEOGRAPHIC_LOCATION=russia
SIMULATED_ASN=AS12389
SIMULATED_IP_RANGE=5.101.0.0/16
SIMULATED_COUNTRY=RU
SIMULATED_CITY=Moscow
WIREGUARD_PORT=51821
PREV_HOP=172.20.0.10
NEXT_HOP=172.20.0.30
EOF

    # Canada hop configuration
    cat > "$config_base/canada/config.env" << EOF
ROUTER_ROLE=hop
GEOGRAPHIC_LOCATION=canada
SIMULATED_ASN=AS812
SIMULATED_IP_RANGE=174.95.0.0/16
SIMULATED_COUNTRY=CA
SIMULATED_CITY=Toronto
WIREGUARD_PORT=51822
PREV_HOP=172.20.0.20
NEXT_HOP=172.20.0.40
EOF

    # Taiwan hop configuration
    cat > "$config_base/taiwan/config.env" << EOF
ROUTER_ROLE=hop
GEOGRAPHIC_LOCATION=taiwan
SIMULATED_ASN=AS9924
SIMULATED_IP_RANGE=1.160.0.0/11
SIMULATED_COUNTRY=TW
SIMULATED_CITY=Taipei
WIREGUARD_PORT=51823
PREV_HOP=172.20.0.30
NEXT_HOP=172.20.0.50
EOF

    # Australia hop configuration
    cat > "$config_base/australia/config.env" << EOF
ROUTER_ROLE=hop
GEOGRAPHIC_LOCATION=australia
SIMULATED_ASN=AS1221
SIMULATED_IP_RANGE=1.128.0.0/11
SIMULATED_COUNTRY=AU
SIMULATED_CITY=Sydney
WIREGUARD_PORT=51824
PREV_HOP=172.20.0.40
NEXT_HOP=172.20.0.60
EOF

    # Exit router configuration
    cat > "$config_base/exit/config.env" << EOF
ROUTER_ROLE=exit
GEOGRAPHIC_LOCATION=exit
SOHO_NETWORK=192.168.1.0/24
WIREGUARD_PORT=51825
PREV_HOP=172.20.0.50
NAT_ENABLED=true
FIREWALL_ENABLED=true
EOF

    log_success "Router configurations created"
}

# Create peer key references
create_peer_keys() {
    local config_base="$1"
    local key_dir="$config_base/keys"

    local routers=("primary" "russia" "canada" "taiwan" "australia" "exit")

    for router in "${routers[@]}"; do
        local peer_dir="$config_base/$router/peer-keys"
        mkdir -p "$peer_dir"

        # Create symlinks to peer public keys
        for peer in "${routers[@]}"; do
            if [ "$router" != "$peer" ]; then
                ln -sf "../../keys/${peer}.pub" "$peer_dir/${peer}.pub" 2>/dev/null || true
            fi
        done
    done
}

# Build all container images
build_images() {
    log_header "Building OblivionEdge Container Images"

    cd "$PROJECT_DIR"

    # Build router image
    log_info "Building router container image..."
    docker build -f OblivionEdge-OblivionEdge_Dev/Dockerfile.router -t oblivion-edge/router:latest OblivionEdge-OblivionEdge_Dev/

    # Build monitoring image (if Dockerfile exists)
    if [ -f "OblivionEdge-OblivionEdge_Dev/Dockerfile.monitor" ]; then
        log_info "Building monitoring container image..."
        docker build -f OblivionEdge-OblivionEdge_Dev/Dockerfile.monitor -t oblivion-edge/monitor:latest OblivionEdge-OblivionEdge_Dev/
    fi

    log_success "Container images built successfully"
}

# Start the geographic router network
start_network() {
    log_header "Starting Geographic Router Network"

    cd "$CONFIG_DIR"

    # Start core services first
    log_info "Starting monitoring services..."
    docker compose up -d oblivion-monitor

    sleep 5

    # Start routers in sequence
    local routers=("oblivion-primary" "oblivion-russia" "oblivion-canada" "oblivion-taiwan" "oblivion-australia" "oblivion-exit")

    for router in "${routers[@]}"; do
        log_info "Starting $router..."
        docker compose up -d "$router"
        sleep 3

        # Wait for health check
        wait_for_health "$router"
    done

    log_success "Geographic Router Network started successfully"
    show_network_status
}

# Stop the network
stop_network() {
    log_header "Stopping Geographic Router Network"

    cd "$CONFIG_DIR"
    docker compose down

    log_success "Network stopped"
}

# Restart the network
restart_network() {
    log_header "Restarting Geographic Router Network"
    stop_network
    sleep 2
    start_network
}

# Wait for container health check
wait_for_health() {
    local container_name="$1"
    local max_attempts=30
    local attempt=1

    log_info "Waiting for $container_name to become healthy..."

    while [ $attempt -le $max_attempts ]; do
        if docker compose ps "$container_name" | grep -q "healthy"; then
            log_success "$container_name is healthy"
            return 0
        fi

        if docker compose ps "$container_name" | grep -q "unhealthy"; then
            log_warning "$container_name is unhealthy"
            return 1
        fi

        sleep 2
        ((attempt++))
    done

    log_warning "$container_name health check timed out"
    return 1
}

# Show network status
show_network_status() {
    log_header "Geographic Router Network Status"

    cd "$CONFIG_DIR"

    echo
    echo "Container Status:"
    docker compose ps

    echo
    echo "Network Configuration:"
    echo "Primary Router:    172.20.0.10 (Entry Point)"
    echo "Russia Hop:        172.20.0.20 (AS12389 - Moscow)"
    echo "Canada Hop:        172.20.0.30 (AS812 - Toronto)"
    echo "Taiwan Hop:        172.20.0.40 (AS9924 - Taipei)"
    echo "Australia Hop:     172.20.0.50 (AS1221 - Sydney)"
    echo "Exit Router:       172.20.0.60 (SOHO Gateway)"
    echo "Monitor Server:    172.21.0.100 (Management)"

    echo
    echo "Access Points:"
    echo "Monitoring Dashboard: http://localhost:3000"
    echo "Primary Admin:        https://localhost:8443"
    echo "Prometheus:           http://localhost:9090"

    echo
    echo "Geographic Route Path:"
    echo "Client → Primary → Russia → Canada → Taiwan → Australia → Exit → SOHO"
}

# Show logs for a specific container
show_logs() {
    local container_name="$1"

    if [ -z "$container_name" ]; then
        log_error "Please specify a container name"
        echo "Available containers: primary, russia, canada, taiwan, australia, exit, monitor"
        return 1
    fi

    cd "$CONFIG_DIR"
    docker compose logs -f "oblivion-$container_name"
}

# Test network connectivity
test_connectivity() {
    log_header "Testing Geographic Router Connectivity"

    cd "$CONFIG_DIR"

    local routers=("primary" "russia" "canada" "taiwan" "australia" "exit")

    for router in "${routers[@]}"; do
        log_info "Testing connectivity to oblivion-$router..."

        if docker compose exec "oblivion-$router" ping -c 1 8.8.8.8 &> /dev/null; then
            log_success "oblivion-$router: Internet connectivity OK"
        else
            log_warning "oblivion-$router: Internet connectivity FAILED"
        fi

        if docker compose exec "oblivion-$router" /usr/bin/oblivion_admin_cli status &> /dev/null; then
            log_success "oblivion-$router: OblivionEdge status OK"
        else
            log_warning "oblivion-$router: OblivionEdge status FAILED"
        fi
    done

    # Test WireGuard connectivity
    log_info "Testing WireGuard tunnels..."
    test_wireguard_connectivity

    log_success "Connectivity tests completed"
}

# Test WireGuard connectivity between hops
test_wireguard_connectivity() {
    local hops=("primary:10.0.1.1" "russia:10.0.2.1" "canada:10.0.3.1" "taiwan:10.0.4.1" "australia:10.0.5.1")

    for hop in "${hops[@]}"; do
        local hop_name="${hop%%:*}"
        local hop_ip="${hop##*:}"

        log_info "Testing WireGuard interface on $hop_name ($hop_ip)..."

        if docker compose exec "oblivion-$hop_name" ip addr show wg0 | grep -q "$hop_ip"; then
            log_success "$hop_name: WireGuard interface configured"
        else
            log_warning "$hop_name: WireGuard interface not found"
        fi
    done
}

# Clean up all resources
cleanup() {
    log_header "Cleaning Up Geographic Router Resources"

    cd "$CONFIG_DIR"

    # Stop and remove containers
    docker compose down -v

    # Remove images (optional)
    read -p "Remove container images? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker image rm oblivion-edge/router:latest oblivion-edge/monitor:latest 2>/dev/null || true
    fi

    # Clean up configuration files (optional)
    read -p "Remove generated configuration files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR/router_configs"
    fi

    log_success "Cleanup completed"
}

# Monitor traffic flows
monitor_traffic() {
    log_header "Geographic Router Traffic Monitor"

    cd "$CONFIG_DIR"

    echo "Real-time traffic monitoring across geographic hops..."
    echo "Press Ctrl+C to stop monitoring"
    echo

    # Monitor each hop
    (
        while true; do
            clear
            echo "=== Geographic Router Traffic Monitor ==="
            echo "$(date)"
            echo

            for router in primary russia canada taiwan australia exit; do
                echo "--- $router ---"
                docker compose exec "oblivion-$router" netstat -i 2>/dev/null | grep -E "(wg0|eth0)" || echo "No interface data"
                echo
            done

            sleep 5
        done
    )
}

# Test geographic routing with traceroute
test_traceroute() {
    log_header "Testing Geographic Routing with Traceroute"

    cd "$CONFIG_DIR"

    # Define test targets and expected route
    local test_targets=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    local router_ips=("172.20.0.10" "172.20.0.20" "172.20.0.30" "172.20.0.40" "172.20.0.50" "172.20.0.60")
    local router_names=("primary" "russia" "canada" "taiwan" "australia" "exit")

    echo "Testing traceroute from each geographic hop..."
    echo

    # Test from each router in the chain
    for i in "${!router_names[@]}"; do
        local router="${router_names[$i]}"
        local router_ip="${router_ips[$i]}"

        log_info "Testing traceroute from $router ($router_ip)..."

        # Test connectivity to external targets
        for target in "${test_targets[@]}"; do
            echo "  → Traceroute to $target from $router:"

            if docker compose exec "oblivion-$router" traceroute -n -w 2 -m 10 "$target" 2>/dev/null | head -15; then
                log_success "Traceroute to $target from $router completed"
            else
                # Fallback to ping if traceroute fails
                if docker compose exec "oblivion-$router" ping -c 3 -W 2 "$target" &>/dev/null; then
                    log_warning "Traceroute failed but ping works for $target from $router"
                else
                    log_error "No connectivity to $target from $router"
                fi
            fi
            echo
        done

        # Test connectivity to next hop in chain (if not exit router)
        if [ $i -lt $((${#router_names[@]} - 1)) ]; then
            local next_router="${router_names[$((i + 1))]}"
            local next_ip="${router_ips[$((i + 1))]}"

            echo "  → Testing connectivity to next hop ($next_router at $next_ip):"
            if docker compose exec "oblivion-$router" ping -c 2 -W 1 "$next_ip" &>/dev/null; then
                log_success "Connectivity to $next_router ($next_ip) OK"
            else
                log_warning "Cannot reach next hop $next_router ($next_ip)"
            fi
            echo
        fi
    done

    # Test end-to-end traceroute through the entire chain
    log_info "Testing end-to-end routing through geographic labyrinth..."
    echo "  → End-to-end traceroute from primary to external target:"

    if docker compose exec oblivion-primary traceroute -n -w 3 -m 15 8.8.8.8 2>/dev/null; then
        log_success "End-to-end traceroute completed successfully"
    else
        log_warning "End-to-end traceroute had issues - checking basic connectivity"
        if docker compose exec oblivion-primary ping -c 5 8.8.8.8 &>/dev/null; then
            log_success "Basic connectivity through route works (ping successful)"
        else
            log_error "No end-to-end connectivity through geographic route"
        fi
    fi

    echo
    log_success "Geographic routing traceroute tests completed"
}

# Comprehensive network topology test
test_network_topology() {
    log_header "Comprehensive Network Topology Test"

    cd "$CONFIG_DIR"

    local routers=("primary" "russia" "canada" "taiwan" "australia" "exit")
    local router_ips=("172.20.0.10" "172.20.0.20" "172.20.0.30" "172.20.0.40" "172.20.0.50" "172.20.0.60")

    echo "Testing full network topology..."
    echo

    # Test internal network connectivity
    log_info "Testing geo-labyrinth network (172.20.0.0/16)..."
    for i in "${!routers[@]}"; do
        local src_router="${routers[$i]}"
        local src_ip="${router_ips[$i]}"

        echo "  From $src_router ($src_ip):"

        # Test connectivity to all other routers
        for j in "${!routers[@]}"; do
            if [ $i -ne $j ]; then
                local dst_router="${routers[$j]}"
                local dst_ip="${router_ips[$j]}"

                if docker compose exec "oblivion-$src_router" ping -c 1 -W 1 "$dst_ip" &>/dev/null; then
                    echo "    ✓ Can reach $dst_router ($dst_ip)"
                else
                    echo "    ✗ Cannot reach $dst_router ($dst_ip)"
                fi
            fi
        done
        echo
    done

    # Test management network connectivity
    log_info "Testing management network (172.21.0.0/16)..."
    local mgmt_ips=("172.21.0.10" "172.21.0.20" "172.21.0.30" "172.21.0.40" "172.21.0.50" "172.21.0.60" "172.21.0.100")
    local mgmt_services=("primary" "russia" "canada" "taiwan" "australia" "exit" "monitor")

    echo "  Management network connectivity matrix:"
    for i in "${!mgmt_services[@]}"; do
        local service="${mgmt_services[$i]}"
        local service_ip="${mgmt_ips[$i]}"

        if [ "$service" = "monitor" ]; then
            container_name="oblivion-monitor"
        else
            container_name="oblivion-$service"
        fi

        echo "    $service ($service_ip):"
        monitor_reachable=false

        if docker compose exec "$container_name" ping -c 1 -W 1 "172.21.0.100" &>/dev/null; then
            echo "      ✓ Can reach monitor (172.21.0.100)"
            monitor_reachable=true
        else
            echo "      ✗ Cannot reach monitor (172.21.0.100)"
        fi
    done

    echo
    log_success "Network topology test completed"
}

# Enhanced connectivity test with traceroute
test_connectivity_enhanced() {
    log_header "Enhanced Geographic Router Connectivity Test"

    cd "$CONFIG_DIR"

    # Run basic connectivity test first
    test_connectivity

    echo

    # Run traceroute tests
    test_traceroute

    echo

    # Run network topology tests
    test_network_topology

    echo
    log_success "Enhanced connectivity testing completed"
}

# Show usage information
show_usage() {
    echo "OblivionEdge Geographic Router Manager"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  init              Initialize the network configuration"
    echo "  build             Build all container images"
    echo "  start             Start the geographic router network"
    echo "  stop              Stop the network"
    echo "  restart           Restart the network"
    echo "  status            Show network status"
    echo "  logs <container>  Show logs for specific container"
    echo "  test              Test network connectivity"
    echo "  test-enhanced     Enhanced connectivity test with traceroute"
    echo "  traceroute        Test geographic routing paths with traceroute"
    echo "  topology          Test network topology and internal connectivity"
    echo "  monitor           Monitor real-time traffic"
    echo "  cleanup           Clean up all resources"
    echo "  help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0 init           # Initialize network"
    echo "  $0 start          # Start all containers"
    echo "  $0 logs russia    # Show Russia hop logs"
    echo "  $0 test           # Test basic connectivity"
    echo "  $0 traceroute     # Test routing paths with traceroute"
    echo "  $0 test-enhanced  # Complete connectivity and routing test"
    echo
    echo "Geographic Route: Client → Primary → Russia → Canada → Taiwan → Australia → Exit → SOHO"
}

# Main command processing
main() {
    case "${1:-}" in
        "init")
            check_prerequisites
            init_network
            ;;
        "build")
            check_prerequisites
            build_images
            ;;
        "start")
            check_prerequisites
            start_network
            ;;
        "stop")
            stop_network
            ;;
        "restart")
            restart_network
            ;;
        "status")
            show_network_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "test")
            test_connectivity
            ;;
        "test-enhanced")
            test_connectivity_enhanced
            ;;
        "traceroute")
            test_traceroute
            ;;
        "topology")
            test_network_topology
            ;;
        "monitor")
            monitor_traffic
            ;;
        "cleanup")
            cleanup
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