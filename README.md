# OblivionEdge Geographic Router Labyrinth

[![Security](https://img.shields.io/badge/security-enhanced-green.svg)](./docs/SecureGeoRouterLabyrinth.md)
[![Network](https://img.shields.io/badge/network-multi--hop-blue.svg)](./docs/diagrams/)
[![Rust](https://img.shields.io/badge/rust-1.75+-orange.svg)](https://www.rust-lang.org/)
[![Docker](https://img.shields.io/badge/docker-24.0+-blue.svg)](https://www.docker.com/)

A sophisticated multi-router geographic hopping system using OblivionEdge components to create a secure labyrinth-like network topology. Traffic appears to originate from Russia, Canada, Taiwan, and Australia before reaching the final destination.

## 🌐 Overview

This project creates a proof-of-concept secure LAN network using multiple OblivionEdge routers deployed as containers. Each router simulates a different geographic location, creating multiple hops that obscure the true origin of network traffic while providing enhanced security through:

- **Geographic IP Hopping**: Traffic appears to come from different countries
- **Multi-Layer Encryption**: WireGuard tunnels between each hop
- **Zero Trust Architecture**: Authentication and validation at each hop
- **Packet Forensics**: Complete traffic monitoring and analysis
- **Container Orchestration**: Easy deployment and management

## 🏗️ Architecture

```
Client → Primary → Russia → Canada → Taiwan → Australia → Exit → SOHO Network
         (Entry)   (Hop 1)  (Hop 2)   (Hop 3)   (Hop 4)    (Gateway)
```

### Geographic Route Path

1. **Primary Router** (Entry Point) - Initial ZTNA authentication
2. **Russia Hop** - AS12389 (ROSTELECOM) - 5.101.0.0/16
3. **Canada Hop** - AS812 (ROGERS) - 174.95.0.0/16  
4. **Taiwan Hop** - AS9924 (CHUNGHWA) - 1.160.0.0/11
5. **Australia Hop** - AS1221 (TELSTRA) - 1.128.0.0/11
6. **Exit Router** - SOHO network gateway

## 📊 System Architecture Diagrams

Understanding the complex multi-hop geographic routing system requires visualizing its various components and interactions. The following PlantUML diagrams provide comprehensive documentation of the network topology, security flows, and container architecture that form the foundation of this advanced routing solution.

### Network Topology Overview

The network topology diagram illustrates the complete end-to-end architecture of the geographic router labyrinth. This foundational diagram shows how traffic flows from client devices through multiple geographic hops before reaching the SOHO network.

![Network Topology](./docs/diagrams/network_topology.png)

*Generated from: [network_topology.puml](./docs/diagrams/network_topology.puml)*

This topology demonstrates the physical and logical connections between all network components, including the primary entry router, geographic hop containers, exit gateway, and management infrastructure. The diagram clearly depicts the isolation between different network zones and the WireGuard tunnel connections that provide secure communication channels between each hop. Additionally, it shows the management interfaces that enable centralized monitoring and control of the entire geographic routing system.

### Geographic Routing Flow Analysis

Moving from the physical topology to traffic flow patterns, the geographic routing diagram details how packets traverse the network while acquiring different geographic identities at each hop.

![Geographic Routing](./docs/diagrams/geographic_routing.png)

*Generated from: [geographic_routing.puml](./docs/diagrams/geographic_routing.puml)*

This sequence diagram captures the step-by-step process of how client traffic is processed, encrypted, and re-routed through each geographic location. It illustrates the transformation of source IP addresses at each hop, showing how traffic appears to originate from Russia, then Canada, Taiwan, and finally Australia. The diagram also highlights the multiple layers of WireGuard encryption applied at each stage, ensuring that traffic remains secure while traversing the geographic labyrinth. Furthermore, it demonstrates the security validation and packet analysis that occurs at each hop, maintaining the zero trust principles throughout the routing process.

### Container Architecture and Orchestration

Transitioning from network flows to implementation details, the container architecture diagram reveals how the geographic routing system is deployed using Docker containers and orchestrated for reliable operation.

![Container Architecture](./docs/diagrams/container_architecture.png)

*Generated from: [container_architecture.puml](./docs/diagrams/container_architecture.puml)*

This deployment view shows the containerized implementation of each geographic hop, including resource allocation, network namespace isolation, and inter-container communication patterns. The diagram illustrates how each router hop runs as an isolated container with dedicated IP ranges, WireGuard interfaces, and geographic simulation components. It also depicts the management container that provides centralized monitoring, the bridge networks that connect containers, and the volume mounts that enable persistent configuration and logging. Moreover, the diagram shows how the host system provides the foundation for container orchestration while maintaining security boundaries between different network functions.

### Security Flow and Authentication

Finally, examining the security aspects that protect the entire system, the security flow diagram demonstrates how zero trust principles and multi-layer encryption work together to secure the geographic routing process.

![Security Flow](./docs/diagrams/security_flow.png)

*Generated from: [security_flow.puml](./docs/diagrams/security_flow.puml)*

This comprehensive security diagram shows the complete authentication and encryption workflow, from initial client connection through final packet delivery. It details the TPM-based attestation process, certificate validation, and policy enforcement that occurs at the primary router entry point. The diagram also illustrates how WireGuard tunnels are established between each hop, the key rotation mechanisms that maintain forward secrecy, and the packet monitoring systems that provide forensic capabilities. Additionally, it shows how security events are detected, logged, and responded to across the entire geographic routing infrastructure, ensuring that the system maintains its security posture even under attack conditions.

### Generating Diagram Images

To generate PNG images from the PlantUML source files, use the following commands:

```bash
# Install PlantUML (requires Java)
sudo apt-get install plantuml

# Generate all diagram images
cd docs/diagrams
plantuml *.puml

# Or generate individual diagrams
plantuml network_topology.puml
plantuml geographic_routing.puml
plantuml container_architecture.puml
plantuml security_flow.puml
```

These diagrams work together to provide a complete understanding of how the geographic router labyrinth operates, from high-level architecture concepts to detailed implementation specifics. Each diagram serves a specific purpose in documenting different aspects of the system, enabling both technical implementers and security professionals to understand and extend the platform effectively.

## 📋 Prerequisites

- **Host System**: Ubuntu 22.04+ or similar Linux distribution
- **Hardware**: 16GB RAM minimum, 50GB storage
- **Docker**: Version 24.0 or higher
- **Docker Compose**: V2 support
- **Network**: Dedicated NICs for WAN/LAN/Management recommended
- **Root Access**: Required for kernel module loading

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd router-n-routers
```

### 2. Initialize Network

```bash
./docs/implementation/container_manager.sh init
```

This command:
- Creates configuration directories
- Generates WireGuard keys for all hops
- Sets up router-specific configurations
- Prepares container networking

### 3. Build Container Images

```bash
./docs/implementation/container_manager.sh build
```

Builds the OblivionEdge router containers based on the Rust codebase.

### 4. Start Geographic Router Network

```bash
./docs/implementation/container_manager.sh start
```

Starts all containers in the correct sequence:
1. Monitoring services
2. Primary router (entry point)
3. Geographic hops (Russia → Canada → Taiwan → Australia)
4. Exit router (SOHO gateway)

### 5. Verify Network Status

```bash
./docs/implementation/container_manager.sh status
```

Shows container health, network configuration, and access points.

## 🔧 Management Commands

### Container Management

```bash
# Start the network
./docs/implementation/container_manager.sh start

# Stop the network
./docs/implementation/container_manager.sh stop

# Restart the network
./docs/implementation/container_manager.sh restart

# Show status
./docs/implementation/container_manager.sh status
```

### Monitoring and Debugging

```bash
# Show logs for specific container
./docs/implementation/container_manager.sh logs russia
./docs/implementation/container_manager.sh logs canada

# Test connectivity across hops
./docs/implementation/container_manager.sh test

# Monitor real-time traffic
./docs/implementation/container_manager.sh monitor
```

### Cleanup

```bash
# Clean up all resources
./docs/implementation/container_manager.sh cleanup
```

## 🌍 Network Configuration

### Container Network Layout

| Container | IP Address | Role | Geographic Simulation |
|-----------|------------|------|----------------------|
| oblivion-primary | 172.20.0.10 | Entry Router | - |
| oblivion-russia | 172.20.0.20 | Hop 1 | Moscow, Russia (AS12389) |
| oblivion-canada | 172.20.0.30 | Hop 2 | Toronto, Canada (AS812) |
| oblivion-taiwan | 172.20.0.40 | Hop 3 | Taipei, Taiwan (AS9924) |
| oblivion-australia | 172.20.0.50 | Hop 4 | Sydney, Australia (AS1221) |
| oblivion-exit | 172.20.0.60 | Exit Gateway | - |
| oblivion-monitor | 172.21.0.100 | Management | - |

### WireGuard Tunnel Network

| Tunnel | Network Range | Purpose |
|--------|---------------|---------|
| wg0 (Primary) | 10.0.1.0/24 | Entry tunnel |
| wg0 (Russia) | 10.0.2.0/24 | Russia hop tunnel |
| wg0 (Canada) | 10.0.3.0/24 | Canada hop tunnel |
| wg0 (Taiwan) | 10.0.4.0/24 | Taiwan hop tunnel |
| wg0 (Australia) | 10.0.5.0/24 | Australia hop tunnel |
| wg0 (Exit) | 10.0.6.0/24 | Exit tunnel |

## 🔐 Security Features

### Zero Trust Network Access (ZTNA)
- Certificate-based authentication at entry point
- TPM attestation support (configurable)
- Policy-based access control

### Multi-Layer Encryption
- WireGuard tunnels between each hop
- Independent key pairs for each connection
- Automatic key rotation every 24 hours

### Packet Monitoring
- Complete traffic capture using `oblivion_suspect_monitoring`
- Flow-based analysis and reconstruction
- Geographic correlation and anomaly detection

### Geographic IP Simulation
- Dynamic IP allocation within country-specific ranges
- ASN simulation for realistic traffic attribution
- Route table manipulation for authentic routing

## 📊 Monitoring and Analytics

### Access Points

- **Monitoring Dashboard**: http://localhost:3000
- **Primary Admin Interface**: https://localhost:8443
- **Prometheus Metrics**: http://localhost:9090
- **Container Logs**: `./docs/implementation/container_manager.sh logs <container>`

### Traffic Analysis

The system provides comprehensive monitoring:

- Real-time flow tracking across geographic hops
- Bandwidth utilization per hop
- Connection success/failure rates
- Geographic path correlation
- Security event logging

## 📁 Project Structure

```
.
├── docs/
│   ├── SecureGeoRouterLabyrinth.md     # Architecture documentation
│   ├── diagrams/                        # PlantUML network diagrams
│   │   ├── network_topology.puml
│   │   ├── geographic_routing.puml
│   │   ├── container_architecture.puml
│   │   └── security_flow.puml
│   ├── config/                          # Container configurations
│   │   ├── docker-compose.yml
│   │   └── router_configs/
│   └── implementation/                  # Core implementation files
│       ├── geo_router_emulator.rs
│       ├── container_manager.sh
│       └── monitoring_setup.sh
├── OblivionEdge-OblivionEdge_Dev/      # OblivionEdge source code
│   ├── oblivion_admin_cli/
│   ├── oblivion_router_kmods/
│   ├── oblivion_suspect_monitoring/
│   ├── oblivion_ztna_daemon/
│   └── Dockerfile.router
└── README.md                           # This file
```

## 🔬 Technical Details

### OblivionEdge Integration

The system leverages several OblivionEdge components:

- **Router Kernel Modules**: `/dev/router_kmod` for route management
- **Admin CLI**: `oblivion_admin_cli` for configuration
- **ZTNA Daemon**: Zero trust network access enforcement
- **Suspect Monitoring**: Packet capture and forensic analysis

### Geographic Simulation

Each hop container runs a custom geographic simulator that:

1. Assigns IP addresses from country-specific ranges
2. Modifies packet headers to reflect geographic origin
3. Updates routing tables for authentic traffic flow
4. Logs geographic metadata for analysis

### Performance Considerations

- **Memory Usage**: ~2GB per container, 16GB total recommended
- **CPU**: Minimal overhead, encryption adds ~10% load
- **Network**: Gigabit interface recommended for full performance
- **Latency**: Adds ~5-10ms per hop under normal conditions

## 🐛 Troubleshooting

### Common Issues

1. **Container Failed to Start**
   ```bash
   # Check logs
   ./docs/implementation/container_manager.sh logs <container>
   
   # Verify prerequisites
   docker --version
   docker compose version
   ```

2. **WireGuard Tunnel Issues**
   ```bash
   # Check kernel module
   sudo modprobe wireguard
   
   # Verify container networking
   docker network ls
   ```

3. **Permission Denied Errors**
   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   newgrp docker
   ```

4. **Health Check Failures**
   ```bash
   # Check container resources
   docker stats
   
   # Verify network connectivity
   ./docs/implementation/container_manager.sh test
   ```

### Debug Mode

Enable verbose logging by setting environment variables:

```bash
export DEBUG=true
export LOG_LEVEL=debug
./docs/implementation/container_manager.sh start
```

## 🤝 Contributing

This is a research and educational project. Contributions are welcome for:

- Enhanced geographic simulation algorithms
- Additional monitoring and analytics features
- Security improvements and hardening
- Documentation and examples
- Performance optimizations

## ⚖️ Legal and Ethics

This system is designed for:

- ✅ Security research and education
- ✅ Proof-of-concept demonstrations  
- ✅ Network testing and validation
- ✅ Privacy protection research

**NOT intended for**:
- ❌ Illegal activity circumvention
- ❌ Malicious traffic hiding
- ❌ Commercial VPN services
- ❌ Production network deployment without proper authorization

## 📜 License

This project extends the OblivionEdge codebase and follows its licensing terms. See the original OblivionEdge documentation for details.

## 🎯 Future Enhancements

- [ ] Support for additional geographic locations
- [ ] Dynamic route optimization based on performance
- [ ] Integration with real VPN exit points
- [ ] Enhanced traffic pattern analysis
- [ ] Machine learning-based anomaly detection
- [ ] Integration with SIEM systems
- [ ] Support for IPv6 geographic routing
- [ ] Hardware TPM integration for containers

---

**Built with OblivionEdge by OBLIVION EDGE LLC**  
*"Free the Router. Free the Code."*

For questions and support, contact: 1337_tech@fortressofsolitude.org