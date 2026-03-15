#!/bin/bash
set -e

echo "Installing Travel Tail Router..."

# Update & install packages
apt update && apt upgrade -y
apt install -y python3 python3-pip hostapd dnsmasq iw curl git
sudo apt install -y python3-flask

# Ensure /etc/sysctl.conf exists
if [ ! -f /etc/sysctl.conf ]; then
    sudo touch /etc/sysctl.conf
fi

# Enable IP forwarding (update if exists, append if not)
if grep -q "^net.ipv4.ip_forward=" /etc/sysctl.conf; then
    sudo sed -i 's/^net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
else
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
fi

# Apply immediately
sudo sysctl -w net.ipv4.ip_forward=1

# NAT
iptables -t nat -A POSTROUTING -o wlan1 -j MASQUERADE
sh -c "iptables-save > /etc/iptables.ipv4.nat"
if ! grep -q "iptables-restore" /etc/rc.local; then
  sed -i '/exit 0/i iptables-restore < /etc/iptables.ipv4.nat' /etc/rc.local
fi

# hostapd
mkdir -p /etc/hostapd
cp hostapd/hostapd.conf /etc/hostapd/hostapd.conf
systemctl enable hostapd
systemctl enable dnsmasq

# dnsmasq
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig || true
cat > /etc/dnsmasq.conf <<EOL
interface=wlan0
dhcp-range=192.168.3.2,192.168.3.20,255.255.255.0,24h
no-resolv
server=1.1.1.1
server=1.0.0.1
EOL
systemctl restart dnsmasq

# Download Python scripts
curl -o /usr/local/bin/wifi-control.py https://raw.githubusercontent.com/<username>/travel-tail-router/main/wifi-control.py
curl -o /usr/local/bin/update-adblock.sh https://raw.githubusercontent.com/<username>/travel-tail-router/main/update-adblock.sh
chmod +x /usr/local/bin/wifi-control.py /usr/local/bin/update-adblock.sh

# Run adblock
/usr/local/bin/update-adblock.sh

# Prompt for Tailscale Auth Key
read -p "Enter your Tailscale Auth Key (starts with tskey-): " TSKEY

# Register Pi with Tailscale headless
sudo tailscale up --authkey $TSKEY --hostname travel-tail-pi --advertise-routes=192.168.1.0/24

# Start web panel
nohup python3 /usr/local/bin/wifi-control.py &

echo "Installation complete! Connect to SSID 'travel_tail_1' with password 'Tail_routing'"
