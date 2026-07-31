#!/bin/bash
# Docker Compose Hooks for OblivionEdge Geographic Router
# Automatically manages host routing when containers are started/stopped

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETUP_SCRIPT="$PROJECT_DIR/setup_host.sh"

# Check if running as root (needed for routing changes)
if [ "$EUID" -ne 0 ]; then
    echo "Warning: Routing hooks require root privileges"
    exit 0
fi

# Function to wait for containers to be ready
wait_for_containers() {
    echo "Waiting for geographic router containers to initialize..."
    sleep 10

    # Check if containers are running
    local attempts=0
    local max_attempts=20

    while [ $attempts -lt $max_attempts ]; do
        # Check if primary container is running
        if docker compose ps oblivion-primary | grep -q "Up" >/dev/null 2>&1; then
            echo "Primary router container is running"

            # Test basic network connectivity to the primary router
            if ping -c 1 -W 2 172.20.0.10 >/dev/null 2>&1; then
                echo "Geographic router network is ready"
                return 0
            else
                echo "Primary router container running but network not ready, waiting..."
            fi
        else
            echo "Waiting for containers to start... (attempt $((attempts+1))/$max_attempts)"
        fi

        sleep 3
        ((attempts++))
    done

    echo "Warning: Geographic router network may not be fully ready"
    echo "You can manually configure routing later with: sudo ../../setup_host.sh setup"
    return 1
}

# Hook for docker compose up
on_compose_up() {
    echo "Geographic router network started - configuring host routing..."

    if wait_for_containers; then
        if [ -x "$SETUP_SCRIPT" ]; then
            "$SETUP_SCRIPT" setup
        else
            echo "Setup script not found or not executable: $SETUP_SCRIPT"
        fi
    else
        echo "Skipping host routing setup due to container initialization issues"
    fi
}

# Hook for docker compose down
on_compose_down() {
    echo "Geographic router network stopping - restoring normal routing..."

    if [ -x "$SETUP_SCRIPT" ]; then
        "$SETUP_SCRIPT" stop
    else
        echo "Setup script not found: $SETUP_SCRIPT"
    fi
}

# Main command processing
case "${1:-}" in
    "up")
        on_compose_up
        ;;
    "down")
        on_compose_down
        ;;
    *)
        echo "Usage: $0 {up|down}"
        echo "  up    - Configure host routing after containers start"
        echo "  down  - Restore normal routing before containers stop"
        exit 1
        ;;
esac