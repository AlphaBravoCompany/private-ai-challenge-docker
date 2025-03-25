#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Detect if Docker or Podman is available
if command -v docker &> /dev/null; then
    CONTAINER_ENGINE="docker"
    COMPOSE_CMD="docker compose"
    CHECK_RUNNING="$CONTAINER_ENGINE ps"
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
    CHECK_RUNNING="$CONTAINER_ENGINE ps"
else
    echo -e "${RED}Error: Neither Docker nor Podman is available.${NC}"
    echo -e "${YELLOW}Please install either Docker or Podman to continue.${NC}"
    exit 1
fi

echo -e "${GREEN}Using container engine: ${CONTAINER_ENGINE} with compose command: ${COMPOSE_CMD}${NC}"

# Default ports
OLLAMA_PORT=11444
WEBUI_PORT=8090

# Default model
DEFAULT_MODEL="gemma:2b"

# Function to display status messages
status() {
    echo -e "${YELLOW}[STATUS]${NC} $1"
}

# Function to display success messages
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display error messages
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to display warning messages
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if a command was successful
check_status() {
    if [ $? -eq 0 ]; then
        success "$1"
    else
        error "$2"
    fi
}

# Note: Port checking has been removed as requested

# Print banner
echo -e "${CYAN}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                 PRIVATE AI DEPLOYMENT TOOL                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to get local IP address
get_local_ip() {
    local ip
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    elif command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
    else
        # Fallback to hostname command
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo "$ip"
}

# Get the server IP address
echo -e "${MAGENTA}This script will deploy Ollama and Open WebUI on your server.${NC}"

# Try to detect local IP address
DETECTED_IP=$(get_local_ip)
if [ -n "$DETECTED_IP" ]; then
    echo -e "${YELLOW}Please enter your server's IP address (detected: $DETECTED_IP):${NC}"
    read -p "> " SERVER_IP
    
    # Use detected IP if user didn't enter anything
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="$DETECTED_IP"
        echo -e "${BLUE}Using detected IP: $SERVER_IP${NC}"
    fi
else
    echo -e "${YELLOW}Please enter your server's IP address:${NC}"
    read -p "> " SERVER_IP
    
    # Provide localhost as fallback
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="127.0.0.1"
        echo -e "${BLUE}Using localhost (127.0.0.1) as default${NC}"
    fi
fi

# Validate IP address format (basic validation)
if [[ ! $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${YELLOW}Warning: '$SERVER_IP' doesn't look like a standard IP address.${NC}"
    read -p "Continue anyway? (y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${RED}Deployment cancelled.${NC}"
        exit 1
    fi
fi

# Port configuration information
echo -e "\n${CYAN}${BOLD}PORT CONFIGURATION:${NC}"
status "Using default ports: Ollama ($OLLAMA_PORT) and Open WebUI ($WEBUI_PORT)"

# Check if container engine is running
if ! $CONTAINER_ENGINE info >/dev/null 2>&1; then
    warning "$CONTAINER_ENGINE is not running or you don't have permission to use it."
    read -p "Do you want to continue anyway? (y/n): " engine_continue
    if [[ ! $engine_continue =~ ^[Yy]$ ]]; then
        error "Deployment cancelled. Please start $CONTAINER_ENGINE and try again."
    fi
fi

echo -e "${YELLOW}Note: If you encounter port conflicts during deployment, you can:${NC}"
echo -e "  ${BLUE}1. Edit the docker-compose.yml files manually to change ports${NC}"
echo -e "  ${BLUE}2. Stop any containers using these ports with '$CONTAINER_ENGINE stop <container-name>'${NC}"
echo -e "  ${BLUE}3. Run '$CONTAINER_ENGINE ps' to see which containers might be using these ports${NC}"

# Model selection
echo -e "\n${CYAN}${BOLD}MODEL SELECTION:${NC}"
echo -e "${YELLOW}Choose an AI model to download:${NC}"
echo -e "  ${BLUE}1. Gemma 2B (Default, smallest, fastest)${NC}"
echo -e "  ${BLUE}2. Llama 2 7B (Medium size, better quality)${NC}"
echo -e "  ${BLUE}3. Mistral 7B (Medium size, good performance)${NC}"
echo -e "  ${BLUE}4. Phi-2 (Small but powerful)${NC}"
echo -e "  ${BLUE}5. Enter a custom model name from https://ollama.com/library${NC}"

read -p "Select an option [1-5] (default: 1): " model_option

case $model_option in
    2)
        MODEL="llama2:7b"
        MODEL_DISPLAY="Llama 2 7B"
        ;;
    3)
        MODEL="mistral:7b"
        MODEL_DISPLAY="Mistral 7B"
        ;;
    4)
        MODEL="phi:2"
        MODEL_DISPLAY="Phi-2"
        ;;
    5)
        echo -e "${YELLOW}Enter the model name from https://ollama.com/library${NC}"
        echo -e "${YELLOW}Format should be 'name:tag' (e.g., 'llama2:7b' or 'mistral:latest')${NC}"
        read -p "> " custom_model
        if [ -z "$custom_model" ]; then
            MODEL="$DEFAULT_MODEL"
            MODEL_DISPLAY="Gemma 2B (default)"
        else
            MODEL="$custom_model"
            MODEL_DISPLAY="$custom_model (custom)"
            echo -e "${YELLOW}Warning: Using a custom model. Make sure it exists on Ollama.${NC}"
            echo -e "${YELLOW}Larger models will require more memory and may run slowly on limited hardware.${NC}"
            read -p "Continue with this model? (y/n): " confirm_model
            if [[ ! $confirm_model =~ ^[Yy]$ ]]; then
                echo -e "${RED}Deployment cancelled.${NC}"
                exit 1
            fi
        fi
        ;;
    *)
        MODEL="$DEFAULT_MODEL"
        MODEL_DISPLAY="Gemma 2B (default)"
        ;;
esac

echo -e "\n${CYAN}${BOLD}DEPLOYMENT PLAN:${NC}"
echo -e "  ${BLUE}1. Deploy Ollama server on port $OLLAMA_PORT${NC}"
echo -e "  ${BLUE}2. Download the $MODEL_DISPLAY model${NC}"
echo -e "  ${BLUE}3. Deploy Open WebUI on port $WEBUI_PORT with your server IP ($SERVER_IP)${NC}"
echo -e "  ${BLUE}4. Verify the deployment${NC}"
echo

# Confirm deployment
read -p "Proceed with deployment? (y/n): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 1
fi

echo

# Store the base directory path
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Step 1: Update Ollama docker-compose.yml with the selected port
status "Updating Ollama configuration with port $OLLAMA_PORT..."
cd "$BASE_DIR/ollama" || error "Ollama directory not found!"

# Update the port in the docker-compose.yml file
sed -i "s/- \"11434:11434\"/- \"$OLLAMA_PORT:11434\"/g" docker-compose.yml
check_status "Updated Ollama port configuration" "Failed to update Ollama port configuration"

# Note: Port conflict checking has been removed as requested

# Check if Ollama is already running and stop it if it is
if $CHECK_RUNNING | grep -q "ollama"; then
    status "Ollama is already running. Stopping it first..."
    $COMPOSE_CMD down
    check_status "Stopped existing Ollama container" "Failed to stop Ollama container"
fi

# Start Ollama
$COMPOSE_CMD up -d

# Check if the container started successfully
if [ $? -ne 0 ]; then
    error "Failed to start Ollama server. This might be due to port conflicts.\n\n${YELLOW}To resolve port conflicts:${NC}\n1. Edit 'ollama/docker-compose.yml' and change the port mapping\n2. Look for the line: '- \"$OLLAMA_PORT:11434\"' and change $OLLAMA_PORT to a different value\n3. Run this script again or use 'docker-compose up -d' in the ollama directory"
else
    success "Ollama server started successfully"
fi

# Wait for Ollama to initialize
status "Waiting for Ollama to initialize (this may take a few seconds)..."
sleep 5

# Verify Ollama is running
status "Verifying Ollama server..."
curl -s "http://$SERVER_IP:$OLLAMA_PORT" > /dev/null
check_status "Ollama is running at http://$SERVER_IP:$OLLAMA_PORT" "Failed to connect to Ollama at http://$SERVER_IP:$OLLAMA_PORT"

# Step 2: Download the selected model
status "Downloading $MODEL_DISPLAY model (this may take several minutes)..."
$CONTAINER_ENGINE exec -it ollama ollama pull $MODEL
check_status "$MODEL_DISPLAY model downloaded successfully" "Failed to download $MODEL_DISPLAY model"

# Verify model is available
status "Verifying model availability..."
MODEL_LIST=$($CONTAINER_ENGINE exec -it ollama ollama list)
if echo "$MODEL_LIST" | grep -q "$MODEL"; then
    success "$MODEL_DISPLAY model is available"
else
    error "$MODEL_DISPLAY model not found in Ollama"
fi

# Step 3: Deploy Open WebUI
status "Deploying Open WebUI..."

# Return to the base directory before proceeding
cd "$BASE_DIR" || error "Failed to return to base directory!"

# Now change to the open-webui directory
cd "$BASE_DIR/open-webui" || error "Open WebUI directory not found!"

# Update the docker-compose.yml file with the server IP and ports
status "Updating Open WebUI configuration with server IP: $SERVER_IP and ports"
sed -i "s|OLLAMA_BASE_URL=http://YOUR-SERVER-IP:11434|OLLAMA_BASE_URL=http://$SERVER_IP:$OLLAMA_PORT|g" docker-compose.yml
sed -i "s/- 8080:8080/- $WEBUI_PORT:8080/g" docker-compose.yml
check_status "Updated Open WebUI configuration" "Failed to update Open WebUI configuration"

# Note: Port conflict checking has been removed as requested

# Check if Open WebUI is already running and stop it if it is
if $CHECK_RUNNING | grep -q "open-webui"; then
    status "Open WebUI is already running. Stopping it first..."
    $COMPOSE_CMD down
    check_status "Stopped existing Open WebUI container" "Failed to stop Open WebUI container"
fi

# Start Open WebUI
$COMPOSE_CMD up -d

# Check if the container started successfully
if [ $? -ne 0 ]; then
    error "Failed to start Open WebUI. This might be due to port conflicts.\n\n${YELLOW}To resolve port conflicts:${NC}\n1. Edit 'open-webui/docker-compose.yml' and change the port mapping\n2. Look for the line: '- $WEBUI_PORT:8080' and change $WEBUI_PORT to a different value\n3. Run this script again or use 'docker-compose up -d' in the open-webui directory"
else
    success "Open WebUI started successfully"
fi

# Step 4: Verify deployment
echo
echo -e "${CYAN}${BOLD}DEPLOYMENT SUMMARY:${NC}"
echo -e "  ${GREEN}✓ Ollama server:${NC} Running at http://$SERVER_IP:$OLLAMA_PORT"
echo -e "  ${GREEN}✓ $MODEL_DISPLAY model:${NC} Installed and ready to use"
echo -e "  ${GREEN}✓ Open WebUI:${NC} Running at http://$SERVER_IP:$WEBUI_PORT"
echo
echo -e "${MAGENTA}${BOLD}NEXT STEPS:${NC}"
echo -e "  ${BLUE}1. Open a web browser and navigate to:${NC} ${BOLD}http://$SERVER_IP:$WEBUI_PORT${NC}"
echo -e "  ${BLUE}2. Create an account and login${NC}"
echo -e "  ${BLUE}3. Select the ${BOLD}$MODEL${NC} model at the top of the screen${NC}"
echo -e "  ${BLUE}4. Start chatting with your private AI!${NC}"
echo
echo -e "${YELLOW}Note: Initial responses may be slow as the model is running on CPU.${NC}"
if [[ "$MODEL" != "$DEFAULT_MODEL" ]]; then
    echo -e "${YELLOW}Warning: You selected a non-default model which may require more resources.${NC}"
    echo -e "${YELLOW}If you experience performance issues, consider switching to a smaller model like gemma:2b.${NC}"
fi
echo -e "${GREEN}${BOLD}Deployment completed successfully!${NC}"
