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

# ===== NEXTCLOUD CONFIG ======================================================
NC_NAME="nextcloud"
NC_PORT=9060
NC_DATA="/opt/nextcloud_data"
NC_DB_DATA="/opt/nextcloud_db_data"

# ==== NEXTCLOUD DB CREDENTIALS ==============================================
DB_NAME="nextcloud"
DB_USER="nextcloud"
DB_PASSWORD="o2nuHpR0AAbtqsN7QoMD"

# ===== NEXTCLOUD DEPLOYMENT ==================================================
if sudo docker ps -a --format '{{.Names}}' | grep -q "^nextcloud-db$"; then
    echo -e "${RUN} ${DOCKER} Stopping and removing existing nextcloud-db container..."
    sudo docker stop nextcloud-db || true
    sudo docker rm nextcloud-db || true
    echo -e "${OK} Existing nextcloud-db container removed"
fi

if sudo docker ps -a --format '{{.Names}}' | grep -q "^nextcloud$"; then
    echo -e "${RUN} ${DOCKER} Stopping and removing existing nextcloud container..."
    sudo docker stop nextcloud || true
    sudo docker rm nextcloud || true
    echo -e "${OK} Existing nextcloud container removed"
fi
echo -e "${RUN} ${DOCKER} Setting up Nextcloud..."
sudo mkdir -p "$NC_DATA" "$NC_DB_DATA"
sudo chown -R 1000:1000 "$NC_DATA" "$NC_DB_DATA"
sudo chmod -R 755 "$NC_DATA" "$NC_DB_DATA"
CONFIG_DIR="$NC_DATA/config"
if [ ! -d "$CONFIG_DIR" ]; then
    sudo mkdir -p "$CONFIG_DIR"
fi
sudo chown -R 33:33 "$CONFIG_DIR"
sudo chmod -R 755 "$CONFIG_DIR"
echo -e "${OK} Set ownership to www-data (33:33) and permissions to 755 on $CONFIG_DIR"

# ===== FIX PERMISSIONS FOR DATA DIRECTORY ====================================
sudo chown -R 33:33 "$NC_DATA"
sudo chmod -R 755 "$NC_DATA"
echo -e "${OK} Set ownership to www-data (33:33) and permissions to 755 on $NC_DATA"
sudo docker pull nextcloud:latest
sudo docker pull mariadb:latest

echo -e "${RUN} ${DOCKER} Starting MariaDB for Nextcloud..."
sudo docker run -d \
    --name nextcloud-db \
    --restart=always \
    -e MYSQL_ROOT_PASSWORD=$DB_PASSWORD \
    -e MYSQL_DATABASE=$DB_NAME \
    -e MYSQL_USER=$DB_USER \
    -e MYSQL_PASSWORD=$DB_PASSWORD \
    -v "$NC_DB_DATA:/var/lib/mysql" \
    mariadb:latest

sleep 10 # Wait for DB to initialize

echo -e "${RUN} ${DOCKER} Starting Nextcloud container..."
sudo docker run -d \
    --name "$NC_NAME" \
    --restart=always \
    -p ${NC_PORT}:80 \
    -v "$NC_DATA:/var/www/html" \
    --link nextcloud-db:db \
    -e MYSQL_HOST=db \
    -e MYSQL_DATABASE=$DB_NAME \
    -e MYSQL_USER=$DB_USER \
    -e MYSQL_PASSWORD=$DB_PASSWORD \
    nextcloud:latest

echo -e "${OK} Nextcloud deployed. Access at: http://$(hostname):${NC_PORT}/"
