#!/bin/bash
set -e

echo "=== Installing Travel Tail Router ==="

# 1️⃣ Update & install required packages
sudo apt update
sudo apt install -y \
    python3-flask \
    iptables \
    hostapd \
    dnsmasq \
    iw \
    curl \
    git \
    net-tools

# 2️⃣ Enable IP forwarding safely
if [ ! -f /etc/sysctl.conf ]; then
    sudo touch /etc/sysctl.conf
fi
if grep -q "^net.ipv4.ip_forward=" /etc/sysctl.conf; then
    sudo sed -i 's/^net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
else
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -w net.ipv4.ip_forward=1

# 3️⃣ Configure NAT
sudo iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

# 4️⃣ Create systemd service to restore NAT on boot
sudo tee /etc/systemd/system/iptables-restore.service > /dev/null <<'EOF'
[Unit]
Description=Restore iptables rules
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore < /etc/iptables.ipv4.nat
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable iptables-restore.service
sudo systemctl start iptables-restore.service

# 5️⃣ Setup hostapd hotspot
sudo mkdir -p /etc/hostapd
sudo tee /etc/hostapd/hostapd.conf > /dev/null <<EOF
interface=wlan0
driver=nl80211
ssid=travel_tail_1
hw_mode=g
channel=6
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF
sudo systemctl enable hostapd
sudo systemctl enable dnsmasq

# 6️⃣ Configure dnsmasq DHCP
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig || true
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
dhcp-range=192.168.3.2,192.168.3.20,255.255.255.0,24h
no-resolv
server=1.1.1.1
server=1.0.0.1
EOF
sudo systemctl restart dnsmasq

# 7️⃣ Download Python scripts
sudo curl -o /usr/local/bin/wifi-control.py https://raw.githubusercontent.com/<username>/travel-tail-router/main/wifi-control.py
sudo curl -o /usr/local/bin/update-adblock.sh https://raw.githubusercontent.com/<username>/travel-tail-router/main/update-adblock.sh
sudo chmod +x /usr/local/bin/wifi-control.py /usr/local/bin/update-adblock.sh

# 8️⃣ Run adblock once
sudo /usr/local/bin/update-adblock.sh

# 9️⃣ Prompt for Tailscale auth key
read -p "Enter your Tailscale Auth Key (starts with tskey-): " TSKEY

# 10️⃣ Register Pi with Tailscale
sudo tailscale up --authkey $TSKEY --hostname travel-tail-pi --advertise-routes=192.168.1.0/24

# 11️⃣ Start web panel
sudo nohup python3 /usr/local/bin/wifi-control.py &

echo "=== Installation complete! ==="
echo "Connect to SSID 'travel_tail_1' with password 'Tail_routing'"
echo "Then open http://192.168.3.1 to access the web panel."
