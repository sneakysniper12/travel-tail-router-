#!/bin/bash
# update-adblock.sh
# Use tree/main URL for your repo blocklists
BLOCKLIST_URL="https://github.com/sneakysniper12/travel-tail-router-/tree/main/blocklists.txt"
BLOCKLIST_DIR="/etc/travel-tail"
BLOCKLIST_FILE="$BLOCKLIST_DIR/blocklists.txt"

sudo mkdir -p "$BLOCKLIST_DIR"

if curl -fsSL "$BLOCKLIST_URL" -o "$BLOCKLIST_FILE"; then
    echo "Adblock list updated successfully!"
else
    echo "Warning: Could not download adblock list."
fi

if [ -f "$BLOCKLIST_FILE" ]; then
    sudo iptables -F
    while read -r domain; do
        [[ "$domain" =~ ^#.*$ || -z "$domain" ]] && continue
        sudo iptables -A OUTPUT -p tcp -d "$domain" -j REJECT
    done < "$BLOCKLIST_FILE"
    echo "Adblock rules applied!"
fi
