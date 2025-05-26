#!/bin/bash
set -e

# Configuration
IPSET_NAME="blocked_domains"
IPTABLES_COMMENT="domain-blocker-rule"
DOMAINS_FILE="/etc/linux-domain-blocker/domains.list"
SCRIPT_DIR="/etc/linux-domain-blocker"

# Install dependencies
if ! dpkg -l | grep -qE 'ipset|iptables-persistent|dnsutils'; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends ipset iptables-persistent dnsutils
fi

# Create ipset if not exists
if ! sudo ipset list -n | grep -q "^${IPSET_NAME}\$"; then
    sudo ipset create $IPSET_NAME hash:ip timeout 300
fi

# Add iptables rule if not exists
if ! sudo iptables -C OUTPUT -m set --match-set $IPSET_NAME dst -j DROP 2>/dev/null; then
    sudo iptables -I OUTPUT 1 -m set --match-set $IPSET_NAME dst -j DROP -m comment --comment "$IPTABLES_COMMENT"
fi

# Create config directory
sudo mkdir -p /etc/linux-domain-blocker

# Install update script
sudo cp update_blocked_domains.sh $SCRIPT_DIR/
sudo chmod +x $SCRIPT_DIR/update_blocked_domains.sh

# Install domains list
[ -f domains.list ] && sudo cp domains.list $DOMAINS_FILE

# Create cron job if not exists
if ! crontab -l | grep -q "$SCRIPT_DIR/update_blocked_domains.sh"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_DIR/update_blocked_domains.sh") | crontab -
fi

# Persist rules
sudo ipset save | sudo tee /etc/iptables/ipset >/dev/null
sudo netfilter-persistent save

# Initial update
sudo $SCRIPT_DIR/update_blocked_domains.sh

echo "Installation complete. Blocking domains from: $DOMAINS_FILE"
