#!/bin/bash

set -e

TUN_IF="t6t$(tr -dc a-z0-9 </dev/urandom | head -c 4)"
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m"

banner() {
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}         تانلا تانل - Tunnela Tunnel        ${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo -e "📦 Github:    ${BLUE}https://github.com/Antifilternetam/6to4-tunnela${NC}"
  echo -e "📣 Telegram:  ${CYAN}@tunnela${NC}"
  echo -e "${CYAN}========================================${NC}\n"
}

ipv4_to_6to4() {
  local ip=$1
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  printf "2002:%02x%02x:%02x%02x::1\n" "$o1" "$o2" "$o3" "$o4"
}

setup_tunnel() {
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

  echo "$ROLE" > ~/.6to4_role
  echo "$IRAN_IPV4" > ~/.6to4_iran_ipv4

  echo -e "${BLUE}[+] Creating 6to4 IPv6 tunnel: $TUN_IF...${NC}"
  sudo modprobe ipv6
  sudo ip tunnel add "$TUN_IF" mode sit remote any local "$MY_IPV4" ttl 255 || true
  sudo ip link set "$TUN_IF" up
  sudo ip -6 addr add "$MY_IPV6/16" dev "$TUN_IF" || true
  sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT

  echo -e "${GREEN}✅ Tunnel created: ${YELLOW}$TUN_IF${NC}"
  echo -e "🌐 Your IPv6:  ${YELLOW}$MY_IPV6${NC}"
  echo -e "🌐 Peer IPv6:  ${YELLOW}$PEER_IPV6${NC}"
  echo -e "🧪 Test with: ${CYAN}ping6 $PEER_IPV6${NC}"
}

show_ipv6_list() {
  echo -e "\n${CYAN}🛰️ Active Tunnela IPv6 addresses:${NC}"
  ip -6 addr | grep -oP '2002:[0-9a-f:]+(?=/)' | sort | uniq
}

remove_all_tunnels() {
  echo -e "${YELLOW}Removing all Tunnela tunnels...${NC}"
  for tun in $(ip tunnel show | grep '^t6t' | awk '{print $1}'); do
    sudo ip tunnel del "$tun" 2>/dev/null
    echo -e "${GREEN}✔ Removed tunnel: $tun${NC}"
  done
  sudo ip6tables -D INPUT -p icmpv6 -j ACCEPT 2>/dev/null
  rm -f ~/.6to4_role ~/.6to4_iran_ipv4
}

setup_rathole() {
  echo -e "\n${BLUE}[+] راه‌اندازی رتهول...${NC}"
  ROLE=$(cat ~/.6to4_role 2>/dev/null || echo "")
  IRAN_IPV4=$(cat ~/.6to4_iran_ipv4 2>/dev/null || echo "")

  if [[ "$ROLE" == "iran" ]]; then
    echo -e "${CYAN}✅ وقتی از شما پرسیده شد از IPv6 استفاده می‌کنید، گزینه 'y' را وارد کنید.${NC}"
    read -p "${GREEN}اگر آماده‌اید، Enter بزنید تا رتهول اجرا شود...${NC}"
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  elif [[ "$ROLE" == "kharej" ]]; then
    IRAN_IPV6=$(ipv4_to_6to4 "$IRAN_IPV4")
    echo -e "\n${GREEN}🛰️ IPv6 برای اتصال به سرور ایران:${NC} ${YELLOW}$IRAN_IPV6${NC}"
    echo -e "${CYAN}✅ در مرحله وارد کردن آدرس سرور، این IPv6 را وارد نمایید.${NC}"
    read -p "ادامه با Enter..." _
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  else
    echo -e "${RED}[!] نقش یا IP سرور ایران پیدا نشد. اول تونل بسازید.${NC}"
  fi
}

# Menu
while true; do
  banner
  echo -e "${YELLOW}Select an option:${NC}"
  echo " 1) Setup 6to4 Tunnel"
  echo " 2) Show IPv6 Addresses"
  echo " 3) Remove All Tunnels"
  echo " 4) Setup Rathole Tunnel"
  echo " 0) Exit"
  echo -ne "\n${BLUE}Enter your choice: ${NC}"
  read CHOICE

  case $CHOICE in
    1) setup_tunnel ;;
    2) show_ipv6_list ;;
    3) remove_all_tunnels ;;
    4) setup_rathole ;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option. Try again.${NC}" ;;
  esac

  echo -e "\n${CYAN}برای بازگشت به منو Enter بزنید...${NC}"
  read
done
