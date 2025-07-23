#!/bin/bash
set -e

# رنگ‌ها
RED="\033[0;31m"; GREEN="\033[0;32m"; BLUE="\033[0;34m"
YELLOW="\033[1;33m"; CYAN="\033[0;36m"; NC="\033[0m"

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
    MY_IPV4="$IRAN_IPV4"; PEER_IPV4="$KHAREJ_IPV4"
  elif [[ "$ROLE" == "kharej" ]]; then
    MY_IPV4="$KHAREJ_IPV4"; PEER_IPV4="$IRAN_IPV4"
  else
    echo -e "${RED}❌ Invalid role. Use 'iran' or 'kharej'.${NC}"; return
  fi

  MY_IPV6=$(ipv4_to_6to4 "$MY_IPV4")
  PEER_IPV6=$(ipv4_to_6to4 "$PEER_IPV4")
  TUN_IF="t6t$(tr -dc a-z0-9 </dev/urandom | head -c 5)"

  echo -e "${BLUE}[+] Creating 6to4 IPv6 tunnel: $TUN_IF...${NC}"
  sudo modprobe ipv6
  sudo ip tunnel add "$TUN_IF" mode sit remote any local "$MY_IPV4" ttl 255
  sudo ip link set "$TUN_IF" up
  sudo ip -6 addr add "$MY_IPV6/16" dev "$TUN_IF"
  sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT

  echo "$ROLE" > ~/.6to4_role
  echo "$IRAN_IPV4" > ~/.6to4_iran_ipv4
  echo "$TUN_IF" >> ~/.6to4_tunnels

  echo -e "${GREEN}✅ Tunnel ready on $TUN_IF${NC}"
  echo -e "🌐 Your IPv6:  ${YELLOW}$MY_IPV6${NC}"
  echo -e "🌐 Peer IPv6:  ${YELLOW}$PEER_IPV6${NC}"
  echo -e "🧪 Test:      ${CYAN}ping6 $PEER_IPV6${NC}"
}

show_ipv6() {
  echo -e "\n${CYAN}🛰️ Active 6to4 IPv6 tunnels:${NC}"
  ip -6 addr show | grep -oP 'inet6 2002:[0-9a-f:]+' | awk '{print $2}' || echo -e "${RED}[!] No tunnel found${NC}"
}

remove_all_tunnels() {
  echo -e "${YELLOW}🧹 Removing all t6t tunnels...${NC}"
  for iface in $(ip tunnel show | grep '^t6t' | awk '{print $1}'); do
    sudo ip tunnel del "$iface" 2>/dev/null && echo -e "${GREEN}✔ Removed: $iface${NC}"
  done
  sudo ip6tables -D INPUT -p icmpv6 -j ACCEPT 2>/dev/null
  rm -f ~/.6to4_role ~/.6to4_iran_ipv4 ~/.6to4_tunnels
}

setup_rathole() {
  echo -e "${BLUE}[+] راه‌اندازی رتهول...${NC}"
  ROLE=$(cat ~/.6to4_role 2>/dev/null || echo "unknown")
  IRAN_IPV4=$(cat ~/.6to4_iran_ipv4 2>/dev/null || echo "")

  if [[ "$ROLE" == "iran" ]]; then
    echo -e "${GREEN}شما در سرور ایران هستید.${NC}"
    echo -e "${YELLOW}در مرحله نصب رتهول، زمانی که پرسید آیا IPv6 هم استفاده شود، گزینه 'y' را وارد کنید.${NC}"
    echo -e "\n${GREEN}برای ادامه Enter بزن...${NC}"
    read
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  elif [[ "$ROLE" == "kharej" && -n "$IRAN_IPV4" ]]; then
    IRAN_IPV6=$(ipv4_to_6to4 "$IRAN_IPV4")
    echo -e "${GREEN}🛰️ IPv6 ایران برای اتصال:${NC} ${YELLOW}$IRAN_IPV6${NC}"
    echo -e "${CYAN}برای نصب رتهول Enter بزن...${NC}"; read
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  else
    echo -e "${RED}ابتدا تونل را راه‌اندازی کن.${NC}"
  fi
}

# منوی اصلی
while true; do
  banner
  echo -e "${YELLOW}Choose an option:${NC}"
  echo " 1) Setup 6to4 Tunnel"
  echo " 2) Show IPv6 Address"
  echo " 3) Remove All Tunnels"
  echo " 4) Setup Rathole Tunnel"
  echo " 0) Exit"
  echo -ne "\n${BLUE}Enter your choice: ${NC}"; read CHOICE

  case $CHOICE in
    1) setup_tunnel ;;
    2) show_ipv6 ;;
    3) remove_all_tunnels ;;
    4) setup_rathole ;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option. Try again.${NC}" ;;
  esac
  echo -e "\n${CYAN}برای بازگشت به منو Enter بزن...${NC}"; read
done
