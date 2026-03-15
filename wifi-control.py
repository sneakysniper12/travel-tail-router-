#!/usr/bin/env python3
import os
import subprocess
import time
from flask import Flask, render_template, request, redirect

app = Flask(__name__)

# Paths
ADBLOCK_SCRIPT_PATH = "/usr/local/bin/update-adblock.sh"

# Update adblock script if it exists in the cloned repo
def update_adblock_script():
    repo_script = "/opt/travel-tail/update-adblock.sh"
    if os.path.isfile(repo_script):
        try:
            subprocess.run(["sudo", "cp", repo_script, ADBLOCK_SCRIPT_PATH], check=True)
            subprocess.run(["sudo", "chmod", "+x", ADBLOCK_SCRIPT_PATH], check=True)
            print("Adblock script updated from repo!")
        except Exception as e:
            print(f"Warning: Could not update adblock script: {e}")
    else:
        print("Warning: Adblock script not found in repo")

# Scan available networks on wlan1
def scan_networks():
    result = subprocess.run(["sudo", "iwlist", "wlan1", "scan"], capture_output=True, text=True)
    networks = []
    for line in result.stdout.split("\n"):
        line = line.strip()
        if line.startswith("ESSID:"):
            ssid = line.split(":")[1].strip('"')
            if ssid:
                networks.append(ssid)
    return sorted(set(networks))

# Connect to Wi-Fi
def connect_wifi(ssid, password):
    wpa_conf = f"""
network={{
    ssid="{ssid}"
    psk="{password}"
}}
"""
    with open("/etc/wpa_supplicant/wpa_supplicant.conf", "a") as f:
        f.write(wpa_conf)
    subprocess.run(["sudo", "wpa_cli", "-i", "wlan1", "reconfigure"])

# Flask routes
@app.route("/")
def index():
    networks = scan_networks()
    return render_template("index.html", networks=networks)

@app.route("/connect", methods=["POST"])
def connect():
    ssid = request.form.get("ssid")
    password = request.form.get("password")
    connect_wifi(ssid, password)
    return redirect("/")

if __name__ == "__main__":
    update_adblock_script()
    app.run(host="0.0.0.0", port=80)
