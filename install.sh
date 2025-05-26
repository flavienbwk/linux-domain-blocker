#!/bin/bash
set -e

# Configuration
IPSET_NAME="blocked_domains"
DOMAINS_FILE="/etc/linux-domain-blocker/domains.list"
SCRIPT_DIR="/etc/linux-domain-blocker"

# Install core dependencies
if ! dpkg -s ipset >/dev/null 2>&1 || ! dpkg -s dnsutils >/dev/null 2>&1; then
    apt-get update
    apt-get install -y --no-install-recommends ipset dnsutils
fi

# Detect UFW
UFW_ACTIVE=false
if command -v ufw >/dev/null && ufw status | grep -q 'active'; then
    UFW_ACTIVE=true
fi

# Create ipset (atomic update compatible)
ipset create $IPSET_NAME hash:ip family inet timeout 300 2>/dev/null || true
ipset create $IPSET_NAME-v6 hash:ip family inet6 timeout 300 2>/dev/null || true

# Main blocking rules
iptables -I OUTPUT -m set --match-set $IPSET_NAME dst -j DROP
ip6tables -I OUTPUT -m set --match-set $IPSET_NAME-v6 dst -j DROP

# Docker container blocking
iptables -I DOCKER-USER -m set --match-set $IPSET_NAME src -j DROP || true
ip6tables -I DOCKER-USER -m set --match-set $IPSET_NAME-v6 src -j DROP || true

# Docker - Allow established connections first
iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT || true

# UFW-specific configuration
if $UFW_ACTIVE; then
    # Only add rules if they are not already present
    if ! grep -q "# domain-blocker-rule (ipv4)" /etc/ufw/after.rules; then
        tee -a /etc/ufw/after.rules >/dev/null <<EOL

# domain-blocker-rule (ipv4)
-A ufw-after-output -m set --match-set $IPSET_NAME dst -j DROP
EOL
    fi
    if ! grep -q "# domain-blocker-rule (ipv6)" /etc/ufw/after6.rules; then
        tee -a /etc/ufw/after6.rules >/dev/null <<EOL

# domain-blocker-rule (ipv6)
-A ufw6-after-output -m set --match-set $IPSET_NAME-v6 dst -j DROP
EOL
    fi
    ufw reload
fi

# Persistence setup
mkdir -p $SCRIPT_DIR
cp update_blocked_domains.sh $SCRIPT_DIR/
chmod +x $SCRIPT_DIR/update_blocked_domains.sh

# Install domains list
[ -f domains.list ] && cp domains.list $DOMAINS_FILE

# Create systemd service
tee /etc/systemd/system/linux-domain-blocker.service >/dev/null <<EOL
[Unit]
Description=Domain Blocker IPSet Restore
After=network.target
Before=ufw.service

[Service]
Type=oneshot
ExecStartPre=-/sbin/ipset create blocked_domains hash:ip family inet timeout 300
ExecStart=/sbin/ipset restore -file /etc/iptables/ipset

[Install]
WantedBy=multi-user.target
EOL

# Enable services
systemctl daemon-reload
systemctl enable linux-domain-blocker.service

# Cron job
if ! crontab -l | grep -q "$SCRIPT_DIR/update_blocked_domains.sh"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * $SCRIPT_DIR/update_blocked_domains.sh") | crontab -
fi

# Initial update
$SCRIPT_DIR/update_blocked_domains.sh

echo "Installation complete. Blocking domains from: $DOMAINS_FILE"
