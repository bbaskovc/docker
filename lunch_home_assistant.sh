#!/usr/bin/env bash

set -e
# ===== COLORS & ICONS ========================================================
RESET="\033[0m"
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
OK="${GREEN}✔${RESET}"
WARN="${YELLOW}⚠${RESET}"
RUN="${CYAN}➜${RESET}"
DOCKER="🐳"
PORT="🖥️ "

# ===== HOME ASSISTANT CONFIG =================================================
HA_NAME="home-assistant"
HA_PORT=9070
HA_DATA="/opt/home_assistant_data"

# ===== HOME ASSISTANT DEPLOYMENT =============================================
echo -e "${RUN} ${DOCKER} Setting up Home Assistant..."
sudo mkdir -p "$HA_DATA"
sudo chown -R 1000:1000 "$HA_DATA"
sudo chmod -R 755 "$HA_DATA"
sudo docker pull ghcr.io/home-assistant/home-assistant:stable
echo -e "${RUN} ${DOCKER} Starting Home Assistant container..."
sudo docker run -d \
    --name "$HA_NAME" \
    --restart=always \
    -p ${HA_PORT}:8123 \
    -v "$HA_DATA:/config" \
    --privileged \
    ghcr.io/home-assistant/home-assistant:stable

echo -e "${OK} Home Assistant deployed. Access at: http://$(hostname):${HA_PORT}/"
