#!/bin/bash
# update-adblock.sh
# Apply adblock using cloned repo blocklist

BLOCKLIST_FILE="/opt/travel-tail/blocklists.txt"
LOCAL_FILE="/etc/travel-tail/blocklists.txt"
sudo mkdir -p /etc/travel-tail

# Copy blocklist from repo
if [ -f "$BLOCKLIST_FILE" ]; then
    sudo cp "$BLOCKLIST_FILE" "$LOCAL_FILE"
    echo "Blocklist copied from repo."
else
    echo "Warning: Blocklist not found in repo."
fi

# Apply iptables rules
if [ -f "$LOCAL_FILE" ]; then
    sudo iptables -F
    while read -r domain; do
        [[ "$domain" =~ ^#.*$ || -z "$domain" ]] && continue
        sudo iptables -A OUTPUT -p tcp -d "$domain" -j REJECT
    done < "$LOCAL_FILE"
    echo "Adblock rules applied!"
fi
