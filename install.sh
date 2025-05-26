#!/bin/bash
set -e

# Configuration
IPSET_NAME="blocked_domains"
IPTABLES_COMMENT="domain-blocker-rule"
DOMAINS_FILE="/etc/linux-domain-blocker/domains.list"
SCRIPT_DIR="/etc/linux-domain-blocker"

# Install dependencies
if ! command -v ipset >/dev/null 2>&1 || ! command -v iptables >/dev/null 2>&1 || ! command -v host >/dev/null 2>&1; then
    apt-get update
    apt-get install -y --no-install-recommends ipset iptables-persistent dnsutils
fi

# Create ipset if not exists
if ! ipset list -n | grep -q "^${IPSET_NAME}\$"; then
    ipset create $IPSET_NAME hash:ip timeout 300
fi

# Add iptables rule if not exists
if ! iptables -C OUTPUT -m set --match-set $IPSET_NAME dst -j DROP 2>/dev/null; then
    iptables -I OUTPUT 1 -m set --match-set $IPSET_NAME dst -j DROP -m comment --comment "$IPTABLES_COMMENT"
fi

# Ensure Docker bridge network also drops these IPs
DOCKER_BRIDGE="docker0"
if ip link show $DOCKER_BRIDGE >/dev/null 2>&1; then
    # Block from containers to blocked IPs
    if ! iptables -C FORWARD -i $DOCKER_BRIDGE -m set --match-set $IPSET_NAME dst -j DROP 2>/dev/null; then
        iptables -I FORWARD 1 -i $DOCKER_BRIDGE -m set --match-set $IPSET_NAME dst -j DROP -m comment --comment "${IPTABLES_COMMENT}-docker"
    fi
    # Block from host to containers if needed (optional, usually OUTPUT covers host)
fi

# Create config directory
mkdir -p /etc/linux-domain-blocker

# Install update script
cp update_blocked_domains.sh $SCRIPT_DIR/
chmod +x $SCRIPT_DIR/update_blocked_domains.sh

# Install domains list
[ -f domains.list ] && cp domains.list $DOMAINS_FILE

# Create cron job if not exists
if ! crontab -u root -l | grep -q "$SCRIPT_DIR/update_blocked_domains.sh"; then
    (crontab -u root -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_DIR/update_blocked_domains.sh") | crontab -u root -
fi

# Persist rules
ipset save | tee /etc/iptables/ipset >/dev/null
netfilter-persistent save

# Initial update
$SCRIPT_DIR/update_blocked_domains.sh

echo "Installation complete. Blocking domains from: $DOMAINS_FILE"
