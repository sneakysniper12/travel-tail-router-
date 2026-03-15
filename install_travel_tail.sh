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
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
fi
sudo sysctl -w net.ipv4.ip_forward=1

# 3️⃣ Setup hotspot (hostapd)
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

# Unmask hostapd if needed
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd
# 4️⃣ Configure DHCP (dnsmasq)
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig || true
sudo tee /etc/dnsmasq.conf > /dev/null <<EOF
interface=wlan0
dhcp-range=192.168.3.2,192.168.3.20,255.255.255.0,24h
no-resolv
server=1.1.1.1
server=1.0.0.1
EOF
sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq

# 5️⃣ Apply NAT dynamically
echo "Applying NAT..."
for i in {1..20}; do
    if ip link show wlan1 &>/dev/null; then
        NAT_IF="wlan1"
        break
    fi
    sleep 2
done
if [ -z "$NAT_IF" ]; then
    echo "Warning: wlan1 not found, using wlan0 for NAT"
    NAT_IF="wlan0"
fi
sudo iptables -t nat -A POSTROUTING -o "$NAT_IF" -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

# 6️⃣ Download Python scripts
sudo curl -fsSL -o /usr/local/bin/wifi-control.py https://raw.githubusercontent.com/<username>/travel-tail-router/main/wifi-control.py
sudo curl -fsSL -o /usr/local/bin/update-adblock.sh https://raw.githubusercontent.com/<username>/travel-tail-router/main/update-adblock.sh
sudo chmod +x /usr/local/bin/wifi-control.py /usr/local/bin/update-adblock.sh

# 7️⃣ Run adblock once
sudo /usr/local/bin/update-adblock.sh || echo "Warning: adblock update failed, continuing"

# 8️⃣ Prompt for Tailscale auth key
read -p "Enter your Tailscale Auth Key (starts with tskey-): " TSKEY

# 9️⃣ Register Pi with Tailscale
sudo tailscale up --authkey "$TSKEY" --hostname travel-tail-pi --advertise-routes=192.168.1.0/24

# 10️⃣ Start web panel
sudo nohup python3 /usr/local/bin/wifi-control.py >/dev/null 2>&1 &

echo "=== Installation complete! ==="
echo "Connect to SSID 'travel_tail_1' with password 'Tail_routing'"
echo "Then open http://192.168.3.1 to access the web panel."
