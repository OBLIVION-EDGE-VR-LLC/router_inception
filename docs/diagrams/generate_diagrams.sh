#!/bin/bash
# Generate PNG diagrams from PlantUML source files
# Copyright © OBLIVION EDGE LLC, 2026. All rights reserved.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 Generating OblivionEdge Architecture Diagrams${NC}"
echo

# Check if PlantUML is available
if command -v plantuml &> /dev/null; then
    PLANTUML_CMD="plantuml"
elif command -v java &> /dev/null && [ -f "/usr/share/plantuml/plantuml.jar" ]; then
    PLANTUML_CMD="java -jar /usr/share/plantuml/plantuml.jar"
elif [ -f "$SCRIPT_DIR/plantuml.jar" ]; then
    PLANTUML_CMD="java -jar $SCRIPT_DIR/plantuml.jar"
else
    echo -e "${RED}❌ PlantUML not found!${NC}"
    echo
    echo "Please install PlantUML:"
    echo "  Ubuntu/Debian: sudo apt-get install plantuml"
    echo "  macOS:         brew install plantuml"
    echo "  Manual:        Download plantuml.jar and place in this directory"
    echo
    echo "Or download from: https://plantuml.com/download"
    exit 1
fi

cd "$SCRIPT_DIR"

# List of diagram files to generate
DIAGRAMS=(
    "network_topology.puml"
    "geographic_routing.puml"
    "container_architecture.puml"
    "security_flow.puml"
)

echo "Found PlantUML: $PLANTUML_CMD"
echo

# Generate each diagram
for diagram in "${DIAGRAMS[@]}"; do
    if [ -f "$diagram" ]; then
        echo -e "${YELLOW}🔄 Generating ${diagram%.puml}.png...${NC}"

        if $PLANTUML_CMD "$diagram"; then
            echo -e "${GREEN}✅ Generated ${diagram%.puml}.png${NC}"
        else
            echo -e "${RED}❌ Failed to generate ${diagram%.puml}.png${NC}"
        fi
    else
        echo -e "${RED}❌ File not found: $diagram${NC}"
    fi
    echo
done

# Check if all diagrams were generated
echo -e "${BLUE}📋 Generated Diagram Files:${NC}"
for diagram in "${DIAGRAMS[@]}"; do
    png_file="${diagram%.puml}.png"
    if [ -f "$png_file" ]; then
        echo -e "${GREEN}✅ $png_file${NC}"
    else
        echo -e "${RED}❌ $png_file${NC}"
    fi
done

echo
echo -e "${GREEN}🎉 Diagram generation completed!${NC}"
echo
echo "The generated PNG files can be viewed in your browser or image viewer:"
echo "  • network_topology.png     - Complete network architecture"
echo "  • geographic_routing.png   - Traffic flow through geographic hops"
echo "  • container_architecture.png - Docker container deployment"
echo "  • security_flow.png        - Security and encryption workflows"
echo
echo "These diagrams are referenced in the main README.md file."