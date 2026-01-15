#!/usr/bin/env bash

set -e

# ===== ENSURE PROMETHEUS IS STOPPED FIRST ===================================
if sudo docker ps --format '{{.Names}}' | grep -q "^prometheus$"; then
    echo -e "${RUN} ${DOCKER} Prometheus is running. Stopping it first."
    sudo docker stop prometheus || true
    echo -e "${OK} Prometheus container stopped."
fi

# ===== CONFIG ================================================================
PROMETHEUS_NAME="prometheus"
PROMETHEUS_DATA="/opt/prometheus_data"
PROMETHEUS_PORT=9090
PROMETHEUS_CONFIG="/opt/prometheus_data/prometheus.yml"

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

# ===== PROMETHEUS DEFAULT CONFIG =============================================
DEFAULT_CONFIG="global:\n  scrape_interval: 15s\n\nscrape_configs:\n  - job_name: 'prometheus'\n    static_configs:\n      - targets: ['localhost:9090']\n"

echo -e "\n${BOLD}${RUN} Prometheus deployment started${RESET}\n"

# ===== FIX DATA DIR PERMISSIONS =============================================
echo -e "${RUN} ${PORT} Stopping and removing Prometheus container if running"
if sudo docker ps -a --format '{{.Names}}' | grep -q "^${PROMETHEUS_NAME}$"; then
    sudo docker stop "${PROMETHEUS_NAME}" || true
    sudo docker rm "${PROMETHEUS_NAME}" || true
    echo -e "${OK} Prometheus container stopped and removed"
fi

echo -e "${RUN} ${PORT} Setting permissions on Prometheus data directory"
sudo mkdir -p "$PROMETHEUS_DATA"
sudo chown -R nobody:nogroup "$PROMETHEUS_DATA"
sudo chmod -R 775 "$PROMETHEUS_DATA"
echo -e "${OK} Permissions set: $PROMETHEUS_DATA"

# ===== CHECK DOCKER ==========================================================
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${WARN} Docker not installed"
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    echo -e "${WARN} Docker service not running"
    exit 1
fi

# ===== REMOVE EXISTING PROMETHEUS ============================================
if sudo docker ps -a --format '{{.Names}}' | grep -q "^${PROMETHEUS_NAME}$"; then
    echo -e "${RUN} ${DOCKER} Stopping existing Prometheus container"
    sudo docker stop "${PROMETHEUS_NAME}" || true
    echo -e "${RUN} ${DOCKER} Removing existing Prometheus container"
    sudo docker rm "${PROMETHEUS_NAME}" || true
    echo -e "${OK} Existing Prometheus removed"
fi

if [ -d "$PROMETHEUS_DATA" ]; then
    echo -e "${RUN} ${PORT} Removing old Prometheus data"
    sudo rm -rf "$PROMETHEUS_DATA"
    echo -e "${OK} Old data removed"
fi

# ===== CREATE DATA VOLUME & CONFIG ===========================================
echo -e "${RUN} ${PORT} Creating new Prometheus data volume"
sudo mkdir -p "$PROMETHEUS_DATA"

if [ ! -f "$PROMETHEUS_CONFIG" ]; then
    echo -e "${RUN} ${PORT} Creating default Prometheus config"
    echo -e "$DEFAULT_CONFIG" | sudo tee "$PROMETHEUS_CONFIG" >/dev/null
    echo -e "${OK} Default config created: ${PROMETHEUS_CONFIG}"
fi

# ===== FINAL PERMISSION FIX BEFORE LAUNCH ====================================
echo -e "${RUN} ${PORT} Final permission fix before starting Prometheus container"
sudo chown -R nobody:nogroup "$PROMETHEUS_DATA"
sudo chmod -R 775 "$PROMETHEUS_DATA"
echo -e "${OK} Permissions set: $PROMETHEUS_DATA"

# ===== DEPLOY PROMETHEUS =====================================================
echo -e "${RUN} ${DOCKER} Pulling latest Prometheus image"
sudo docker pull prom/prometheus:latest

echo -e "${RUN} ${DOCKER} Starting fresh Prometheus container"
sudo docker run -d \
    --name "${PROMETHEUS_NAME}" \
    --restart=always \
    --user 65534:65534 \
    -p ${PROMETHEUS_PORT}:9090 \
    -v "${PROMETHEUS_DATA}:/prometheus" \
    -v "${PROMETHEUS_CONFIG}:/etc/prometheus/prometheus.yml" \
    prom/prometheus:latest

# ===== GET HOSTNAME ==========================================================
HOSTNAME=$(hostname)

echo -e "${OK} Prometheus deployed successfully"
echo -e "${OK} Access it at: http://${HOSTNAME}:${PROMETHEUS_PORT}/\n"
