#!/bin/bash
# update-adblock.sh
# Downloads and applies ad-block lists

BLOCKLIST_URL="https://raw.githubusercontent.com/sneakysniper12/travel-tail-router-/refs/heads/main/blocklists.txt"
BLOCKLIST_DIR="/etc/travel-tail"
BLOCKLIST_FILE="$BLOCKLIST_DIR/blocklists.txt"

# Ensure directory exists
sudo mkdir -p "$BLOCKLIST_DIR"

# Download blocklist
if curl -fsSL "$BLOCKLIST_URL" -o "$BLOCKLIST_FILE"; then
    echo "Adblock list updated successfully!"
else
    echo "Warning: Could not download adblock list."
fi

# Apply adblock using iptables
if [ -f "$BLOCKLIST_FILE" ]; then
    sudo iptables -F
    while read -r domain; do
        # Skip empty lines or comments
        [[ "$domain" =~ ^#.*$ || -z "$domain" ]] && continue
        sudo iptables -A OUTPUT -p tcp -d "$domain" -j REJECT
    done < "$BLOCKLIST_FILE"
    echo "Adblock rules applied!"
fi
