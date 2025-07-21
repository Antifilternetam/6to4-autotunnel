#!/bin/bash

set -e

# ----------------------
# 6to4 AutoTunnel Script (Pro Version)
# Author: Antifilternetam
# ----------------------

SERVICE_FILE="/etc/systemd/system/6to4.service"
SCRIPT_PATH="/usr/local/bin/setup-6to4.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

banner() {
  echo -e "\n${CYAN}========================================${NC}"
  echo -e "${GREEN}     آنتی فیلترنتم - AntiFilterNetam     ${NC}"
  echo -e "${CYAN}========================================${NC}\n"
}

print_menu() {
  while true; do
    banner
    echo -e "${YELLOW}Choose an option:${NC}"
    echo " 1) Install 6to4 Tunnel"
    echo " 2) View Tunnel Status"
    echo " 3) View Assigned IPv6 Address"
    echo " 4) Uninstall Tunnel"
    echo " 5) Help"
    echo " 0) Exit"
    echo -ne "\n${BLUE}Enter choice [0-5]: ${NC}"
    read choice
    case $choice in
      1) check_installed install; install_tunnel ;;
      2) status_info ;;
      3) show_ipv6 ;;
      4) uninstall_tunnel ;;
      5) print_help ;;
      0) echo -e "${GREEN}Exiting.${NC}"; exit 0 ;;
      *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac
    echo -e "\n${CYAN}Press Enter to return to menu...${NC}"
    read
  done
}

print_help() {
  echo -e "\n${CYAN}Usage:${NC} bash 6to4.sh [install|uninstall|status|ipv6|--help]"
  echo -e "${YELLOW}  install     ${NC}: setup 6to4 tunnel"
  echo -e "${YELLOW}  uninstall   ${NC}: remove all 6to4 tunnel settings"
  echo -e "${YELLOW}  status      ${NC}: show tunnel and IPv6 info"
  echo -e "${YELLOW}  ipv6        ${NC}: show assigned IPv6 address"
  echo -e "${YELLOW}  --help      ${NC}: show this help menu"
  echo ""
  return
}

check_installed() {
  if [[ -f "$SERVICE_FILE" ]]; then
    if [[ "$1" == "install" ]]; then
      echo -e "${RED}[!] Tunnel already installed. Use 'status' or 'uninstall'.${NC}"
      exit 1
    fi
  fi
}

create_script() {
  cat <<EOF > $SCRIPT_PATH
#!/bin/bash
modprobe ipv6
modprobe sit
ip tunnel add sit0 mode sit ttl 255 || true
ip link set sit0 up
ip -6 addr add $IP6/64 dev sit0 || true
ip -6 route add default dev sit0 metric 1024 || true
EOF
  chmod +x $SCRIPT_PATH
}

create_service() {
  cat <<EOF > $SERVICE_FILE
[Unit]
Description=6to4 Tunnel Setup
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reexec
  systemctl enable --now 6to4.service
}

get_ipv6() {
  HEX_IP=$(printf '%02x' $(echo $MY_IP | tr '.' ' '))
  IP6="2002:${HEX_IP:0:4}:${HEX_IP:4:4}::1"
}

install_tunnel() {
  echo -e "${BLUE}[+] Starting 6to4 Tunnel Setup${NC}"
  read -p "Enter your public IPv4 address: " MY_IP
  get_ipv6
  create_script
  create_service
  echo -e "${GREEN}[✔] IPv6 assigned: $IP6${NC}"
  echo -e "${GREEN}[✔] Tunnel active. Use 'status' to check.${NC}"
}

uninstall_tunnel() {
  echo -e "${YELLOW}[+] Removing 6to4 tunnel...${NC}"
  systemctl stop 6to4.service || true
  systemctl disable 6to4.service || true
  rm -f $SERVICE_FILE $SCRIPT_PATH
  ip tunnel del sit0 2>/dev/null || true
  systemctl daemon-reload
  echo -e "${GREEN}[✔] Tunnel removed.${NC}"
  exit 0
}

status_info() {
  echo -e "${CYAN}[+] Tunnel info:${NC}\n"
  ip -6 addr show dev sit0 || echo -e "${RED}sit0 not configured.${NC}"
  ip -6 route | grep sit0 || echo -e "${RED}No IPv6 route found.${NC}"
  systemctl status 6to4.service --no-pager
  return
}

show_ipv6() {
  echo -e "${CYAN}[+] Assigned IPv6 Address (sit0):${NC}"
  ip -6 addr show dev sit0 | grep inet6 | awk '{print $2}' || echo -e "${RED}[!] No IPv6 address found on sit0${NC}"
  return
}

# ----------------------
# Main Execution Logic
# ----------------------

banner
print_menu
