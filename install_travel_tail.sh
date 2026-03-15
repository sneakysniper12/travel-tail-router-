#!/bin/bash
set -e

echo "=== Installing Travel Tail Router (git clone method) ==="

# 1️⃣ Update & install required packages
sudo apt update
sudo apt install -y python3-flask iptables hostapd dnsmasq iw curl git net-tools

# 2️⃣ Enable IP forwarding safely
sudo touch /etc/sysctl.conf
grep -q "^net.ipv4.ip_forward=" /etc/sysctl.conf \
    && sudo sed -i 's/^net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf \
    || echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -w net.ipv4.ip_forward=1

# 3️⃣ Reset hostapd
sudo systemctl stop hostapd || true
sudo systemctl mask hostapd || true
sudo apt remove --purge -y hostapd
sudo apt install -y hostapd
sudo systemctl unmask hostapd

# 4️⃣ Setup hotspot
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
sudo systemctl start hostapd

# 5️⃣ Configure DHCP
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

# 6️⃣ Apply NAT
for i in {1..20}; do
    if ip link show wlan1 &>/dev/null; then NAT_IF="wlan1"; break; fi
    sleep 2
done
[ -z "$NAT_IF" ] && NAT_IF="wlan0"
sudo iptables -t nat -A POSTROUTING -o "$NAT_IF" -j MASQUERADE
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

# 7️⃣ Persist NAT via rc.local
if [ ! -f /etc/rc.local ]; then
    sudo tee /etc/rc.local > /dev/null <<'EOF'
#!/bin/bash
for i in {1..20}; do
    if ip link show wlan1 &>/dev/null; then NAT_IF="wlan1"; break; fi
    sleep 2
done
[ -z "$NAT_IF" ] && NAT_IF="wlan0"
/sbin/iptables-restore < /etc/iptables.ipv4.nat
exit 0
EOF
    sudo chmod +x /etc/rc.local
fi

# 8️⃣ Clone your repo
sudo git clone https://github.com/sneakysniper12/travel-tail-router-.git /opt/travel-tail -b main --depth 1
sudo cp /opt/travel-tail/wifi-control.py /usr/local/bin/
sudo cp /opt/travel-tail/update-adblock.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/wifi-control.py /usr/local/bin/update-adblock.sh

# 9️⃣ Run adblock once
sudo /usr/local/bin/update-adblock.sh || echo "Warning: adblock update failed, continuing"

# 🔟 Tailscale setup
read -p "Enter your Tailscale Auth Key (tskey-…): " TSKEY
sudo tailscale up --authkey "$TSKEY" --hostname travel-tail-pi --advertise-routes=192.168.1.0/24

# 1️⃣1️⃣ Start web panel
sudo nohup python3 /usr/local/bin/wifi-control.py >/dev/null 2>&1 &

echo "=== Installation complete! ==="
echo "Connect to SSID 'travel_tail_1' (password: Tail_routing)"
echo "Open http://192.168.3.1 to access the web panel."
