#!/bin/bash

set -e

TUN_IF="sit0"
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m"

banner() {
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}     آنتی فیلترنتم - AntiFilterNetam     ${NC}"
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

  echo -e "\n${BLUE}[+] Setting up 6to4 tunnel on $TUN_IF...${NC}"
  sudo modprobe ipv6
  sudo ip tunnel add $TUN_IF mode sit remote any local "$MY_IPV4" ttl 255 || true
  sudo ip link set $TUN_IF up
  sudo ip -6 addr add "$MY_IPV6/16" dev $TUN_IF
  sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT

  echo -e "${GREEN}✅ 6to4 tunnel ready${NC}"
  echo -e "🌐 Your IPv6:  ${YELLOW}$MY_IPV6${NC}"
  echo -e "🌐 Peer IPv6:  ${YELLOW}$PEER_IPV6${NC}"
  echo -e "🧪 Test:      ${CYAN}ping6 $PEER_IPV6${NC}"
}

show_ipv6() {
  echo -e "\n${CYAN}Your current IPv6 on $TUN_IF:${NC}"
  ip -6 addr show dev $TUN_IF | grep inet6 | awk '{print $2}' || echo -e "${RED}[!] No IPv6 found${NC}"
}

remove_tunnel() {
  echo -e "${YELLOW}Removing tunnel $TUN_IF...${NC}"
  sudo ip tunnel del $TUN_IF 2>/dev/null || echo "Already removed."
  echo -e "${GREEN}✅ Tunnel removed.${NC}"
}

while true; do
  banner
  echo -e "${YELLOW}Choose an option:${NC}"
  echo " 1) Setup 6to4 Tunnel"
  echo " 2) Show IPv6 Address"
  echo " 3) Remove Tunnel"
  echo " 0) Exit"
  echo -ne "\n${BLUE}Enter your choice: ${NC}"
  read CHOICE

  case $CHOICE in
    1) setup_tunnel ;;
    2) show_ipv6 ;;
    3) remove_tunnel ;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option. Try again.${NC}" ;;
  esac
  echo -e "\n${CYAN}Press Enter to return to menu...${NC}"
  read
done
