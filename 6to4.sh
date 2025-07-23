#!/bin/bash

set -e

# رنگ‌ها
RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m"

# لوگو
banner() {
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}         تانلا تانل - Tunnela Tunnel        ${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo -e "📦 Github:    ${BLUE}https://github.com/Antifilternetam/6to4-tunnela${NC}"
  echo -e "📣 Telegram:  ${CYAN}@tunnela${NC}"
  echo -e "${CYAN}========================================${NC}\n"
}

# ساخت آدرس IPv6 از IPv4
ipv4_to_6to4() {
  local ip=$1
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  printf "2002:%02x%02x:%02x%02x::1\n" "$o1" "$o2" "$o3" "$o4"
}

# ساخت تونل
setup_tunnel() {
  TUN_IF="t6t$(tr -dc a-z0-9 </dev/urandom | head -c 5)"
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

  echo -e "\n${BLUE}[+] Creating 6to4 IPv6 tunnel: ${YELLOW}$TUN_IF${NC}"
  sudo modprobe ipv6
  sudo ip tunnel del $TUN_IF 2>/dev/null || true
  sudo ip tunnel add $TUN_IF mode sit remote any local "$MY_IPV4" ttl 255
  sudo ip link set $TUN_IF up
  sudo ip -6 addr add "$MY_IPV6/16" dev $TUN_IF
  sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT

  echo "$ROLE" > ~/.6to4_role
  echo "$IRAN_IPV4" > ~/.6to4_iran_ipv4

  echo -e "${GREEN}✅ 6to4 tunnel ready using $TUN_IF${NC}"
  echo -e "🌐 Your IPv6:  ${YELLOW}$MY_IPV6${NC}"
  echo -e "🌐 Peer IPv6:  ${YELLOW}$PEER_IPV6${NC}"
  echo -e "🧪 Test:      ${CYAN}ping6 $PEER_IPV6${NC}"
}

# نمایش آی‌پی‌ها
show_ipv6() {
  echo -e "\n${CYAN}🛰️ Active 6to4 IPv6 addresses:${NC}"
  ip -6 addr show | grep -oP 'inet6 2002:[0-9a-f:]+(?=/)' | awk '{print $2}' || echo -e "${RED}[!] No 6to4 IPv6 found${NC}"
}

# حذف همه تونل‌ها
remove_all_tunnels() {
  echo -e "${YELLOW}🧹 Removing all tunnels (t6t*)...${NC}"
  for iface in $(ip tunnel show | grep '^t6t' | awk '{print $1}'); do
    sudo ip tunnel del "$iface" 2>/dev/null && echo -e "${GREEN}✔ Removed: $iface${NC}"
  done

  # حذف قوانین iptables
  sudo ip6tables -D INPUT -p icmpv6 -j ACCEPT 2>/dev/null
  sudo iptables -D INPUT -p gre -j ACCEPT 2>/dev/null

  # حذف فایل‌های موقتی
  rm -f ~/.6to4_role ~/.6to4_iran_ipv4

  echo -e "${GREEN}✅ Cleanup complete.${NC}"
}

# راه‌اندازی رتهول
setup_rathole() {
  echo -e "\n${BLUE}[+] راه‌اندازی رتهول...${NC}"
  echo -e "${CYAN}این ابزار از پروژه Musixal/rathole-tunnel استفاده می‌کند.${NC}"

  ROLE=$(cat ~/.6to4_role 2>/dev/null || echo "unknown")
  IRAN_IPV4=$(cat ~/.6to4_iran_ipv4 2>/dev/null || echo "")

  if [[ "$ROLE" == "iran" ]]; then
    echo -e "\n${GREEN}شما در سرور ایران هستید.${NC}"
    echo -e "${YELLOW}در ادامه از شما پرسیده می‌شود آیا می‌خواهید از IPv6 استفاده کنید؟${NC}"
    echo -e "${CYAN}✅ لطفاً گزینه 'y' را وارد کنید تا رتهول با IPv6 اجرا شود.${NC}"
    echo -e "\n${GREEN}اگر آماده‌ای، Enter را بزن تا نصب آغاز شود...${NC}"
    read
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)

  elif [[ "$ROLE" == "kharej" && -n "$IRAN_IPV4" ]]; then
    IRAN_IPV6=$(ipv4_to_6to4 "$IRAN_IPV4")
    echo -e "\n${GREEN}🛰️ از این آدرس برای اتصال به ایران استفاده کن:${NC}"
    echo -e "${YELLOW}$IRAN_IPV6${NC}"
    echo -e "${CYAN}⏳ در رتهول، این IPv6 را به عنوان آدرس سرور وارد کن.${NC}"
    echo -e "${CYAN}✅ اگر آماده‌ای، Enter بزن تا نصب شود...${NC}"
    read
    bash <(curl -Ls --ipv4 https://raw.githubusercontent.com/Musixal/rathole-tunnel/main/rathole_v2.sh)

  else
    echo -e "${RED}[!] نقش یا IP ایران مشخص نیست. لطفاً اول تونل رو بساز.${NC}"
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
  echo -ne "\n${BLUE}Enter your choice: ${NC}"
  read CHOICE

  case $CHOICE in
    1) setup_tunnel ;;
    2) show_ipv6 ;;
    3) remove_all_tunnels ;;
    4) setup_rathole ;;
    0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
    *) echo -e "${RED}Invalid option. Try again.${NC}" ;;
  esac

  echo -e "\n${CYAN}برای بازگشت به منو Enter بزن...${NC}"
  read
done
