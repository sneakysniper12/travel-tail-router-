from flask import Flask, request, render_template_string
import subprocess
import time
import threading
import urllib.request
import re

app = Flask(__name__)

PAGE = """
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:Arial;background:#111;color:white;padding:20px;}
h2{color:#00c3ff;}
input{width:100%;padding:12px;margin:6px 0;border-radius:6px;border:none;font-size:16px;}
button{width:100%;padding:12px;margin-top:10px;background:#00c3ff;border:none;border-radius:6px;font-size:16px;}
.network{padding:10px;margin:4px 0;background:#222;border-radius:6px;cursor:pointer;}
.network:hover{background:#333;}
.status{background:#222;padding:10px;border-radius:6px;margin-bottom:20px;}
.portal{background:#ff9800;padding:10px;border-radius:6px;margin-bottom:20px;}
</style>
<script>
function fillSSID(name){document.getElementById("ssid").value = name}
</script>
</head>
<body>
<h2>Travel Tail Router</h2>
<div class="status">
<b>Connection Status</b><br>{{wifi_status}}<br><br>
<b>Tailscale</b><br>{{tailscale_status}}
</div>
{% if captive %}
<div class="portal">
⚠ Captive Portal Detected — open a website to login.
</div>
{% endif %}
<form method="post">
SSID
<input id="ssid" name="ssid">
Password
<input type="password" name="password">
<button type="submit">Connect</button>
</form>

<form method="post">
<button name="exit" value="on">Enable Exit Node</button>
<button name="exit" value="off">Disable Exit Node</button>
</form>

<br>
<form method="get">
<button>Refresh Networks</button>
</form>

<h3>Available Networks</h3>
{% for n in networks %}
<div class="network" onclick="fillSSID('{{n[0]}}')">
{{n[0]}}  ({{n[1]}} dBm)
</div>
{% endfor %}
</body>
</html>
"""

# Scan WiFi networks
def scan_wifi():
    result = subprocess.run(["iw","dev","wlan1","scan"], capture_output=True, text=True)
    networks = []
    ssid = None
    signal = None
    for line in result.stdout.split("\n"):
        if "signal:" in line:
            signal = float(line.split("signal:")[1].split()[0])
        if "SSID:" in line:
            ssid = line.split("SSID:")[1].strip()
            if ssid:
                networks.append((ssid,signal))
    unique = {}
    for ssid,signal in networks:
        if ssid not in unique or signal > unique[ssid]:
            unique[ssid] = signal
    return sorted(unique.items(), key=lambda x:x[1], reverse=True)

# Get saved networks
def saved_networks():
    with open("/etc/wpa_supplicant/wpa_supplicant.conf") as f:
        data = f.read()
    return re.findall(r'ssid="([^"]+)"', data)

# Connect to WiFi
def connect_wifi(ssid,password):
    conf = f'''
network={{
    ssid="{ssid}"
    psk="{password}"
}}
'''
    with open("/etc/wpa_supplicant/wpa_supplicant.conf","a") as f:
        f.write(conf)
    subprocess.run(["wpa_cli","-i","wlan1","reconfigure"])

# WiFi status
def wifi_status():
    result = subprocess.run(["iw","dev","wlan1","link"], capture_output=True, text=True)
    if "Not connected" in result.stdout:
        return "Not connected"
    for line in result.stdout.split("\n"):
        if "SSID:" in line:
            return "Connected to " + line.split("SSID:")[1].strip()
    return "Unknown"

# Tailscale status
def tailscale_status():
    result = subprocess.run(["tailscale","status"], capture_output=True, text=True)
    if result.returncode == 0:
        return "Running"
    else:
        return "Not connected"

# Detect captive portal
def detect_captive():
    try:
        r = urllib.request.urlopen("http://connectivitycheck.gstatic.com/generate_204", timeout=5)
        if r.status == 204:
            return False
        return True
    except:
        return True

# Auto network failover
def auto_network_failover():
    while True:
        result = subprocess.run(["iw","dev","wlan1","link"], capture_output=True, text=True)
        if "Not connected" in result.stdout:
            available = scan_wifi()
            saved = saved_networks()
            for ssid,signal in available:
                if ssid in saved:
                    subprocess.run(["wpa_cli","-i","wlan1","select_network",ssid])
                    subprocess.run(["wpa_cli","-i","wlan1","reconfigure"])
                    break
        time.sleep(30)

# Router watchdog
def router_watchdog():
    services = ["hostapd","dnsmasq","tailscaled"]
    while True:
        for s in services:
            result = subprocess.run(["systemctl","is-active",s], capture_output=True, text=True)
            if "active" not in result.stdout:
                subprocess.run(["systemctl","restart",s])
        time.sleep(20)

# Hotspot channel optimization
def optimize_channel():
    result = subprocess.run(["iw","dev","wlan0","scan"], capture_output=True, text=True)
    channels = {}
    for line in result.stdout.split("\n"):
        if "DS Parameter set" in line or "channel" in line:
            try:
                ch = int(line.split()[-1])
                channels[ch] = channels.get(ch,0)+1
            except: pass
    if not channels: return 6
    best = min(channels,key=channels.get)
    conf_path = "/etc/hostapd/hostapd.conf"
    with open(conf_path) as f:
        conf = f.read()
    conf = re.sub(r"channel=\d+", f"channel={best}", conf)
    with open(conf_path,"w") as f:
        f.write(conf)
    subprocess.run(["systemctl","restart","hostapd"])

def channel_optimizer():
    while True:
        optimize_channel()
        time.sleep(3600)

# Tailscale exit node functions
def tailscale_exit_enabled():
    result = subprocess.run(["tailscale","status","--json"], capture_output=True, text=True)
    return "--exit-node" in result.stdout or "ExitNode" in result.stdout

def enable_exit():
    subprocess.run(["tailscale","up","--advertise-exit-node","--advertise-routes=192.168.1.0/24"])

def disable_exit():
    subprocess.run(["tailscale","up","--advertise-routes=192.168.1.0/24"])

# Flask route
@app.route("/", methods=["GET","POST"])
def index():
    if request.method == "POST":
        if "exit" in request.form:
            if request.form["exit"]=="on": enable_exit()
            if request.form["exit"]=="off": disable_exit()
        elif "ssid" in request.form:
            ssid = request.form["ssid"]
            password = request.form["password"]
            connect_wifi(ssid,password)
    networks = scan_wifi()
    return render_template_string(PAGE,
                                  networks=networks,
                                  wifi_status=wifi_status(),
                                  tailscale_status=tailscale_status(),
                                  captive=detect_captive())

# Start background threads
threading.Thread(target=auto_network_failover, daemon=True).start()
threading.Thread(target=router_watchdog, daemon=True).start()
threading.Thread(target=channel_optimizer, daemon=True).start()

# Start Flask web panel
app.run(host="0.0.0.0", port=80)
