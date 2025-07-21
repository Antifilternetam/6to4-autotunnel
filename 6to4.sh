#!/bin/bash

# -------------------------
# Tunnela Full Installer (IPv6 + IPv4 Tunnel + Rathole)
# -------------------------
# By: Antifilternetam
# Description: Creates both a 6to4 IPv6 tunnel, a local IPv4 GRE tunnel, and runs Rathole installer with guide

set -e

# Colors
GREEN="\e[32m"; RED="\e[31m"; CYAN="\e[36m"; RESET="\e[0m"

echo -e "${CYAN}⚙️  Tunnela Dual Stack Tunnel + Rathole Installer${RESET}"

# Get role
read -rp "Is this the 'iran' or 'kharej' server? (iran/kharej): " ROLE
read -rp "Enter the public IPv4 of the IRAN server: " IRAN_IPV4
read -rp "Enter the public IPv4 of the KHAREJ server: " KHAREJ_IPV4

if [[ "$ROLE" == "iran" ]]; then
    MY_IPV4="$IRAN_IPV4"
    PEER_IPV4="$KHAREJ_IPV4"
    MY_V4LOCAL="192.168.250.1"
    PEER_V4LOCAL="192.168.250.2"
elif [[ "$ROLE" == "kharej" ]]; then
    MY_IPV4="$KHAREJ_IPV4"
    PEER_IPV4="$IRAN_IPV4"
    MY_V4LOCAL="192.168.250.2"
    PEER_V4LOCAL="192.168.250.1"
else
    echo -e "${RED}❌ Invalid role. Use 'iran' or 'kharej'.${RESET}"
    exit 1
fi

# IPv4 → IPv6 6to4 conversion
ipv4_to_6to4() {
    local ip=$1
    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
    printf "2002:%02x%02x:%02x%02x::1" "$o1" "$o2" "$o3" "$o4"
}

MY_IPV6=$(ipv4_to_6to4 "$MY_IPV4")
PEER_IPV6=$(ipv4_to_6to4 "$PEER_IPV4")

# IPv6 Tunnel Setup
TUN_IF="sit0"
echo -e "${GREEN}[+] Setting up 6to4 IPv6 tunnel on $TUN_IF...${RESET}"
sudo modprobe ipv6 || true
sudo ip tunnel del $TUN_IF 2>/dev/null || true
sudo ip tunnel add $TUN_IF mode sit remote any local "$MY_IPV4" ttl 255
sudo ip link set $TUN_IF up
sudo ip -6 addr add "$MY_IPV6/16" dev $TUN_IF

# IPv4 GRE Tunnel Setup
GRE_IF="gre0"
echo -e "${GREEN}[+] Setting up local IPv4 GRE tunnel on $GRE_IF...${RESET}"
sudo modprobe ip_gre || true
sudo ip tunnel del $GRE_IF 2>/dev/null || true
sudo ip tunnel add $GRE_IF mode gre local "$MY_IPV4" remote "$PEER_IPV4" ttl 255
sudo ip addr add "$MY_V4LOCAL/30" dev $GRE_IF
sudo ip link set $GRE_IF up

# Enable ICMPv6 and IPv4 forwarding
sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT
sudo iptables -C INPUT -p gre -j ACCEPT 2>/dev/null || sudo iptables -A INPUT -p gre -j ACCEPT

# Tunnel summary
echo -e "\n${CYAN}✅ Tunnel Configuration Completed:${RESET}"
echo -e "🌐 IPv6 Local:  ${GREEN}$MY_IPV6${RESET}"
echo -e "🌐 IPv6 Peer:   ${PEER_IPV6}"
echo -e "🔒 IPv4 Local:  ${GREEN}$MY_V4LOCAL${RESET}"
echo -e "🔒 IPv4 Peer:   ${PEER_V4LOCAL}"

echo -e "\n🧪 You can test connectivity with:"
echo -e "  ping6 ${PEER_IPV6}"
echo -e "  ping ${PEER_V4LOCAL}"

echo -e "\n📢 در سرور خارج می‌توانید برای برقراری ارتباط با سرور ایران، از هرکدام از آدرس‌های زیر استفاده کنید:"
echo -e "  🔹 IPv6 سرور ایران: ${GREEN}${PEER_IPV6}${RESET}"
echo -e "  🔹 IPv4 لوکال سرور ایران: ${GREEN}${PEER_V4LOCAL}${RESET}"
echo -e "✳️ بستگی به ابزار و ترجیح شما دارد، از هرکدام می‌توانید استفاده کنید."

echo -e "\n🧠 نکته برای نصب Rathole:"
if [[ "$ROLE" == "iran" ]]; then
    echo -e "🔧 لطفاً هنگام نصب رتهول اگر پرسیده شد که آیا از آی‌پی ورژن ۶ استفاده می‌کنید، گزینه 'y' را انتخاب کنید."
else
    echo -e "🔗 در سرور خارج، برای برقراری ارتباط با ایران، یکی از این آدرس‌ها را هنگام نصب رتهول وارد کنید:"
    echo -e "   🔹 IPv6 ایران: ${GREEN}${PEER_IPV6}${RESET}"
    echo -e "   🔹 IPv4 لوکال ایران: ${GREEN}${PEER_V4LOCAL}${RESET}"
fi

echo -e "\nاگر آماده‌اید برای نصب رتهول، 'yes' را تایپ کرده و Enter بزنید."
read -rp "آیا می‌خواهید نصب رتهول آغاز شود؟ (yes/no): " INSTALL_RATHOLE
if [[ "$INSTALL_RATHOLE" == "yes" ]]; then
    echo -e "\n${GREEN}📦 نصب رتهول آغاز شد...${RESET}"
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
else
    echo -e "${CYAN}🚫 نصب رتهول لغو شد. شما می‌توانید بعداً به صورت دستی نصب کنید.${RESET}"
fi

exit 0
