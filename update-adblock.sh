#!/bin/bash
BLOCKLIST=/etc/dnsmasq.d/adblock.conf

echo "Downloading adblock list..."
curl -s https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts | \
grep "^0.0.0.0" | \
awk '{print "address=/"$2"/0.0.0.0"}' \
> $BLOCKLIST

systemctl restart dnsmasq
echo "Adblock updated."
