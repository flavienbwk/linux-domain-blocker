# Domain Blocker for Linux 🚫🌐

Block outgoing connections to specific domains on your machine - using only native Linux tools!  
This project leverages **ipset** and **iptables** to block all traffic to domains you specify, automatically updating IPs as DNS changes.

## ✨ Features

- **Blocks outgoing connections** to any domains you list
- **Automatic updates:** Keeps up with DNS changes
- **No third-party libraries:** Only standard Linux tools
- **Idempotent and safe:** Won't duplicate rules or sets
- **Easy to manage:** Just edit a text file to add/remove domains

## 🚀 Installation

1. Clone the Repository

    ```bash
    git clone https://github.com/flavienbwk/linux-domain-blocker.git
    cd linux-domain-blocker
    ```

2. List Domains to Block

    Edit the [`domains.list`](./domains.list) file and add one domain per line:

    ```bash
    example.com
    malicious-domain.net
    ```

3. Run the Installer Script

    ```bash
    chmod +x install.sh
    sudo ./install.sh
    ```

   - This will:
     - Install required packages
     - Set up the `blocked_domains` ipset
     - Add the iptables rule (if not already present)
     - Copy scripts and domain list to `/etc/linux-domain-blocker/`
     - Set up a cron job to update the blocklist every 5 minutes
     - Persist rules across reboots

4. Verify Blocking

    Check the current blocked IPs:

    ```bash
    sudo ipset list blocked_domains
    ```

    Check the iptables rule:

    ```bash
    sudo iptables -L OUTPUT -v --line-numbers
    ```

5. Update Blocked Domains

   - Edit `/etc/linux-domain-blocker/domains.list` to add or remove domains.
   - The script will automatically update the blocklist every 5 minutes, or you can run:

   ```bash
   sudo /etc/linux-domain-blocker/update_blocked_domains.sh
   ```

## 🛠️ How It Works

1. **Reads your domain list**
2. **Resolves each domain's IPs**
3. **Updates an ipset** with those IPs (removes old ones)
4. **iptables blocks outgoing traffic** to all IPs in the set

## 📝 Notes

- IPv4 and IPv6 addresses are both supported.
- For advanced use, see the scripts for customization.
- Rules and sets are idempotent - safe to run multiple times.

## 🧑‍💻 Contributing

Pull requests and suggestions welcome!  
See [issues](https://github.com/flavienbwk/linux-domain-blocker/issues) for ideas or to report problems.
