#!/bin/bash

set -e

TUN_IF="t6t$(tr -dc a-z0-9 </dev/urandom | head -c 4)"
GRE_IF="gre$(tr -dc a-z0-9 </dev/urandom | head -c 4)"

RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m"

banner() {
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}        Tunnela - Dual Tunnel Tool       ${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo -e "📦 Github:    ${BLUE}https://github.com/Antifilternetam/6to4-tunnela${NC}"
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

  MY_IPV6=$(ipv4_to_6to4 "$MY_IPV4")
  PEER_IPV6=$(ipv4_to_6to4 "$PEER_IPV4")

  echo -e "\n${BLUE}[+] Creating 6to4 IPv6 tunnel: $TUN_IF...${NC}"
  sudo modprobe ipv6
  sudo ip tunnel del $TUN_IF 2>/dev/null || true
  sudo ip tunnel add $TUN_IF mode sit remote any local "$MY_IPV4" ttl 255
  sudo ip link set $TUN_IF up
  sudo ip -6 addr add "$MY_IPV6/16" dev $TUN_IF

  echo -e "${BLUE}[+] Creating GRE IPv4 tunnel: $GRE_IF...${NC}"
  sudo modprobe ip_gre || true
  sudo ip tunnel del $GRE_IF 2>/dev/null || true
  sudo ip tunnel add $GRE_IF mode gre local "$MY_IPV4" remote "$PEER_IPV4" ttl 255
  sudo ip addr add "$MY_V4LOCAL/30" dev $GRE_IF
  sudo ip link set $GRE_IF up

  sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT
  sudo iptables -C INPUT -p gre -j ACCEPT 2>/dev/null || sudo iptables -A INPUT -p gre -j ACCEPT

  echo -e "\n${CYAN}✅ Tunnel Configuration Completed:${NC}"
  echo -e "🌐 IPv6 Local:  ${GREEN}$MY_IPV6${NC}"
  echo -e "🌐 IPv6 Peer:   ${PEER_IPV6}"
  echo -e "🔒 IPv4 Local:  ${GREEN}$MY_V4LOCAL${NC}"
  echo -e "🔒 IPv4 Peer:   ${PEER_V4LOCAL}"

  echo -e "\n🧠 نکته برای نصب Rathole:"
  if [[ "$ROLE" == "iran" ]]; then
    echo -e "🔧 لطفاً هنگام نصب رتهول اگر پرسیده شد که آیا از آی‌پی ورژن ۶ استفاده می‌کنید، گزینه 'y' را انتخاب کنید."
  else
    echo -e "🔗 در سرور خارج، برای برقراری ارتباط با ایران، برای اتصال به سرور از این آدرس‌ها استفاده کنید:"
    echo -e "   🔹 IPv6 ایران: ${GREEN}${PEER_IPV6}${NC}"
    echo -e "   🔹 IPv4 لوکال ایران: ${GREEN}${PEER_V4LOCAL}${NC}"
  fi

  echo "$ROLE" > ~/.tunnela_role
  echo "$IRAN_IPV4" > ~/.tunnela_iran_ipv4
}

show_ipv6() {
  echo -e "\n${CYAN}🛰️ Your active 6to4 IPv6 addresses:${NC}"
  ip -6 addr show | grep -oP 'inet6 2002:[0-9a-f:]+' | awk '{print $2}' || echo -e "${RED}[!] No 6to4 IPv6 found${NC}"
}

remove_all_tunnels() {
  echo -e "${YELLOW}Removing all tunnels starting with t6t or gre...${NC}"
  for iface in $(ip tunnel show | awk '{print $1}' | grep -E '^t6t|^gre'); do
    sudo ip tunnel del "$iface"
    echo -e "${GREEN}✔ Removed tunnel: $iface${NC}"
  done
}

setup_rathole() {
  echo -e "\n${BLUE}[+] راه‌اندازی رتهول...${NC}"
  ROLE=$(cat ~/.tunnela_role 2>/dev/null || echo "unknown")
  IRAN_IPV4=$(cat ~/.tunnela_iran_ipv4 2>/dev/null || echo "")

  if [[ "$ROLE" == "iran" ]]; then
    echo -e "\n${GREEN}شما در سرور ایران هستید.${NC}"
    echo -e "${YELLOW}در ادامه از شما پرسیده می‌شود آیا می‌خواهید از IPv6 استفاده کنید؟${NC}"
    echo -e "${CYAN}✅ لطفاً گزینه 'yes' را وارد کنید تا تونل با IPv6 ساخته شود.${NC}"
    read -p "ادامه برای نصب رتهول؟ (Enter): "
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  elif [[ "$ROLE" == "kharej" && -n "$IRAN_IPV4" ]]; then
    IRAN_IPV6=$(ipv4_to_6to4 "$IRAN_IPV4")
    echo -e "\n${GREEN}🛰️ توجه: برای اتصال به سرور ایران، از آدرس‌های زیر استفاده کنید:${NC}"
    echo -e "   🔹 IPv6: ${GREEN}$IRAN_IPV6${NC}"
    echo -e "   🔹 IPv4: ${GREEN}192.168.250.1${NC}"
    echo -e "${CYAN}⏳ لطفاً در اسکریپت رتهول همین آی‌پی‌ها را وارد کنید.${NC}"
    read -p "ادامه برای نصب رتهول؟ (Enter): "
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)
  else
    echo -e "${RED}[!] نقش یا IP ایران مشخص نیست. لطفاً ابتدا Tunnel را ایجاد کنید.${NC}"
  fi
}

while true; do
  banner
  echo -e "${YELLOW}Choose an option:${NC}"
  echo " 1) Setup Tunnel (IPv6 + IPv4 GRE)"
  echo " 2) Show IPv6 Address"
  echo " 3) Remove All Tunnels"
  echo " 4) Setup Rathole Tunnel"
  echo " 0) Exit"
  echo -ne "\n${BLUE}Enter your choice: ${NC}"
  read CHOICE
  case $CHOICE in
    1) setup_tunnel;;
    2) show_ipv6;;
    3) remove_all_tunnels;;
    4) setup_rathole;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0;;
    *) echo -e "${RED}Invalid option. Try again.${NC}";;
  esac
  echo -e "\n${CYAN}برای بازگشت به منو Enter بزنید...${NC}"
  read
done
