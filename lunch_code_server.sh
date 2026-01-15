#!/usr/bin/env bash

set -e

# ===== GENERATE RANDOM PASSWORD EACH RUN =====================================
PASSWORD=$(openssl rand -base64 16)

# ===== GENERATE SELF-SIGNED CERTS IF NEEDED ==================================
CERT_DIR="${CODE_SERVER_DATA}/.certs"
CERT_FILE="$CERT_DIR/code-server.crt"
KEY_FILE="$CERT_DIR/code-server.key"
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo -e "${RUN} Generating self-signed certificate for HTTPS..."
    sudo mkdir -p "$CERT_DIR"
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/CN=$(hostname)" >/dev/null 2>&1
    sudo chown 1000:1000 "$CERT_FILE" "$KEY_FILE"
    sudo chmod 600 "$CERT_FILE" "$KEY_FILE"
    echo -e "${OK} Self-signed certificate generated at $CERT_FILE and $KEY_FILE with permissions 600 and owned by coder (UID 1000)"
fi

# ===== CONFIG ================================================================
CODE_SERVER_NAME="code-server"
CODE_SERVER_DATA="/opt/code_server_data"
CODE_SERVER_PORT=9080

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

# ===== CHECK IF ANY CONTAINER IS USING THE TARGET PORT AND REMOVE IT =========
EXISTING_CONTAINER=$(sudo docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | grep ":${CODE_SERVER_PORT}->" | awk '{print $2}')
if [ -n "$EXISTING_CONTAINER" ]; then
    echo -e "${RUN} ${DOCKER} Stopping container using port ${CODE_SERVER_PORT}: $EXISTING_CONTAINER"
    sudo docker stop "$EXISTING_CONTAINER" || true
    echo -e "${RUN} ${DOCKER} Removing container using port ${CODE_SERVER_PORT}: $EXISTING_CONTAINER"
    sudo docker rm "$EXISTING_CONTAINER" || true
    echo -e "${OK} Container $EXISTING_CONTAINER using port ${CODE_SERVER_PORT} removed"
fi

# ===== REMOVE EXISTING CODE-SERVER BY NAME ===================================
if sudo docker ps -a --format '{{.Names}}' | grep -q "^${CODE_SERVER_NAME}$"; then
    echo -e "${RUN} ${DOCKER} Stopping existing code-server container"
    sudo docker stop "${CODE_SERVER_NAME}" || true
    echo -e "${RUN} ${DOCKER} Removing existing code-server container"
    sudo docker rm "${CODE_SERVER_NAME}" || true
    echo -e "${OK} Existing code-server removed"
fi

if [ -d "$CODE_SERVER_DATA" ]; then
    echo -e "${RUN} ${PORT} Using code-server data directory: $CODE_SERVER_DATA"
else
    echo -e "${RUN} ${PORT} Creating code-server data directory: $CODE_SERVER_DATA"
    sudo mkdir -p "$CODE_SERVER_DATA"
fi

# ===== FIX PERMISSIONS FOR CODER USER =======================================
sudo chown -R 1000:1000 "$CODE_SERVER_DATA"
sudo chmod -R 755 "$CODE_SERVER_DATA"
echo -e "${OK} Set ownership to UID 1000 and permissions to 755 on $CODE_SERVER_DATA"

# ===== DEPLOY CODE-SERVER ====================================================
echo -e "${RUN} ${DOCKER} Pulling latest code-server image"
sudo docker pull codercom/code-server:latest

echo -e "${RUN} ${DOCKER} Starting fresh code-server container"
sudo docker run -d \
    --name "${CODE_SERVER_NAME}" \
    --restart=always \
    -p ${CODE_SERVER_PORT}:8080 \
    -v "${CODE_SERVER_DATA}:/home/coder/Shared" \
    -v "$CERT_FILE:/home/coder/.certs/code-server.crt:ro" \
    -v "$KEY_FILE:/home/coder/.certs/code-server.key:ro" \
    -e PASSWORD="$PASSWORD" \
    codercom/code-server:latest \
    --cert /home/coder/.certs/code-server.crt --cert-key /home/coder/.certs/code-server.key

# ===== INSTALL DEV TOOLS IN CONTAINER =======================================
echo -e "${RUN} Installing Python, GCC, Git, CMake, Ninja in code-server container..."
sudo docker exec --user root "${CODE_SERVER_NAME}" bash -c "apt-get update && apt-get install -y python3 python3-pip python-is-python3 gcc g++ git cmake ninja-build"
echo -e "${OK} Python, GCC, Git, CMake, Ninja installed in code-server container (with 'python' symlink)"

# ===== SAVE PASSWORD INSIDE CONTAINER ========================================


# ===== GET HOSTNAME ==========================================================
HOSTNAME=$(hostname)

echo -e "${OK} code-server deployed successfully"
echo -e "${OK} Access it at: https://${HOSTNAME}:${CODE_SERVER_PORT}/ (self-signed certificate)"
echo -e "${OK} Username: coder"
echo -e "${OK} Password: $PASSWORD"
