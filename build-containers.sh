#!/bin/bash
# Build OblivionEdge containers with onion routing support
# Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

set -e

echo "Building OblivionEdge containers with onion routing support..."

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ] || [ ! -d "src/onion_routing" ]; then
    echo "Error: Please run this script from the router-n-routers directory"
    exit 1
fi

# Create a temporary build directory
BUILD_DIR="/tmp/oblivion-build-$(date +%s)"
echo "Creating build directory: $BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy OblivionEdge source
echo "Copying OblivionEdge source code..."
cp -r OblivionEdge-OblivionEdge_Dev/* "$BUILD_DIR/"

# Copy our onion routing implementation
echo "Integrating onion routing implementation..."
mkdir -p "$BUILD_DIR/router_n_routers"
cp -r src/ "$BUILD_DIR/router_n_routers/"
cp Cargo.toml "$BUILD_DIR/router_n_routers/"

# Create a new Cargo workspace that includes both
echo "Creating integrated Cargo workspace..."
cat > "$BUILD_DIR/Cargo.toml" << 'EOF'
[workspace]
resolver = "2"
members = [
    ".",
    "router_n_routers",
    "oblivion_admin_cli_deprecated",
    "monitoring",
]

[workspace.dependencies]
tokio = { version = "1.28", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
anyhow = "1.0"
tracing = "0.1"

[package]
name = "oblivion-edge-workspace"
version = "0.1.0"
edition = "2021"

[dependencies]
router_n_routers = { path = "router_n_routers" }
EOF

# Update the Dockerfile to build our onion routing components
echo "Updating Dockerfile for integrated build..."
cat > "$BUILD_DIR/Dockerfile.router.updated" << 'EOF'
# OblivionEdge Geographic Router Container with Onion Routing
# Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

FROM rust:1.83-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    musl-dev \
    linux-headers \
    openssl-dev \
    pkgconfig \
    gcc \
    make \
    libc6-compat \
    wireguard-tools-wg-quick && \
    ln -sf /usr/bin/gcc /usr/bin/musl-gcc

WORKDIR /src

# Install musl target
RUN rustup target add x86_64-unknown-linux-musl

# Copy source code
COPY . .

# Build all components including onion routing
RUN cargo build --release --target x86_64-unknown-linux-musl --workspace

# Build specifically our onion routing binaries
RUN cd router_n_routers && \
    cargo build --release --target x86_64-unknown-linux-musl --bins

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    iptables \
    ip6tables \
    iproute2 \
    wireguard-tools \
    openssl \
    curl \
    bind-tools \
    tcpdump \
    net-tools \
    bridge-utils \
    dbus \
    supervisor \
    tini

# Create user for oblivion processes
RUN addgroup -g 1000 oblivion && \
    adduser -D -s /bin/sh -u 1000 -G oblivion oblivion

# Copy built OblivionEdge binaries
COPY --from=builder /src/target/x86_64-unknown-linux-musl/release/oblivion_ztna_daemon /usr/bin/

# Copy onion routing binaries
COPY --from=builder /src/router_n_routers/target/x86_64-unknown-linux-musl/release/onion-client /usr/bin/
COPY --from=builder /src/router_n_routers/target/x86_64-unknown-linux-musl/release/onion-server /usr/bin/

# Copy admin CLI if it exists
RUN --mount=from=builder,source=/src/target/x86_64-unknown-linux-musl/release,target=/tmp/release \
    if [ -f /tmp/release/oblivion_admin_cli ]; then \
        cp /tmp/release/oblivion_admin_cli /usr/bin/; \
    else \
        echo "#!/bin/sh\necho 'OblivionEdge Admin CLI - not available in this build'\nexit 1" > /usr/bin/oblivion_admin_cli; \
        chmod +x /usr/bin/oblivion_admin_cli; \
    fi

# Copy monitoring if it exists
RUN --mount=from=builder,source=/src/target/x86_64-unknown-linux-musl/release,target=/tmp/release \
    if [ -f /tmp/release/oblivion_suspect_monitoring ]; then \
        cp /tmp/release/oblivion_suspect_monitoring /usr/bin/; \
    else \
        echo "#!/bin/sh\necho 'OblivionEdge Monitoring - not available in this build'\nexit 1" > /usr/bin/oblivion_suspect_monitoring; \
        chmod +x /usr/bin/oblivion_suspect_monitoring; \
    fi

# Create necessary directories
RUN mkdir -p /etc/oblivion \
    /var/log/oblivion \
    /var/lib/oblivion \
    /etc/wireguard \
    /etc/dhcp \
    /dev/net \
    /sys/class/net \
    /etc/onion

# Create TUN device
RUN mkdir -p /dev/net && \
    mknod /dev/net/tun c 10 200 && \
    chmod 600 /dev/net/tun

# Copy configuration templates
COPY docker/router-configs/ /etc/oblivion/templates/
COPY docker/scripts/ /usr/local/bin/

# Copy supervisor configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/oblivion.conf

# Create onion routing startup script
RUN echo '#!/bin/sh' > /usr/local/bin/start-onion-server.sh && \
    echo 'set -e' >> /usr/local/bin/start-onion-server.sh && \
    echo '' >> /usr/local/bin/start-onion-server.sh && \
    echo 'HOP_ID="${GEOGRAPHIC_LOCATION:-${ROUTER_ROLE}}"' >> /usr/local/bin/start-onion-server.sh && \
    echo 'LISTEN_ADDR="0.0.0.0:9001"' >> /usr/local/bin/start-onion-server.sh && \
    echo '' >> /usr/local/bin/start-onion-server.sh && \
    echo 'echo "Starting onion routing server for hop: $HOP_ID"' >> /usr/local/bin/start-onion-server.sh && \
    echo 'exec /usr/bin/onion-server "$HOP_ID" "$LISTEN_ADDR"' >> /usr/local/bin/start-onion-server.sh && \
    chmod +x /usr/local/bin/start-onion-server.sh

# Update supervisor config to include onion server
RUN echo '' >> /etc/supervisor/conf.d/oblivion.conf && \
    echo '[program:onion-server]' >> /etc/supervisor/conf.d/oblivion.conf && \
    echo 'command=/usr/local/bin/start-onion-server.sh' >> /etc/supervisor/conf.d/oblivion.conf && \
    echo 'autostart=true' >> /etc/supervisor/conf.d/oblivion.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/oblivion.conf && \
    echo 'user=oblivion' >> /etc/supervisor/conf.d/oblivion.conf && \
    echo 'stdout_logfile=/var/log/oblivion/onion-server.log' >> /etc/supervisor/conf.d/oblivion.conf && \
    echo 'stderr_logfile=/var/log/oblivion/onion-server.error.log' >> /etc/supervisor/conf.d/oblivion.conf

# Copy wrapper entrypoint script
COPY entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh

# Use the existing entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/entrypoint-wrapper.sh

# Expose common ports + onion routing port
EXPOSE 51820-51829/udp 8443/tcp 80/tcp 443/tcp 53/udp 9001/tcp

# Use tini as init
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/bin/oblivion_admin_cli status || exit 1

# Labels
LABEL maintainer="Blake De Garza <1337_tech@fortressofsolitude.org>"
LABEL description="OblivionEdge Geographic Router with Onion Routing Support"
LABEL version="1.1"
LABEL org.oblivion-edge.component="geographic-router-onion"
EOF

# Build the updated container
echo "Building updated container with onion routing..."
cd "$BUILD_DIR"

# Stop and remove existing containers
echo "Stopping existing containers..."
cd /home/bdg/Documents/projects/OBLIVION_EDGE_LLC/ResearchAndDev/router-n-routers/docs/config
sudo ./compose down || true

# Build new image
echo "Building new Docker image..."
cd "$BUILD_DIR"
sudo docker build -f Dockerfile.router.updated -t oblivion-edge-router:with-onion .

# Update docker-compose to use new image
echo "Updating docker-compose configuration..."
cd /home/bdg/Documents/projects/OBLIVION_EDGE_LLC/ResearchAndDev/router-n-routers/docs/config
sudo sed -i 's/image: oblivion-edge-router.*/image: oblivion-edge-router:with-onion/' docker-compose.yml || true

# Clean up build directory
echo "Cleaning up build directory..."
rm -rf "$BUILD_DIR"

echo ""
echo "Container build completed successfully!"
echo ""
echo "The containers now include:"
echo "  - Original OblivionEdge components"
echo "  - Onion routing client (/usr/bin/onion-client)"
echo "  - Onion routing server (/usr/bin/onion-server)"
echo "  - Automatic onion server startup on each hop"
echo ""
echo "To start the updated containers:"
echo "  cd /home/bdg/Documents/projects/OBLIVION_EDGE_LLC/ResearchAndDev/router-n-routers/docs/config"
echo "  sudo ./compose up -d"
echo ""
echo "The onion servers will automatically start on port 9001 in each container."