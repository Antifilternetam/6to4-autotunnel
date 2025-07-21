#!/bin/bash

set -e

----------------------

6to4 AutoTunnel Script (Pro Version)

Author: Antifilternetam

----------------------

SERVICE_FILE="/etc/systemd/system/6to4.service" SCRIPT_PATH="/usr/local/bin/setup-6to4.sh"

print_help() { echo "\nUsage: bash 6to4.sh [install|uninstall|status|--help]" echo "  install     : (default) setup 6to4 tunnel" echo "  uninstall   : remove all 6to4 tunnel settings" echo "  status      : show tunnel and IPv6 info" echo "  --help      : show this help menu\n" exit 0 }

check_installed() { if [[ -f "$SERVICE_FILE" ]]; then echo "[!] Tunnel already installed. Use 'status' or 'uninstall'." exit 1 fi }

create_script() { cat <<EOF > $SCRIPT_PATH #!/bin/bash modprobe ipv6 modprobe sit ip tunnel add sit0 mode sit ttl 255 || true ip link set sit0 up ip -6 addr add $IP6/64 dev sit0 || true ip -6 route add default dev sit0 metric 1024 || true EOF chmod +x $SCRIPT_PATH }

create_service() { cat <<EOF > $SERVICE_FILE [Unit] Description=6to4 Tunnel Setup After=network.target

[Service] Type=oneshot ExecStart=$SCRIPT_PATH RemainAfterExit=true

[Install] WantedBy=multi-user.target EOF systemctl daemon-reexec systemctl enable --now 6to4.service }

get_ipv6() { HEX_IP=$(printf '%02x' $(echo $MY_IP | tr '.' ' ')) IP6="2002:${HEX_IP:0:4}:${HEX_IP:4:4}::1" }

install_tunnel() { echo "[+] Starting 6to4 Tunnel Setup" read -p "Enter your public IPv4 address: " MY_IP get_ipv6 create_script create_service echo "[✔] IPv6 assigned: $IP6" echo "[✔] Tunnel active. Use 'bash 6to4.sh status' to check." }

uninstall_tunnel() { echo "[+] Removing 6to4 tunnel..." systemctl stop 6to4.service || true systemctl disable 6to4.service || true rm -f $SERVICE_FILE $SCRIPT_PATH ip tunnel del sit0 2>/dev/null || true systemctl daemon-reload echo "[✔] Tunnel removed." exit 0 }

status_info() { echo "[+] Tunnel info:\n" ip -6 addr show dev sit0 || echo "sit0 not configured." ip -6 route | grep sit0 || echo "No IPv6 route found." systemctl status 6to4.service --no-pager exit 0 }

----------------------

Main Execution Logic

----------------------

case "$1" in uninstall) uninstall_tunnel ;; status) status_info ;; --help|-h) print_help ;; install|"") check_installed install_tunnel ;; *) echo "[!] Unknown option: $1" print_help ;; esac

