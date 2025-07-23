#!/bin/bash
set -e

RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
NC="\033[0m"

REGISTRY_FILE="$HOME/.tunnela_registry"

banner() {
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}        Tunnela Tunnel Manager           ${NC}"
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

generate_iface_name() {
  for i in $(seq 1 99); do
    IFNAME="t6t$i"
    if ! ip tunnel show "$IFNAME" &>/dev/null; then
      echo "$IFNAME"
      return
    fi
  done
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
  IFACE=$(generate_iface_name)

  echo -e "\n${BLUE}[+] Creating 6to4 IPv6 tunnel: $IFACE...${NC}"
  sudo modprobe ipv6
  sudo ip tunnel add "$IFACE" mode sit remote any local "$MY_IPV4" ttl 255
  sudo ip link set "$IFACE" up
  sudo ip -6 addr add "$MY_IPV6/16" dev "$IFACE"
  sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT

  echo "$IFACE|$ROLE|$MY_IPV6|$PEER_IPV6|$PEER_IPV4" >> "$REGISTRY_FILE"

  echo -e "${GREEN}✅ Tunnel created: $IFACE${NC}"
  echo -e "🌐 IPv6 Local:  ${YELLOW}$MY_IPV6${NC}"
  echo -e "🌐 Peer IPv6:   ${YELLOW}$PEER_IPV6${NC}"

  echo "$ROLE" > ~/.tunnela_role
  echo "$IRAN_IPV4" > ~/.tunnela_iran_ipv4
}

show_tunnels() {
  echo -e "\n${CYAN}🛰️ Active Tunnels:${NC}"
  [[ ! -f "$REGISTRY_FILE" ]] && echo -e "${RED}[!] No tunnel registry found.${NC}" && return

  while IFS='|' read -r iface role myv6 peerv6 peer4; do
    echo -e "\n🔹 Tunnel: $iface"
    echo -e "   Role: $role"
    echo -e "   IPv6 Local: $myv6"
    echo -e "   Peer IPv6: $peerv6"
    echo -e "   Peer IPv4: $peer4"
  done < "$REGISTRY_FILE"
}

remove_all_tunnels() {
  echo -e "${YELLOW}Removing all 6to4 tunnels (t6t)...${NC}"
  for iface in $(ip tunnel show | grep '^t6t' | awk '{print $1}'); do
    sudo ip tunnel del "$iface"
    echo -e "${GREEN}✔ Removed: $iface${NC}"
  done
  > "$REGISTRY_FILE"
}

setup_rathole() {
  ROLE=$(cat ~/.tunnela_role 2>/dev/null || echo "")
  IRAN_IPV4=$(cat ~/.tunnela_iran_ipv4 2>/dev/null || echo "")

  if [[ "$ROLE" == "iran" ]]; then
    echo -e "${CYAN}📘 شما در سرور ایران هستید. در هنگام نصب رتهول وقتی پرسید IPv6 استفاده شود؟ بنویسید: y${NC}"
    echo -e "${YELLOW}برای ادامه Enter بزنید...${NC}"
    read
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  elif [[ "$ROLE" == "kharej" && -n "$IRAN_IPV4" ]]; then
    IRAN_IPV6=$(ipv4_to_6to4 "$IRAN_IPV4")
    echo -e "${CYAN}📡 آدرس IPv6 ایران جهت اتصال:${NC} ${YELLOW}$IRAN_IPV6${NC}"
    echo -e "${YELLOW}در مرحله اتصال، این آدرس را وارد نمایید. Enter بزن برای نصب رتهول...${NC}"
    read
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  else
    echo -e "${RED}[!] ابتدا باید تونل 6to4 را بسازید.${NC}"
  fi
}

while true; do
  banner
  echo -e "${YELLOW}Select an option:${NC}"
  echo " 1) Setup 6to4 Tunnel"
  echo " 2) Show All Tunnels"
  echo " 3) Remove All Tunnels"
  echo " 4) Setup Rathole Tunnel"
  echo " 0) Exit"
  echo -ne "\n${BLUE}Enter your choice: ${NC}"
  read CHOICE
  case "$CHOICE" in
    1) setup_tunnel ;;
    2) show_tunnels ;;
    3) remove_all_tunnels ;;
    4) setup_rathole ;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid choice.${NC}" ;;
  esac
  echo -e "\n${CYAN}Press Enter to return to menu...${NC}"
  read
done
