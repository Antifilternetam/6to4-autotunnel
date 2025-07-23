#!/bin/bash

set -e

TUN_IF="t6t$(tr -dc a-z0-9 </dev/urandom | head -c 4)"
GRE_IF="gre0"

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m"

# Banner
banner() {
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}         Tunnela IPv6/IPv4 Tunnel         ${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo -e "📦 Github:    ${BLUE}https://github.com/Antifilternetam/6to4-autotunnel${NC}"
  echo -e "📣 Telegram:  ${CYAN}@antifilteram${NC}"
  echo -e "${CYAN}========================================${NC}\n"
}

# Convert IPv4 to 6to4
ipv4_to_6to4() {
  local ip=$1
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  printf "2002:%02x%02x:%02x%02x::1\n" "$o1" "$o2" "$o3" "$o4"
}

# Setup 6to4 Tunnel
setup_6to4() {
  read -p "Is this the 'iran' or 'kharej' server? (iran/kharej): " ROLE
  read -p "Enter the public IPv4 of the IRAN server: " IRAN_IPV4
  read -p "Enter the public IPv4 of the KHAREJ server: " KHAREJ_IPV4

  if [[ "$ROLE" == "iran" ]]; then
      MY_IPV4="$IRAN_IPV4"
      PEER_IPV4="$KHAREJ_IPV4"
  elif [[ "$ROLE" == "kharej" ]]; then
      MY_IPV4="$KHAREJ_IPV4"
      PEER_IPV4="$IRAN_IPV4"
  else
      echo -e "${RED}❌ Invalid role. Use 'iran' or 'kharej'.${NC}"
      return
  fi

  MY_IPV6=$(ipv4_to_6to4 "$MY_IPV4")
  PEER_IPV6=$(ipv4_to_6to4 "$PEER_IPV4")

  echo "$ROLE" > ~/.tunnela_role
  echo "$IRAN_IPV4" > ~/.tunnela_iran_ipv4

  echo -e "\n${BLUE}[+] Creating 6to4 tunnel: $TUN_IF...${NC}"
  sudo modprobe ipv6
  sudo ip tunnel del $TUN_IF 2>/dev/null || true
  sudo ip tunnel add $TUN_IF mode sit remote any local "$MY_IPV4" ttl 255
  sudo ip link set $TUN_IF up
  sudo ip -6 addr add "$MY_IPV6/16" dev $TUN_IF
  sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT

  echo -e "${GREEN}✅ 6to4 tunnel ready using $TUN_IF${NC}"
  echo -e "🌐 Your IPv6:  ${YELLOW}$MY_IPV6${NC}"
  echo -e "🌐 Peer IPv6:  ${YELLOW}$PEER_IPV6${NC}"
}

# Setup GRE Tunnel
setup_gre() {
  read -p "Is this the 'iran' or 'kharej' server? (iran/kharej): " ROLE
  read -p "Enter the public IPv4 of the IRAN server: " IRAN_IPV4
  read -p "Enter the public IPv4 of the KHAREJ server: " KHAREJ_IPV4

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
      echo -e "${RED}❌ Invalid role. Use 'iran' or 'kharej'.${NC}"
      return
  fi

  echo "$ROLE" > ~/.tunnela_role
  echo "$IRAN_IPV4" > ~/.tunnela_iran_ipv4

  echo -e "\n${BLUE}[+] Setting up GRE tunnel (IPv4 local)...${NC}"
  sudo modprobe ip_gre
  sudo ip tunnel del $GRE_IF 2>/dev/null || true
  sudo ip tunnel add $GRE_IF mode gre local "$MY_IPV4" remote "$PEER_IPV4" ttl 255
  sudo ip addr add "$MY_V4LOCAL/30" dev $GRE_IF
  sudo ip link set $GRE_IF up
  sudo iptables -C INPUT -p gre -j ACCEPT 2>/dev/null || sudo iptables -A INPUT -p gre -j ACCEPT

  echo -e "${GREEN}✅ GRE tunnel created.${NC}"
  echo -e "🔒 IPv4 Local: ${YELLOW}$MY_V4LOCAL${NC}"
  echo -e "🔒 IPv4 Peer:  ${YELLOW}$PEER_V4LOCAL${NC}"
}

# Show IPv6
show_ipv6() {
  echo -e "\n${CYAN}🛰️ Your active 6to4 IPv6 addresses:${NC}"
  ip -6 addr show | grep -oP 'inet6 2002:[0-9a-f:]+(?=/)' | awk '{print $2}' || echo -e "${RED}[!] No 6to4 IPv6 found${NC}"
}

# Remove tunnels
remove_all_tunnels() {
  echo -e "${YELLOW}Removing all 6to4 tunnels (starting with t6t) and GRE...${NC}"
  for iface in $(ip tunnel show | grep '^t6t' | awk '{print $1}'); do
    sudo ip tunnel del "$iface"
    echo -e "${GREEN}✔ Removed tunnel: $iface${NC}"
  done
  sudo ip tunnel del gre0 2>/dev/null && echo -e "${GREEN}✔ Removed tunnel: gre0${NC}"
}

# Setup Rathole
setup_rathole() {
  echo -e "\n${BLUE}[+] Rathole Tunnel Setup${NC}"
  ROLE=$(cat ~/.tunnela_role 2>/dev/null || echo "unknown")
  IRAN_IPV4=$(cat ~/.tunnela_iran_ipv4 2>/dev/null || echo "")

  if [[ "$ROLE" == "iran" ]]; then
    echo -e "\n${GREEN}📍 این سرور در موقعیت ایران قرار دارد.${NC}"
    echo -e "${YELLOW}📌 هنگام نصب رتهول، از شما پرسیده می‌شود آیا می‌خواهید از IPv6 استفاده کنید؟${NC}"
    echo -e "${CYAN}✅ لطفاً دقیقاً عبارت ${GREEN}y${CYAN} را وارد کنید و Enter بزنید تا تونل با آی‌پی نسخه ۶ ساخته شود.${NC}"
    echo -e "${GREEN}اگر آماده‌ای، Enter را بزن تا نصب رتهول آغاز شود...${NC}"
    read
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)

  elif [[ "$ROLE" == "kharej" && -n "$IRAN_IPV4" ]]; then
    IRAN_IPV6=$(ipv4_to_6to4 "$IRAN_IPV4")
    IRAN_V4LOCAL="192.168.250.1"
    echo -e "\n${GREEN}📍 This is the foreign server.${NC}"
    echo -e "🔹 Use one of the following to connect to the Iran server:"
    echo -e "🌐 IPv6: ${YELLOW}$IRAN_IPV6${NC}"
    echo -e "🔒 IPv4: ${YELLOW}$IRAN_V4LOCAL${NC}"
    echo -e "${CYAN}Copy and paste into Rathole when asked for the server address.${NC}"
    read -p "Press Enter to launch Rathole setup..."
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  else
    echo -e "${RED}[!] Please run the tunnel setup first.${NC}"
  fi
}

# Main Menu
while true; do
  banner
  echo -e "${YELLOW}Select an option:${NC}"
  echo " 1) Setup 6to4 Tunnel (IPv6)"
  echo " 2) Setup GRE Tunnel (IPv4 Local)"
  echo " 3) Show active 6to4 IPv6"
  echo " 4) Remove all tunnels"
  echo " 5) Setup Rathole Tunnel"
  echo " 0) Exit"
  echo -ne "\n${BLUE}Enter your choice: ${NC}"
  read CHOICE

  case $CHOICE in
    1) setup_6to4 ;;
    2) setup_gre ;;
    3) show_ipv6 ;;
    4) remove_all_tunnels ;;
    5) setup_rathole ;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option.${NC}" ;;
  esac

  echo -e "\n${CYAN}Press Enter to return to menu...${NC}"
  read
done
