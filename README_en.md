<p align="center">
  <a href="#">
    <img src="https://img.shields.io/badge/AutoScript-v5.0-blue.svg" alt="AutoScript Version">
  </a>
  <a href="#7-license">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  </a>
  <a href="README.md">
    <img src="https://img.shields.io/badge/lang-PL-red.svg" alt="Polish">
  </a>
</p>

<h1 align="center">AutoScript: Integrated Server Platform</h1>

**AutoScript is a fully integrated, automated, and secure solution for deploying and managing a complete, multi-service server platform.** This project transforms a "bare" server into a ready-to-use, secure, and monitored environment, capable of hosting a wide range of applications simultaneously.

---

## Table of Contents

1.  [Platform Architecture: Service Overview](#1-platform-architecture-overview)
2.  [Configuration Guide: Key Acquisition](#2-configuration-guide-key-acquisition)
3.  [Installation (Quick Start)](#3-installation-quick-start)
4.  [Command Guide](#4-command-guide)
5.  [Backup and Restore](#5-backup-and-restore)
6.  [Security Aspects](#6-security-aspects)
7.  [License](#7-license)

---

## 1. Platform Architecture: Service Overview

AutoScript builds a comprehensive ecosystem of services, ready to use right after installation:

| Category                 | Service                                      | Role in System                                                                                             |
| ------------------------ | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Social Networks**      | **Mastodon**                                 | Decentralized, federated social network.                                                                   |
| **Discussion Forums**    | **Discourse**                                | Modern, full-featured forum platform.                                                                      |
| **Blog System**          | **WordPress**                                | The world's most popular content management system (CMS), ideal for running a blog or site.                  |
| **RSS Reader**           | **FreshRSS**                                 | Personal news aggregator and RSS feed reader, hosted on your server.                                         |
| **Email Server**         | **Self-hosted mail server**                  | Complete, self-sufficient mail server (IMAP/SMTP) with an admin panel.                                        |
| **Mail Synchronization** | **imapsync**                                 | Tool for bulk email account migration and synchronization between servers.                                   |
| **Monitoring and Status**| **Uptime Kuma**                              | Dashboard for monitoring the availability of all your services with a public status page.                   |
| **Infrastructure**       | **Traefik, Docker, PostgreSQL, etc.**        | Robust foundation consisting of reverse proxy, containerization, and databases.                             |

## 2. Configuration Guide: Key Acquisition

### SSH Key

1. Generate SSH key pair on your local computer:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```
2. Copy the content of the public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
3. Use this content as the `PUBLIC_KEY` value in the configuration file.

### Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Go to **My Profile** > **API Tokens**
3. Click **Create Token** and select the **Custom token** template
4. Set permissions:
   - Zone: Zone:Read
   - Zone: DNS:Edit
5. Select the appropriate DNS zone
6. Copy the generated token as `CF_DNS_API_TOKEN`

### Backup Keys (Backblaze B2)

1. Log in to your [Backblaze](https://www.backblaze.com/) account.
2. Go to **"B2 Cloud Storage"** > **"Buckets"** and create a new private bucket.
3. Go to **"App Keys"** and generate a new application key with access to your bucket. You will need `applicationKeyId` (as `B2_ACCOUNT_ID`) and `applicationKey` (as `B2_ACCOUNT_KEY`).

## 3. Installation: From Zero to a Working Platform

This section is a detailed, complete guide that will take you from zero to a fully operational, secure platform. Execute commands in the given order. We assume you start with a freshly installed server with **Debian 12** or **Ubuntu 22.04+**.

### Step 1: Initial Server Connection

Immediately after creating a server with your hosting provider, you will receive an IP address. Connect to the server as the `root` user using an SSH terminal. On your local computer (Linux, macOS, Windows with WSL or Git Bash), enter:

```bash
ssh root@<YOUR_SERVER_IP>
```

You will be asked for the root password provided by your hosting provider.

### Step 2: Download AutoScript

Once logged in as `root` on the server, your first task is to install `git` (if it's not there) and download the AutoScript code. Execute all the following commands **on the server**.

```bash
# Update the list of available packages and install git
apt update && apt install -y git

# Clone the repository into /root/autoscript folder and navigate into it
git clone https://github.com/pawelorzech/autoscript.git && cd autoscript
```

### Step 3: Platform Configuration

This is the crucial step where you define how your platform will operate. You need to create a configuration file and fill it with your data.

```bash
# Create a copy of the example file
cp autoscript.conf.example autoscript.conf

# Open the configuration file in a simple text editor
nano autoscript.conf
```

The `nano` editor will open. Use the arrows to navigate the file. Carefully fill in **all required variables**, following the instructions from the "Configuration Guide: Key Acquisition" section. Pay special attention to `PUBLIC_KEY`, `CF_DNS_API_TOKEN`, and domains for individual services.

**To save the file and exit the `nano` editor:**
1. Press `Ctrl + X`.
2. Press `Y` (to confirm save).
3. Press `Enter` (to confirm the filename).

### Step 4: Configuration Validation

Before making any changes in the system, run a validation. The script will check if the API keys are correct and if it can connect to the required services. This is your safety net.

```bash
# Make sure you are in the /root/autoscript folder
sudo ./start.sh validate
```

If the validation is successful, you are ready to install. If not, the script will inform you what needs to be corrected in the `autoscript.conf` file.

### Step 5: Installation Initiation

Execute the main installation command. The script will do the rest. Sit back; the process can take several minutes.

```bash
# Make sure you are in the /root/autoscript folder
sudo ./start.sh install
```

The script will install all packages, configure security, deploy all services in Docker containers, and link them into a seamlessly functioning ecosystem.

### Step 6: Post-Installation Steps (Very Important!)

Once the script finishes its work, your server is ready, but its security has been fundamentally changed:

1.  **Logging in as `root` is BLOCKED.**
2.  **SSH Port is CHANGED** to a random number within the range 10000-65535. To find out, execute on the server:
    ```bash
    cat /root/ssh_port.txt
    ```
3.  **A new `admin` user has been created.** From now on, you log in only to this account using your SSH key and the new port. On **your local computer**, execute:
    ```bash
    ssh admin@<YOUR_SERVER_IP> -p <NEW_PORT_FROM_FILE>
    ```
4.  **2FA Configuration (TOTP):** The first time you use `sudo` (e.g., `sudo ls /root`), a QR code will appear on the screen. Scan it with a Google Authenticator or Authy type app and **save backup codes in a safe place!** They are one-time use and necessary to recover access if the phone is lost.

Your platform is now ready to use. Services will be available under the domains configured in the `autoscript.conf` file.

## 4. Command Guide

AutoScript is controlled with simple, logical commands. All commands must be run from the `/root/autoscript` folder with `sudo` privileges.

### Main Commands

- `sudo ./start.sh install`
  **Meta-command used once at the start.** Initiates in the proper order all necessary installation modules: validation, system hardening, deploying Traefik, monitoring, and all configured services. Ideal for quick start.

- `sudo ./start.sh uninstall`
  **VERY DANGEROUS!** This command completely removes **everything** created by AutoScript: containers, application data, Docker volumes, and even uninstalls packages. Use only when you want to entirely clear the server. The script will prompt for confirmation to prevent accidental use.

- `sudo ./start.sh validate`
  **Your safety net.** Checks the correctness of the `autoscript.conf` file, verifies API keys and tokens but **makes no system changes**. Always run this command after configuration changes.

### Service Management Commands

You can manage each service independently. This is useful for redeploying or updating specific components.

- `sudo ./start.sh deploy_mastodon`
- `sudo ./start.sh deploy_discourse`
- `sudo ./start.sh deploy_wordpress`
- `sudo ./start.sh deploy_freshrss`
- `sudo ./start.sh deploy_mail`
- `sudo ./start.sh deploy_status`
- `sudo ./start.sh deploy_monitoring`
- `sudo ./start.sh deploy_traefik`

### Backup Management Commands

- `sudo ./start.sh backup:init`
  Initializes a new, empty backup repository in your Backblaze B2 bucket. **You must do this once before automatic backup works.**

- `sudo ./start.sh backup:run`
  Manually starts the process of creating a new, encrypted backup of the entire `/opt/services` folder.

- `sudo ./start.sh backup:list`
  Displays a list of all available snapshots in your backup repository.

- `sudo ./start.sh backup:restore <SNAPSHOT_ID>`
  Restores the selected snapshot to the `/opt/services.restored` folder. Does not overwrite existing data, giving you full control over the recovery process.

### Utility Commands

- `sudo ./start.sh secrets:edit <service_name>`
  Safely opens an encrypted secret file for a given service (e.g., `mastodon`) in the default editor. After saving, the file is automatically re-encrypted.

- `sudo ./start.sh secrets:view <service_name>`
  Securely displays the decrypted contents of the secret file on screen without saving it anywhere in plain text.

- `sudo ./start.sh self-update`
  Updates the AutoScript to the latest version from the Git repository. It's recommended to run regularly.

## 5. Backup and Restore

AutoScript is fully integrated with `Restic` and `Backblaze B2` to ensure the safety of your data.

- **Automation**: After proper configuration, the script automatically creates a `cron` job that daily performs an encrypted backup of the entire `/opt/services` folder (containing all application data) to your B2 bucket.
- **Recovery**: In the event of a failure, you can use the command `sudo ./start.sh backup:restore <SNAPSHOT_ID>` to recover data.

## 6. Security Aspects: "Secure by Default" Architecture

AutoScript does not take security as an option but as a fundamental element built into every aspect of the platform. Here are the key defense mechanisms that are automatically deployed:

### Operating System Level

- **Minimization of Attack Surface**: The script installs only necessary packages. There is no redundant software that could pose a potential threat.
- **Strengthened Authentication**: Password login to SSH is completely disabled. Access is only possible using cryptographic keys. Additionally, access to `root` privileges (via `sudo`) is protected by two-factor authentication (TOTP).
- **Access Control**: Logging into the `root` account is blocked. The dedicated `admin` user has limited privileges, which can only be elevated using `sudo` (with 2FA verification).
- **Firewall (UFW)**: The firewall is configured in "deny all, allow selected" mode. Only ports necessary for the operation of deployed services are opened.

### Application and Network Level

- **Proactive Intrusion Protection (IPS)**: `CrowdSec` analyzes network behavior and proactively blocks IP addresses known for malicious activity globally. `Fail2ban` additionally monitors logs for brute-force attack attempts.
- **End-to-End Encryption**: All traffic to your services is automatically encrypted with SSL/TLS certificates from Let's Encrypt, managed by Traefik.
- **Container Isolation**: All services run in Docker containers, isolating them from each other and the host system. Additionally, enabling `userns-remap` maps the `root` user inside the container to a regular user on the host, drastically limiting potential damage in case of container "escape."

### Data Level

- **Secret Management (`sops`)**: All sensitive data – API keys, database passwords, tokens – are encrypted on disk using `sops` and the `age` key. They are never stored in plain text.
- **Encrypted Backups**: All backups created by `Restic` are encrypted end-to-end before being sent to an external location (Backblaze B2). Without the repository password, no one can read your data.

## 7. Post-Installation Steps: What Next?

Congratulations! Your platform is fully installed, secured, and ready to work. Here's what you should do now to fully take control of it and start using it.

### 1. First Login and Application Configuration

Each of the installed services is now available under the domain you configured in the `autoscript.conf` file. It's time to visit them and complete their configuration from the web interface.

- **Mastodon (`https://your-domain.ovh`)**: Go to the main page and register your first account. The first registered account automatically receives the instance owner role.
- **Discourse (`https://forum.your-domain.ovh`)**: Like Mastodon, register an admin account to start configuring forum categories and settings.
- **WordPress (`https://blog.your-domain.ovh`)**: Go through the famous "five-minute setup" of WordPress to set up the site title, create an admin account, and start writing.
- **FreshRSS (`https://rss.your-domain.ovh`)**: Log in and start adding your favorite RSS feeds.
- **Mail Server (`https://your-domain.ovh/admin`)**: Log in to the mail admin panel using the `MAIL_ADMIN_PASSWORD` from the configuration file. Here you can add domains and mailboxes.
- **Status Dashboard (`https://status.your-domain.ovh`)**: Configure Uptime Kuma by creating monitors for all your new services to track their availability.

### 2. Access to Data and Secrets

All your application data (databases, uploaded files) are located in the `/opt/services/` folder. You can browse them as the `admin` user.

If you need to check the generated database password or another secret, use the built-in command:

```bash
sudo ./start.sh secrets:view <service_name>
# Example:
sudo ./start.sh secrets:view mastodon
```

### 3. Backup Management

Backups are configured, but it's worth checking their status. You can manually start a backup or list existing snapshots.

```bash
# Manually running a backup
sudo ./start.sh backup:run

# Displaying the list of all backups in the repository
sudo ./start.sh backup:list
```

### 4. System Monitoring

Explore the Grafana dashboard to see how your server is performing.

- **Grafana (`https://grafana.your-domain.ovh`)**: Log in using the `GRAFANA_ADMIN_PASSWORD` from the configuration file. There you'll find pre-configured dashboards showing CPU usage, memory, container status, and much more.
- **Alertmanager (`https://alertmanager.your-domain.ovh`)**: Here you can see active alerts. By default, they are sent to your `ADMIN_EMAIL`.

### 5. Updates

Remember to regularly update both the operating system and the AutoScript itself.

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update AutoScript to the latest version
sudo ./start.sh self-update
```

Your platform is now fully in your hands. Experiment, create, and enjoy the freedom of having your own, powerful infrastructure!

## 8. License

The project is available under the MIT license.
