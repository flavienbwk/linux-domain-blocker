#!/bin/bash
set -e

IPSET_NAME="blocked_domains"
DOMAINS_FILE="/etc/linux-domain-blocker/domains.list"

# Read domains from file
mapfile -t DOMAINS < <(grep -v '^#' $DOMAINS_FILE | grep -v '^$')

# Temporary set for atomic updates
TMP_SET="tmp_${IPSET_NAME}"

# Create temporary set
sudo ipset create $TMP_SET hash:ip timeout 300 2>/dev/null || true

# Resolve domains and add to temporary set
for domain in "${DOMAINS[@]}"; do
    ips=$(dig +short "$domain" A "$domain" AAAA | grep -P '^(\d{1,3}\.){3}\d{1,3}|([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}')
    
    for ip in $ips; do
        sudo ipset add $TMP_SET "$ip" 2>/dev/null
    done
done

# Swap sets atomically
sudo ipset swap $TMP_SET $IPSET_NAME
sudo ipset destroy $TMP_SET

exit 0
