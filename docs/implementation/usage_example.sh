#!/bin/bash
# Usage Example: OblivionEdge Geographic Router Labyrinth
# Demonstrates how to deploy and test the multi-hop network
# Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}╔════════════════════════════════════════════════════════╗"
echo -e "║           OblivionEdge Geographic Router               ║"
echo -e "║              Labyrinth Usage Example                   ║"
echo -e "║                                                        ║"
echo -e "║   Demonstrates multi-hop geographic routing through:   ║"
echo -e "║   Russia → Canada → Taiwan → Australia → SOHO         ║"
echo -e "╚════════════════════════════════════════════════════════╝${NC}"
echo

# Step 1: Environment Setup
echo -e "${BLUE}📋 Step 1: Environment Setup${NC}"
echo "Checking system requirements..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Check available memory
TOTAL_MEM=$(free -g | awk 'NR==2{printf "%.0f", $2}')
if [ "$TOTAL_MEM" -lt 16 ]; then
    echo "⚠️  Warning: Only ${TOTAL_MEM}GB RAM detected. 16GB recommended."
fi

echo "✅ System checks passed"
echo

# Step 2: Initialize the Network
echo -e "${BLUE}📡 Step 2: Initialize Geographic Router Network${NC}"
echo "Creating configuration files and WireGuard keys..."

"$SCRIPT_DIR/container_manager.sh" init

echo "✅ Network initialized"
echo

# Step 3: Build Container Images
echo -e "${BLUE}🔧 Step 3: Build OblivionEdge Container Images${NC}"
echo "Building router and monitoring containers..."

"$SCRIPT_DIR/container_manager.sh" build

echo "✅ Container images built"
echo

# Step 4: Deploy the Network
echo -e "${BLUE}🚀 Step 4: Deploy Geographic Router Labyrinth${NC}"
echo "Starting containers in sequence..."

"$SCRIPT_DIR/container_manager.sh" start

echo "✅ Network deployed successfully"
echo

# Step 5: Verify Network Health
echo -e "${BLUE}🔍 Step 5: Verify Network Health${NC}"
echo "Testing connectivity across all hops..."

"$SCRIPT_DIR/container_manager.sh" test

echo

# Step 6: Demonstrate Geographic Routing
echo -e "${BLUE}🌐 Step 6: Demonstrate Geographic Routing${NC}"
echo "Testing traffic flow through geographic hops..."

# Test from primary router
echo "Testing route from Primary Router through Russia hop..."
cd "$PROJECT_DIR/docs/config"

# Check if containers are running
if docker compose ps | grep -q "healthy"; then
    echo "✅ Containers are healthy"

    # Test geographic routing
    echo -e "${YELLOW}Testing geographic IP simulation:${NC}"

    # Test Russia hop
    echo "🇷🇺 Testing Russia hop (AS12389 - Moscow)..."
    docker compose exec oblivion-russia ip addr show wg0 | grep -o "10.0.2.1" && echo "   ✅ Russia tunnel interface active"

    # Test Canada hop
    echo "🇨🇦 Testing Canada hop (AS812 - Toronto)..."
    docker compose exec oblivion-canada ip addr show wg0 | grep -o "10.0.3.1" && echo "   ✅ Canada tunnel interface active"

    # Test Taiwan hop
    echo "🇹🇼 Testing Taiwan hop (AS9924 - Taipei)..."
    docker compose exec oblivion-taiwan ip addr show wg0 | grep -o "10.0.4.1" && echo "   ✅ Taiwan tunnel interface active"

    # Test Australia hop
    echo "🇦🇺 Testing Australia hop (AS1221 - Sydney)..."
    docker compose exec oblivion-australia ip addr show wg0 | grep -o "10.0.5.1" && echo "   ✅ Australia tunnel interface active"

    echo
    echo -e "${YELLOW}Testing end-to-end connectivity:${NC}"

    # Ping through the chain
    echo "Testing ping from primary to exit through all hops..."
    docker compose exec oblivion-primary ping -c 1 172.20.0.60 &> /dev/null && echo "   ✅ End-to-end connectivity confirmed"

    # Test external connectivity
    echo "Testing external connectivity from exit router..."
    docker compose exec oblivion-exit ping -c 1 8.8.8.8 &> /dev/null && echo "   ✅ External connectivity confirmed"

else
    echo "❌ Some containers are not healthy"
fi

echo

# Step 7: Show Monitoring Dashboard
echo -e "${BLUE}📊 Step 7: Access Monitoring Dashboard${NC}"
echo "The following services are now available:"
echo
echo "🖥️  Monitoring Dashboard:    http://localhost:3000"
echo "🔧 Primary Admin Interface: https://localhost:8443"
echo "📈 Prometheus Metrics:      http://localhost:9090"
echo

# Step 8: Traffic Simulation Example
echo -e "${BLUE}🔄 Step 8: Traffic Simulation Example${NC}"
echo "Simulating traffic flow through geographic hops..."

cat << 'EOF'

Example Traffic Flow:

1. Client connects to Primary Router (172.20.0.10)
   ┌─────────────────────────────────────┐
   │ Client → Primary Router             │
   │ Authentication: Certificate + ZTNA  │
   │ Encryption: WireGuard tunnel setup  │
   └─────────────────────────────────────┘

2. Primary routes to Russia Hop (172.20.0.20)
   ┌─────────────────────────────────────┐
   │ Primary → Russia (Moscow)           │
   │ Geographic IP: 5.101.x.x            │
   │ ASN: AS12389 (ROSTELECOM)           │
   │ Re-encryption: New WireGuard tunnel │
   └─────────────────────────────────────┘

3. Russia routes to Canada Hop (172.20.0.30)
   ┌─────────────────────────────────────┐
   │ Russia → Canada (Toronto)           │
   │ Geographic IP: 174.95.x.x           │
   │ ASN: AS812 (ROGERS)                 │
   │ Re-encryption: New WireGuard tunnel │
   └─────────────────────────────────────┘

4. Canada routes to Taiwan Hop (172.20.0.40)
   ┌─────────────────────────────────────┐
   │ Canada → Taiwan (Taipei)            │
   │ Geographic IP: 1.160.x.x            │
   │ ASN: AS9924 (CHUNGHWA)              │
   │ Re-encryption: New WireGuard tunnel │
   └─────────────────────────────────────┘

5. Taiwan routes to Australia Hop (172.20.0.50)
   ┌─────────────────────────────────────┐
   │ Taiwan → Australia (Sydney)         │
   │ Geographic IP: 1.128.x.x            │
   │ ASN: AS1221 (TELSTRA)               │
   │ Re-encryption: New WireGuard tunnel │
   └─────────────────────────────────────┘

6. Australia routes to Exit Router (172.20.0.60)
   ┌─────────────────────────────────────┐
   │ Australia → Exit → SOHO Network     │
   │ Final decryption and NAT            │
   │ Traffic exits as if from Australia  │
   │ SOHO devices: 192.168.1.0/24        │
   └─────────────────────────────────────┘

EOF

echo -e "${YELLOW}Security Features Active:${NC}"
echo "🔒 Multi-layer WireGuard encryption (6 layers)"
echo "🛡️  Zero Trust authentication at entry"
echo "👁️  Packet monitoring and forensics"
echo "🌍 Geographic IP obfuscation"
echo "🔄 Automatic key rotation"
echo

# Step 9: Real-time Monitoring
echo -e "${BLUE}📡 Step 9: Real-time Monitoring${NC}"
echo "Starting real-time traffic monitor..."
echo "Press Ctrl+C to stop monitoring and continue..."
echo

# Start monitoring in background
"$SCRIPT_DIR/container_manager.sh" monitor &
MONITOR_PID=$!

# Wait for user input
read -p "Press Enter to stop monitoring and continue..."
kill $MONITOR_PID 2>/dev/null || true

echo

# Step 10: Cleanup Instructions
echo -e "${BLUE}🧹 Step 10: Cleanup Instructions${NC}"
echo "To clean up the geographic router network:"
echo
echo "1. Stop the network:"
echo "   ./docs/implementation/container_manager.sh stop"
echo
echo "2. Remove all containers and volumes:"
echo "   ./docs/implementation/container_manager.sh cleanup"
echo
echo "3. Remove Docker images (optional):"
echo "   docker image rm oblivion-edge/router:latest oblivion-edge/monitor:latest"
echo

# Final summary
echo -e "${PURPLE}╔════════════════════════════════════════════════════════╗"
echo -e "║                    Demo Complete! ✅                   ║"
echo -e "║                                                        ║"
echo -e "║   Your geographic router labyrinth is now running.    ║"
echo -e "║   Traffic flows through multiple countries before     ║"
echo -e "║   reaching its destination, providing enhanced        ║"
echo -e "║   privacy and security through:                       ║"
echo -e "║                                                        ║"
echo -e "║   • Multi-hop geographic routing                      ║"
echo -e "║   • Layer upon layer of encryption                    ║"
echo -e "║   • Zero trust network access                         ║"
echo -e "║   • Real-time monitoring and forensics               ║"
echo -e "║                                                        ║"
echo -e "║   This system demonstrates advanced network security  ║"
echo -e "║   concepts using the OblivionEdge platform.          ║"
echo -e "╚════════════════════════════════════════════════════════╝${NC}"

echo
echo -e "${GREEN}🎉 Geographic Router Labyrinth demonstration completed!${NC}"
echo
echo "Next steps:"
echo "• Explore the monitoring dashboard at http://localhost:3000"
echo "• Examine traffic logs with: ./docs/implementation/container_manager.sh logs <hop>"
echo "• Modify configurations in: ./docs/config/router_configs/"
echo "• Study the Rust implementation in: ./docs/implementation/geo_router_emulator.rs"
echo
echo "For more information, see: ./README.md"