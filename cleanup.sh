#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect if Docker or Podman is available
if command -v docker &> /dev/null; then
    CONTAINER_ENGINE="docker"
    COMPOSE_CMD="docker compose"
elif command -v podman &> /dev/null; then
    CONTAINER_ENGINE="podman"
    # Check if podman-compose is installed
    if command -v podman-compose &> /dev/null; then
        COMPOSE_CMD="podman-compose"
    elif podman compose version &> /dev/null; then
        COMPOSE_CMD="podman compose"
    else
        echo -e "${YELLOW}Warning: Neither podman-compose nor podman compose is available.${NC}"
        echo -e "${YELLOW}Please install one of them to continue:${NC}"
        echo -e "  - For podman-compose: pip3 install podman-compose"
        echo -e "  - For podman compose: Make sure you have a recent version of Podman"
        exit 1
    fi
else
    echo -e "${RED}Error: Neither Docker nor Podman is available.${NC}"
    echo -e "${YELLOW}Please install either Docker or Podman to continue.${NC}"
    exit 1
fi

echo -e "${GREEN}Using container engine: ${CONTAINER_ENGINE} with compose command: ${COMPOSE_CMD}${NC}"

echo -e "${YELLOW}=== Container Cleanup Script ===${NC}"
echo -e "${YELLOW}This script will:${NC}"
echo -e "  ${RED}1. Stop and remove all containers from Ollama and Open WebUI${NC}"
echo -e "  ${RED}2. Remove all volumes associated with these services${NC}"
echo -e "  ${RED}3. Delete the local data directories${NC}"
echo
echo -e "${YELLOW}The following will be removed:${NC}"
echo -e "  - Ollama container and its data volume"
echo -e "  - Open WebUI container and its data volume (openwebui_data)"
echo -e "  - ./ollama/ollama_data directory"
echo
echo -e "${RED}WARNING: This action is irreversible. All data will be permanently deleted.${NC}"
echo

# Ask for confirmation
read -p "Are you sure you want to proceed? Type 'yes' to confirm: " confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled. No changes were made.${NC}"
    exit 0
fi

echo
echo -e "${YELLOW}Starting cleanup process...${NC}"

# Store the base directory path
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Stop and remove Ollama containers and volumes
echo -e "Stopping and removing Ollama containers and volumes..."
cd "$BASE_DIR/ollama" || { echo "Ollama directory not found"; exit 1; }
$COMPOSE_CMD down -v
echo -e "${GREEN}Ollama containers and volumes removed.${NC}"

# Remove Ollama data directory
if [ -d "./ollama_data" ]; then
    echo -e "Removing Ollama data directory..."
    
    # Try normal removal first
    rm -rf ./ollama_data 2>/dev/null
    
    # Check if directory still exists (permission issues)
    if [ -d "./ollama_data" ]; then
        echo -e "${YELLOW}Permission issues detected. Trying with sudo...${NC}"
        # Ask for sudo permission
        sudo rm -rf ./ollama_data || {
            echo -e "${YELLOW}Warning: Could not remove some files in ollama_data due to permission issues.${NC}"
            echo -e "${YELLOW}You may need to manually remove them with: sudo rm -rf $BASE_DIR/ollama/ollama_data${NC}"
        }
    fi
    
    echo -e "${GREEN}Ollama data directory removal attempted.${NC}"
fi

# Return to the base directory before proceeding
cd "$BASE_DIR" || { echo "Failed to return to base directory"; exit 1; }

# Stop and remove Open WebUI containers and volumes
echo -e "Stopping and removing Open WebUI containers and volumes..."
cd "$BASE_DIR/open-webui" || { echo "Open WebUI directory not found"; exit 1; }
$COMPOSE_CMD down -v
echo -e "${GREEN}Open WebUI containers and volumes removed.${NC}"

# Return to the base directory
cd "$BASE_DIR" || exit

# Check if any containers are still running
remaining_containers=$($CONTAINER_ENGINE ps -a --filter "name=ollama|open-webui" --format "{{.Names}}" 2>/dev/null)
if [ -n "$remaining_containers" ]; then
    echo -e "${YELLOW}Some containers may still exist. Consider removing them manually:${NC}"
    echo "$remaining_containers"
fi

# Check if any volumes are still present
remaining_volumes=$($CONTAINER_ENGINE volume ls --filter "name=ollama|openwebui" --format "{{.Name}}" 2>/dev/null)
if [ -n "$remaining_volumes" ]; then
    echo -e "${YELLOW}Some volumes may still exist. Consider removing them manually:${NC}"
    echo "$remaining_volumes"
fi

echo
echo -e "${GREEN}Cleanup completed successfully!${NC}"
echo -e "${YELLOW}If you want to restart the services, you can run the '$COMPOSE_CMD up' commands in their respective directories.${NC}"
