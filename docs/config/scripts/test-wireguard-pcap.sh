#!/bin/bash
# WireGuard Traffic Capture and Analysis Script
# Uses tcpdump to capture packets for observation of the geographic pin-ball routing
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
    echo -e "${PURPLE}[OBLIVION EDGE PCAP TEST]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PCAP_DIR="/tmp/oblivion-pcaps"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Container information
CONTAINERS=("oblivion-primary" "oblivion-russia" "oblivion-canada" "oblivion-taiwan" "oblivion-australia" "oblivion-exit")
CONTAINER_IPS=("172.20.0.10" "172.20.0.20" "172.20.0.30" "172.20.0.40" "172.20.0.50" "172.20.0.60")
WG_PORTS=("51820" "51821" "51822" "51823" "51824" "51825")

# Create pcap directory
create_pcap_dir() {
    log_info "Creating packet capture directory..."
    mkdir -p "$PCAP_DIR"
    chmod 755 "$PCAP_DIR"
    log_success "PCAP directory created: $PCAP_DIR"
}

# Check if containers are running
check_containers() {
    log_info "Checking container status..."

    cd "$CONFIG_DIR"
    local running_containers=$(docker compose ps --services --filter "status=running")

    if [ -z "$running_containers" ]; then
        log_error "No containers are running. Please start the OblivionEdge network first."
        echo "Use: docker compose up -d"
        exit 1
    fi

    log_success "Found running containers"
    echo "$running_containers"
}

# Start packet capture on host interfaces
start_host_capture() {
    log_header "Starting Host Interface Packet Captures"

    local capture_duration="${1:-60}"
    local interface_filter="${2:-any}"

    log_info "Capturing packets for $capture_duration seconds on interface $interface_filter"

    # Capture on docker bridge interface
    log_info "Starting capture on docker0 interface..."
    tcpdump -i docker0 -w "$PCAP_DIR/host-docker0-$TIMESTAMP.pcap" -G $capture_duration -W 1 \
        '(udp and portrange 51820-51825) or (host 172.20.0.0/16) or (host 172.21.0.0/16)' &
    local docker_pid=$!

    # Capture on main network interface
    local main_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -n "$main_interface" ]; then
        log_info "Starting capture on main interface: $main_interface..."
        tcpdump -i "$main_interface" -w "$PCAP_DIR/host-$main_interface-$TIMESTAMP.pcap" -G $capture_duration -W 1 \
            'udp and portrange 51820-51825' &
        local main_pid=$!
    fi

    log_success "Host captures started (duration: ${capture_duration}s)"
    echo "  Docker bridge PID: $docker_pid"
    [ -n "$main_interface" ] && echo "  Main interface PID: $main_pid"
}

# Start packet capture in containers
start_container_captures() {
    log_header "Starting Container Packet Captures"

    local capture_duration="${1:-60}"

    cd "$CONFIG_DIR"

    for i in "${!CONTAINERS[@]}"; do
        local container="${CONTAINERS[$i]}"
        local container_ip="${CONTAINER_IPS[$i]}"
        local wg_port="${WG_PORTS[$i]}"

        log_info "Starting capture in $container..."

        # Start tcpdump in container for WireGuard interface
        docker compose exec -d "$container" tcpdump -i wg0 -w /tmp/wg0-capture-$TIMESTAMP.pcap -G $capture_duration -W 1 2>/dev/null &

        # Start tcpdump in container for ethernet interface
        docker compose exec -d "$container" tcpdump -i eth0 -w /tmp/eth0-capture-$TIMESTAMP.pcap -G $capture_duration -W 1 \
            "udp port $wg_port or host $container_ip" 2>/dev/null &

        log_success "Capture started in $container"
    done
}

# Generate test traffic
generate_test_traffic() {
    log_header "Generating Test Traffic Through Geographic Chain"

    cd "$CONFIG_DIR"

    # Test targets
    local targets=("8.8.8.8" "1.1.1.1" "208.67.222.222")

    log_info "Generating ping traffic from each container..."

    for container in "${CONTAINERS[@]}"; do
        for target in "${targets[@]}"; do
            log_info "Pinging $target from $container..."
            docker compose exec -T "$container" ping -c 5 -i 0.5 "$target" >/dev/null 2>&1 &
        done
    done

    log_info "Generating curl traffic..."
    for container in "${CONTAINERS[@]}"; do
        docker compose exec -T "$container" curl -s --max-time 10 http://httpbin.org/ip >/dev/null 2>&1 &
        docker compose exec -T "$container" curl -s --max-time 10 https://api.ipify.org >/dev/null 2>&1 &
    done

    log_success "Test traffic generation started"
}

# Collect captured packets from containers
collect_container_pcaps() {
    log_header "Collecting Packet Captures from Containers"

    cd "$CONFIG_DIR"

    for container in "${CONTAINERS[@]}"; do
        log_info "Collecting captures from $container..."

        # Copy WireGuard interface capture
        if docker compose exec "$container" test -f "/tmp/wg0-capture-$TIMESTAMP.pcap" 2>/dev/null; then
            docker compose cp "$container:/tmp/wg0-capture-$TIMESTAMP.pcap" "$PCAP_DIR/$container-wg0-$TIMESTAMP.pcap" 2>/dev/null || true
            log_success "Collected wg0 capture from $container"
        else
            log_warning "No wg0 capture found in $container"
        fi

        # Copy ethernet interface capture
        if docker compose exec "$container" test -f "/tmp/eth0-capture-$TIMESTAMP.pcap" 2>/dev/null; then
            docker compose cp "$container:/tmp/eth0-capture-$TIMESTAMP.pcap" "$PCAP_DIR/$container-eth0-$TIMESTAMP.pcap" 2>/dev/null || true
            log_success "Collected eth0 capture from $container"
        else
            log_warning "No eth0 capture found in $container"
        fi

        # Clean up temporary files in container
        docker compose exec "$container" rm -f "/tmp/*capture-$TIMESTAMP.pcap" 2>/dev/null || true
    done
}

# Analyze captured packets
analyze_pcaps() {
    log_header "Analyzing Captured Packets"

    local analysis_file="$PCAP_DIR/analysis-$TIMESTAMP.txt"

    echo "=== OblivionEdge Geographic Routing PCAP Analysis ===" > "$analysis_file"
    echo "Timestamp: $(date)" >> "$analysis_file"
    echo "Capture Session: $TIMESTAMP" >> "$analysis_file"
    echo "" >> "$analysis_file"

    log_info "Analyzing packet captures..."

    # Count packets per file
    echo "=== Packet Counts ===" >> "$analysis_file"
    for pcap_file in "$PCAP_DIR"/*.pcap; do
        if [ -f "$pcap_file" ]; then
            local filename=$(basename "$pcap_file")
            local packet_count=$(tcpdump -r "$pcap_file" 2>/dev/null | wc -l)
            echo "$filename: $packet_count packets" >> "$analysis_file"
            log_info "$filename: $packet_count packets captured"
        fi
    done

    echo "" >> "$analysis_file"

    # Analyze WireGuard traffic
    echo "=== WireGuard Traffic Analysis ===" >> "$analysis_file"
    for pcap_file in "$PCAP_DIR"/*-wg0-*.pcap; do
        if [ -f "$pcap_file" ]; then
            local filename=$(basename "$pcap_file")
            echo "--- $filename ---" >> "$analysis_file"

            # UDP port analysis
            tcpdump -r "$pcap_file" -n 'udp' 2>/dev/null | head -20 >> "$analysis_file" 2>/dev/null || true
            echo "" >> "$analysis_file"
        fi
    done

    # Analyze inter-container traffic
    echo "=== Inter-Container Traffic Analysis ===" >> "$analysis_file"
    for pcap_file in "$PCAP_DIR"/host-*.pcap; do
        if [ -f "$pcap_file" ]; then
            local filename=$(basename "$pcap_file")
            echo "--- $filename ---" >> "$analysis_file"

            # Container network traffic
            tcpdump -r "$pcap_file" -n 'net 172.20.0.0/16 or net 172.21.0.0/16' 2>/dev/null | head -20 >> "$analysis_file" 2>/dev/null || true
            echo "" >> "$analysis_file"
        fi
    done

    log_success "Analysis complete: $analysis_file"
}

# Generate summary report
generate_summary() {
    log_header "Generating Summary Report"

    local summary_file="$PCAP_DIR/summary-$TIMESTAMP.txt"

    echo "=== OblivionEdge Geographic Routing Test Summary ===" > "$summary_file"
    echo "Test Session: $TIMESTAMP" >> "$summary_file"
    echo "Date: $(date)" >> "$summary_file"
    echo "" >> "$summary_file"

    # List captured files
    echo "=== Captured Files ===" >> "$summary_file"
    ls -la "$PCAP_DIR"/*.pcap 2>/dev/null | while read line; do
        echo "$line" >> "$summary_file"
    done

    echo "" >> "$summary_file"

    # Network topology
    echo "=== Geographic Routing Topology ===" >> "$summary_file"
    echo "Primary (172.20.0.10:51820) → Russia (172.20.0.20:51821) → " >> "$summary_file"
    echo "Canada (172.20.0.30:51822) → Taiwan (172.20.0.40:51823) → " >> "$summary_file"
    echo "Australia (172.20.0.50:51824) → Exit (172.20.0.60:51825) → Internet" >> "$summary_file"
    echo "" >> "$summary_file"

    # Instructions for analysis
    echo "=== Analysis Instructions ===" >> "$summary_file"
    echo "1. Use Wireshark to open PCAP files:" >> "$summary_file"
    echo "   wireshark $PCAP_DIR/*.pcap" >> "$summary_file"
    echo "" >> "$summary_file"
    echo "2. Filter for WireGuard traffic:" >> "$summary_file"
    echo "   udp.port >= 51820 and udp.port <= 51825" >> "$summary_file"
    echo "" >> "$summary_file"
    echo "3. Filter for container networks:" >> "$summary_file"
    echo "   ip.addr == 172.20.0.0/16 or ip.addr == 172.21.0.0/16" >> "$summary_file"
    echo "" >> "$summary_file"
    echo "4. Look for tunneled traffic:" >> "$summary_file"
    echo "   Follow the packet flow through each geographic hop" >> "$summary_file"

    log_success "Summary report generated: $summary_file"
}

# Clean up old captures
cleanup_old_captures() {
    log_info "Cleaning up captures older than 24 hours..."
    find "$PCAP_DIR" -name "*.pcap" -mtime +1 -delete 2>/dev/null || true
    find "$PCAP_DIR" -name "*.txt" -mtime +1 -delete 2>/dev/null || true
    log_success "Cleanup completed"
}

# Run a comprehensive capture test
run_comprehensive_test() {
    local duration="${1:-60}"

    log_header "Running Comprehensive WireGuard PCAP Test"
    log_info "Test duration: $duration seconds"

    # Setup
    create_pcap_dir
    check_containers
    cleanup_old_captures

    # Start captures
    start_host_capture "$duration"
    sleep 2
    start_container_captures "$duration"
    sleep 2

    # Generate traffic
    generate_test_traffic

    log_info "Waiting for captures to complete ($duration seconds)..."
    sleep "$duration"

    # Additional wait for tcpdump to finish writing
    sleep 5

    # Collect and analyze
    collect_container_pcaps
    analyze_pcaps
    generate_summary

    log_success "Comprehensive test completed!"
    echo
    echo "Capture files location: $PCAP_DIR"
    echo "Analysis file: $PCAP_DIR/analysis-$TIMESTAMP.txt"
    echo "Summary file: $PCAP_DIR/summary-$TIMESTAMP.txt"
    echo
    echo "To view captures in Wireshark:"
    echo "  wireshark $PCAP_DIR/*-$TIMESTAMP.pcap"
}

# Show current captures
list_captures() {
    log_header "Current Packet Captures"

    if [ -d "$PCAP_DIR" ] && [ "$(ls -A $PCAP_DIR 2>/dev/null)" ]; then
        echo "Capture directory: $PCAP_DIR"
        echo
        ls -lah "$PCAP_DIR"
        echo
        echo "Total disk usage:"
        du -sh "$PCAP_DIR"
    else
        echo "No captures found in $PCAP_DIR"
    fi
}

# Real-time traffic monitoring
monitor_realtime() {
    log_header "Real-time Geographic Traffic Monitor"

    check_containers

    echo "Monitoring WireGuard traffic across geographic hops..."
    echo "Press Ctrl+C to stop monitoring"
    echo

    # Monitor docker bridge interface
    log_info "Starting real-time monitoring of geographic routing..."
    tcpdump -i docker0 -n '(udp and portrange 51820-51825) or (net 172.20.0.0/16)' 2>/dev/null
}

# Usage information
show_usage() {
    echo "OblivionEdge WireGuard Traffic Capture and Analysis"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  test [duration]      Run comprehensive capture test (default: 60s)"
    echo "  monitor             Real-time traffic monitoring"
    echo "  host-capture [dur]  Capture only on host interfaces"
    echo "  container-capture   Capture only in containers"
    echo "  analyze             Analyze existing captures"
    echo "  list                List current captures"
    echo "  cleanup             Clean up old captures"
    echo
    echo "Examples:"
    echo "  $0 test 120         # Run 2-minute comprehensive test"
    echo "  $0 monitor          # Real-time monitoring"
    echo "  $0 host-capture 30  # 30-second host capture"
    echo "  $0 analyze          # Analyze existing captures"
    echo
    echo "Output:"
    echo "  PCAP files:   $PCAP_DIR/"
    echo "  View with:    wireshark $PCAP_DIR/*.pcap"
}

# Main command processing
main() {
    case "${1:-}" in
        "test")
            run_comprehensive_test "${2:-60}"
            ;;
        "monitor")
            monitor_realtime
            ;;
        "host-capture")
            create_pcap_dir
            start_host_capture "${2:-60}"
            log_success "Host capture started for ${2:-60} seconds"
            ;;
        "container-capture")
            create_pcap_dir
            check_containers
            start_container_captures "${2:-60}"
            sleep "${2:-60}"
            collect_container_pcaps
            ;;
        "analyze")
            analyze_pcaps
            generate_summary
            ;;
        "list")
            list_captures
            ;;
        "cleanup")
            cleanup_old_captures
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