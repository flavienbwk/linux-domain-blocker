#!/bin/bash
set -e

IPSET_NAME="blocked_domains"
DOMAINS_FILE="/etc/linux-domain-blocker/domains.list"

# Read domains
mapfile -t DOMAINS < <(grep -v '^#' $DOMAINS_FILE | grep -v '^$')

# Temporary sets
TMP4="tmp4_${IPSET_NAME}"
TMP6="tmp6_${IPSET_NAME}"

# Create temporary sets
ipset create $TMP4 hash:ip family inet timeout 300 2>/dev/null || true
ipset create $TMP6 hash:ip family inet6 timeout 300 2>/dev/null || true

# Resolve domains
for domain in "${DOMAINS[@]}"; do
    # IPv4
    ips4=$(dig +short "$domain" A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    for ip in $ips4; do
        ipset add $TMP4 "$ip" 2>/dev/null
    done
    
    # IPv6
    ips6=$(dig +short "$domain" AAAA | grep -E '^[0-9a-fA-F:]+$')
    for ip in $ips6; do
        ipset add $TMP6 "$ip" 2>/dev/null
    done
done

# Atomic swap
ipset swap $TMP4 $IPSET_NAME
ipset swap $TMP6 ${IPSET_NAME}-v6

# Cleanup
ipset destroy $TMP4 2>/dev/null || true
ipset destroy $TMP6 2>/dev/null || true

# Save for persistence
ipset save > /etc/iptables/ipset
ipset save > /etc/iptables/ipset-v6

exit 0
