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
  echo -e "${GREEN}          تانلا تانل (Tunnela)           ${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo -e "📦 Github:    ${BLUE}https://github.com/Antifilternetam/6to4-autotunnel${NC}"
  echo -e "📣 Telegram:  ${CYAN}@antifilteram${NC}"
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

  echo -e "\n${BLUE}[+] Creating 6to4 IPv6 tunnel: $TUN_IF...${NC}"
  sudo modprobe ipv6
  sudo ip tunnel del $TUN_IF 2>/dev/null || true
  sudo ip tunnel add $TUN_IF mode sit remote any local "$MY_IPV4" ttl 255
  sudo ip link set $TUN_IF up
  sudo ip -6 addr add "$MY_IPV6/16" dev $TUN_IF
  sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT

  echo -e "${GREEN}✅ 6to4 tunnel ready using $TUN_IF${NC}"
  echo -e "🌐 Your IPv6:  ${YELLOW}$MY_IPV6${NC}"
  echo -e "🌐 Peer IPv6:  ${YELLOW}$PEER_IPV6${NC}"

  echo "$ROLE" > ~/.6to4_role
  echo "$IRAN_IPV4" > ~/.6to4_iran_ipv4
}

setup_gre() {
  echo -e "\n${BLUE}[+] Setting up GRE tunnel (IPv4 local)...${NC}"
  ROLE=$(cat ~/.6to4_role 2>/dev/null || echo "unknown")
  IRAN_IPV4=$(cat ~/.6to4_iran_ipv4 2>/dev/null || echo "")

  if [[ "$ROLE" == "iran" ]]; then
      MY_IPV4="$IRAN_IPV4"
      read -p "Enter KHAREJ IPv4 again: " KHAREJ_IPV4
      PEER_IPV4="$KHAREJ_IPV4"
      MY_V4LOCAL="192.168.250.1"
      PEER_V4LOCAL="192.168.250.2"
  elif [[ "$ROLE" == "kharej" ]]; then
      read -p "Enter KHAREJ public IPv4 again: " KHAREJ_IPV4
      MY_IPV4="$KHAREJ_IPV4"
      PEER_IPV4="$IRAN_IPV4"
      MY_V4LOCAL="192.168.250.2"
      PEER_V4LOCAL="192.168.250.1"
  else
      echo -e "${RED}❌ Role not found. Run IPv6 setup first.${NC}"
      return
  fi

  sudo modprobe ip_gre || true
  sudo ip tunnel del gre0 2>/dev/null || true
  sudo ip tunnel add gre0 mode gre local "$MY_IPV4" remote "$PEER_IPV4" ttl 255
  sudo ip addr add "$MY_V4LOCAL/30" dev gre0
  sudo ip link set gre0 up
  sudo iptables -C INPUT -p gre -j ACCEPT 2>/dev/null || sudo iptables -A INPUT -p gre -j ACCEPT

  echo -e "${GREEN}✔ GRE Tunnel created using gre0${NC}"
  echo -e "🔐 Your IPv4 Local: ${YELLOW}$MY_V4LOCAL${NC}"
  echo -e "🔐 Peer IPv4 Local: ${YELLOW}$PEER_V4LOCAL${NC}"
}

setup_rathole() {
  echo -e "\n${BLUE}[+] راه‌اندازی رتهول...${NC}"
  ROLE=$(cat ~/.6to4_role 2>/dev/null || echo "unknown")
  IRAN_IPV4=$(cat ~/.6to4_iran_ipv4 2>/dev/null || echo "")
  IRAN_IPV6=$(ipv4_to_6to4 "$IRAN_IPV4")
  IRAN_V4LOCAL="192.168.250.1"

  if [[ "$ROLE" == "iran" ]]; then
    echo -e "${CYAN}در مرحله نصب رتهول، وقتی از شما سوال شد 'استفاده از IPv6؟' حتماً yes بزنید.${NC}"
    read -p "برای ادامه Enter بزن..." _
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  elif [[ "$ROLE" == "kharej" ]]; then
    echo -e "\n${GREEN}🌐 آدرس‌های سرور ایران برای اتصال:${NC}"
    echo -e "🔹 IPv6: ${YELLOW}$IRAN_IPV6${NC}"
    echo -e "🔹 IPv4 Local: ${YELLOW}$IRAN_V4LOCAL${NC}"
    echo -e "${CYAN}هرکدام را مایل بودید برای اتصال استفاده کنید.${NC}"
    read -p "برای ادامه نصب رتهول Enter بزن..." _
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  else
    echo -e "${RED}نقش سرور مشخص نیست. ابتدا تونل را بسازید.${NC}"
  fi
}

while true; do
  banner
  echo -e "${YELLOW}Choose an option:${NC}"
  echo " 1) Setup 6to4 Tunnel (IPv6)"
  echo " 2) Setup GRE Tunnel (IPv4 Local)"
  echo " 3) Install Rathole Tunnel"
  echo " 0) Exit"
  echo -ne "\n${BLUE}Enter your choice: ${NC}"
  read CHOICE

  case $CHOICE in
    1) setup_tunnel ;;
    2) setup_gre ;;
    3) setup_rathole ;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option. Try again.${NC}" ;;
  esac

  echo -e "\n${CYAN}برای بازگشت به منو Enter بزنید...${NC}"
  read
done
---
