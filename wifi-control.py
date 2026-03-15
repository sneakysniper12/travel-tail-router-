#!/usr/bin/env python3
import os
import subprocess
import requests
import time
from flask import Flask, render_template, request, redirect

app = Flask(__name__)

# Use tree/main URL for your repo files
ADBLOCK_SCRIPT_URL = "https://github.com/sneakysniper12/travel-tail-router-/tree/main/update-adblock.sh"
ADBLOCK_SCRIPT_PATH = "/usr/local/bin/update-adblock.sh"

def update_adblock_script():
    try:
        response = requests.get(ADBLOCK_SCRIPT_URL)
        response.raise_for_status()
        with open(ADBLOCK_SCRIPT_PATH, "wb") as f:
            f.write(response.content)
        os.chmod(ADBLOCK_SCRIPT_PATH, 0o755)
        print("Adblock script updated successfully!")
    except Exception as e:
        print(f"Warning: Could not update adblock script: {e}")

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
