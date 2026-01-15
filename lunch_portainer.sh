#!/usr/bin/env bash

set -e

# ===== CONFIG ================================================================
PORTAINER_NAME="portainer"
PORTAINER_DATA="/opt/portainer_data"
PORTAINER_PORT=9443   # HTTPS port
DOCKER_SOCKET="/var/run/docker.sock"

# ===== COLORS & ICONS ========================================================
RESET="\033[0m"
BOLD="\033[1m"

GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"

OK="${GREEN}✔${RESET}"
WARN="${YELLOW}⚠${RESET}"
RUN="${CYAN}➜${RESET}"

DOCKER="🐳"
PORT="🖥️ "

echo -e "\n${BOLD}${RUN} Portainer deployment started${RESET}\n"

# ===== CHECK DOCKER ==========================================================
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${WARN} Docker not installed"
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    echo -e "${WARN} Docker service not running"
    exit 1
fi

# ===== REMOVE EXISTING PORTAINER =============================================
if sudo docker ps -a --format '{{.Names}}' | grep -q "^${PORTAINER_NAME}$"; then
    echo -e "${RUN} ${DOCKER} Stopping existing Portainer container"
    sudo docker stop "${PORTAINER_NAME}" || true
    echo -e "${RUN} ${DOCKER} Removing existing Portainer container"
    sudo docker rm "${PORTAINER_NAME}" || true
    echo -e "${OK} Existing Portainer removed"
fi

if [ -d "$PORTAINER_DATA" ]; then
    echo -e "${RUN} ${PORT} Removing old Portainer data"
    sudo rm -rf "$PORTAINER_DATA"
    echo -e "${OK} Old data removed"
fi

# ===== CREATE DATA VOLUME ====================================================
echo -e "${RUN} ${PORT} Creating new Portainer data volume"
sudo mkdir -p "$PORTAINER_DATA"
sudo chown 1000:1000 "$PORTAINER_DATA"
echo -e "${OK} Data volume ready: ${PORTAINER_DATA}"

# ===== DEPLOY PORTAINER ======================================================
echo -e "${RUN} ${DOCKER} Pulling latest Portainer image"
sudo docker pull portainer/portainer-ce:latest

echo -e "${RUN} ${DOCKER} Starting fresh Portainer container"
sudo docker run -d \
    --name "${PORTAINER_NAME}" \
    --restart=always \
    -p ${PORTAINER_PORT}:9443 \
    -v "${DOCKER_SOCKET}:${DOCKER_SOCKET}" \
    -v "${PORTAINER_DATA}:/data" \
    portainer/portainer-ce:latest

# ===== GET HOSTNAME ==========================================================
HOSTNAME=$(hostname)

echo -e "${OK} Portainer deployed successfully"
echo -e "${OK} Access it at: https://${HOSTNAME}:${PORTAINER_PORT}/\n"
