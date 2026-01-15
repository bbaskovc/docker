#!/usr/bin/env bash
set -e

# ===== CONFIG ================================================================
WG_NAME="wireguard"
WG_DATA="/opt/wireguard"
WG_PORT=51820
WG_SUBNET="10.13.13.0"
WG_PEERS="phone,laptop"
LAN_SUBNET="192.168.1.0/24"   # CHANGE if your LAN is different
TZ="Europe/Ljubljana"

# ===== COLORS & ICONS ========================================================
RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
OK="${GREEN}✔${RESET}"
RUN="${CYAN}➜${RESET}"
DOCKER="🐳"
NET="🌐"

# ===== CHECK ROOT ============================================================
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠ Please run as root (sudo)${RESET}"
    exit 1
fi

# ===== ENABLE IP FORWARDING ==================================================
echo -e "${RUN} ${NET} Enabling IPv4 forwarding"
sysctl -w net.ipv4.ip_forward=1 >/dev/null
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl --system >/dev/null
echo -e "${OK} IPv4 forwarding enabled"

# ===== SET NAT (MASQUERADE) ==================================================
IFACE=$(ip route | awk '/default/ {print $5}')
echo -e "${RUN} ${NET} Enabling NAT on interface ${IFACE}"
iptables -t nat -C POSTROUTING -o "$IFACE" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
echo -e "${OK} NAT enabled"

# ===== CLEAN EXISTING CONTAINER =============================================
if docker ps -a --format '{{.Names}}' | grep -q "^${WG_NAME}$"; then
    echo -e "${RUN} ${DOCKER} Removing existing WireGuard container"
    docker stop "${WG_NAME}" || true
    docker rm "${WG_NAME}" || true
    echo -e "${OK} Existing WireGuard removed"
fi

# ===== CREATE DATA DIR =======================================================
if [ ! -d "$WG_DATA" ]; then
    echo -e "${RUN} Creating WireGuard data directory: $WG_DATA"
    mkdir -p "$WG_DATA"
fi

# ===== DEPLOY WIREGUARD ======================================================
echo -e "${RUN} ${DOCKER} Pulling WireGuard image"
docker pull lscr.io/linuxserver/wireguard:latest

echo -e "${RUN} ${DOCKER} Starting WireGuard container"
docker run -d \
    --name "${WG_NAME}" \
    --restart=unless-stopped \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_MODULE \
    -p ${WG_PORT}:51820/udp \
    -v "${WG_DATA}:/config" \
    -v /lib/modules:/lib/modules:ro \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ="${TZ}" \
    -e SERVERPORT=${WG_PORT} \
    -e PEERS="${WG_PEERS}" \
    -e INTERNAL_SUBNET="${WG_SUBNET}" \
    -e ALLOWEDIPS="0.0.0.0/0, ::/0, ${LAN_SUBNET}" \
    -e PEERDNS="auto" \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    lscr.io/linuxserver/wireguard:latest

# ===== DONE ==================================================================
HOSTNAME=$(hostname)

echo -e "${OK} WireGuard deployed successfully"
echo -e "${OK} Public port: UDP ${WG_PORT}"
echo -e "${OK} Full tunnel enabled (ALL internet via VPN)"
echo -e "${OK} LAN access enabled: ${LAN_SUBNET}"
echo -e "${OK} Client configs are in: ${WG_DATA}/peer_*"
echo -e "${OK} Connect and your internet + LAN will go through ${HOSTNAME}"
