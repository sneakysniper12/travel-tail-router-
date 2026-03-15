# Travel Tail Router

DIY portable Raspberry Pi travel router:

- Dual WiFi adapters (wlan1 inlet, wlan0 outlet)
- Mobile-friendly web panel
- Clickable network list, signal sorting
- Auto reconnect & network failover
- Captive portal detection
- Automatic hotspot channel optimization
- Tailscale exit node with subnet routing 192.168.1.0/24
- Router watchdog for self-healing
- Lightweight ad-blocking

## One-Command Install

Run this on a fresh Raspberry Pi OS Lite:

```bash
curl -sSL https://raw.githubusercontent.com/<sneakysniper12>/travel-tail-router/main/install_travel_tail.sh | sudo bash
