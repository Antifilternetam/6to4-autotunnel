#!/bin/bash

echo "🌍 6to4 IPv6 Tunnel Auto Installer"

read -p "Is this the 'iran' or 'kharej' server? (iran/kharej): " ROLE
read -p "Enter the public IPv4 of the IRAN server: " IRAN_IPV4
read -p "Enter the public IPv4 of the KHAREJ server: " KHAREJ_IPV4

# Validate role
if [[ "$ROLE" != "iran" && "$ROLE" != "kharej" ]]; then
  echo "❌ Invalid role. Use 'iran' or 'kharej'."
  exit 1
fi

echo "📦 Installing requirements..."
sudo apt update -y >/dev/null
sudo apt install curl -y >/dev/null

echo "📁 Creating tunnel setup script..."
sudo tee /usr/local/bin/setup-6to4.sh >/dev/null <<EOF
#!/bin/bash

ROLE="$ROLE"
IRAN_IPV4="$IRAN_IPV4"
KHAREJ_IPV4="$KHAREJ_IPV4"
TUN_IF="sit0"

if [[ "\$ROLE" == "iran" ]]; then
    MY_IPV4="\$IRAN_IPV4"
    PEER_IPV4="\$KHAREJ_IPV4"
else
    MY_IPV4="\$KHAREJ_IPV4"
    PEER_IPV4="\$IRAN_IPV4"
fi

ipv4_to_6to4() {
    IFS='.' read -r o1 o2 o3 o4 <<< "\$1"
    printf "2002:%02x%02x:%02x%02x::1" "\$o1" "\$o2" "\$o3" "\$o4"
}

MY_IPV6=\$(ipv4_to_6to4 "\$MY_IPV4")

sudo modprobe ipv6
sudo ip tunnel add \$TUN_IF mode sit remote any local "\$MY_IPV4" ttl 255 || true
sudo ip link set \$TUN_IF up
sudo ip -6 addr flush dev \$TUN_IF
sudo ip -6 addr add "\$MY_IPV6/16" dev \$TUN_IF
sudo ip6tables -C INPUT -p icmpv6 -j ACCEPT 2>/dev/null || sudo ip6tables -A INPUT -p icmpv6 -j ACCEPT

echo "✅ Tunnel set on \$TUN_IF with IPv6 \$MY_IPV6"
EOF

sudo chmod +x /usr/local/bin/setup-6to4.sh

echo "🛠️ Creating systemd service..."
sudo tee /etc/systemd/system/6to4.service >/dev/null <<EOF
[Unit]
Description=6to4 IPv6 Tunnel Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-6to4.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Enabling and starting 6to4.service..."
sudo systemctl daemon-reload
sudo systemctl enable 6to4.service
sudo systemctl start 6to4.service

echo "✅ Done. Tunnel is active and will persist after reboot."
