#!/bin/bash
set -e

TUN_IF="t6t$(tr -dc a-z0-9 </dev/urandom | head -c 4)"
GRE_IF="gre0"

RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m"

banner() {
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}       تانلا تانل - Tunnela Tunnel       ${NC}"
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
  echo -e "🧪 Test:      ${CYAN}ping6 $PEER_IPV6${NC}"

  echo "$ROLE" > ~/.tunnela_role
  echo "$IRAN_IPV4" > ~/.tunnela_iran_ipv4
}

show_ipv6() {
  echo -e "\n${CYAN}🛰️ Your active 6to4 IPv6 addresses:${NC}"
  ip -6 addr show | grep -oP 'inet6 2002:[0-9a-f:]+' | awk '{print $2}' || echo -e "${RED}[!] No 6to4 IPv6 found${NC}"
}

remove_all_tunnels() {
  echo -e "${YELLOW}Removing all tunnels (t6t* and gre0)...${NC}"
  for iface in $(ip tunnel show | grep -E '^t6t|^gre0' | awk '{print $1}'); do
    sudo ip tunnel del "$iface"
    echo -e "${GREEN}✔ Removed tunnel: $iface${NC}"
  done
}

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

  echo -e "\n${BLUE}[+] Setting up GRE tunnel (IPv4 local)...${NC}"
  sudo modprobe ip_gre
  sudo ip tunnel del $GRE_IF 2>/dev/null || true
  sudo ip tunnel add $GRE_IF mode gre local "$MY_IPV4" remote "$PEER_IPV4" ttl 255
  sudo ip addr add "$MY_V4LOCAL/30" dev $GRE_IF
  sudo ip link set $GRE_IF up
  sudo iptables -C INPUT -p gre -j ACCEPT 2>/dev/null || sudo iptables -A INPUT -p gre -j ACCEPT

  echo -e "${GREEN}✅ GRE tunnel ready using $GRE_IF${NC}"
  echo -e "🔒 Your IPv4 Local: ${YELLOW}$MY_V4LOCAL${NC}"
  echo -e "🔒 Peer IPv4 Local: ${YELLOW}$PEER_V4LOCAL${NC}"
}

setup_rathole() {
  echo -e "\n${BLUE}[+] راه‌اندازی تونل رتهول (Rathole)${NC}"
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
    echo -e "\n${GREEN}📍 این سرور در موقعیت خارج از ایران قرار دارد.${NC}"
    echo -e "${YELLOW}📌 برای اتصال به سرور ایران، از یکی از آدرس‌های زیر استفاده کنید:${NC}"
    echo -e "🔹 IPv6 ایران: ${CYAN}$IRAN_IPV6${NC}"
    echo -e "🔹 IPv4 لوکال ایران: ${CYAN}$IRAN_V4LOCAL${NC}"
    echo -e "${CYAN}✅ هر کدام را می‌توانید در تنظیمات رتهول وارد کنید، بستگی به تنظیمات و ابزار شما دارد.${NC}"
    echo -e "${GREEN}اگر آماده‌ای، Enter را بزن تا نصب رتهول آغاز شود...${NC}"
    read
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)

  else
    echo -e "${RED}⚠️ ابتدا باید نقش سرور و آی‌پی ایران را با ساخت یکی از تونل‌ها مشخص کنید.${NC}"
  fi
}

while true; do
  banner
  echo -e "${YELLOW}انتخاب کنید:${NC}"
  echo " 1) ساخت تونل 6to4 (IPv6 لوکال)"
  echo " 2) نمایش آی‌پی‌های 6to4"
  echo " 3) حذف همه تونل‌ها"
  echo " 4) ساخت تونل GRE (IPv4 لوکال)"
  echo " 5) نصب و راه‌اندازی رتهول"
  echo " 0) خروج"
  echo -ne "\n${BLUE}گزینه را وارد کنید: ${NC}"
  read CHOICE

  case $CHOICE in
    1) setup_tunnel ;;
    2) show_ipv6 ;;
    3) remove_all_tunnels ;;
    4) setup_gre ;;
    5) setup_rathole ;;
    0) echo -e "${GREEN}خروج...${NC}"; exit 0 ;;
    *) echo -e "${RED}گزینه نامعتبر است. دوباره تلاش کنید.${NC}" ;;
  esac
  echo -e "\n${CYAN}برای بازگشت به منو Enter بزنید...${NC}"
  read
done
---
