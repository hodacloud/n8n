# n8n
This script automatically installs and configures n8n on Docker, requests the user’s domain, generates an SSL certificate via Certbot, sets up Nginx as a reverse proxy, and finally launches the n8n service using Docker Compose for a secure and ready-to-use workflow automation platform.

# n8n Auto Installer on Docker + SSL + Nginx

This script automatically installs and configures **n8n** on Docker with SSL and Nginx.  
It creates the required environment files, generates an SSL certificate using Certbot, configures Nginx as a reverse proxy, and launches n8n with Docker Compose.  

---

## Requirements

- **Docker & Docker Compose** must be installed. You can install them in two ways:

1. Using the official Docker installer:
   ```bash
   bash <(curl -sSL https://get.docker.com)
2. Or via Snap:
   ```bash
   apt install snapd -y
   snap install docker

# A domain or subdomain must be pointed to your server.


## Installation

Once the requirements are met, simply run the following command as root:
   ```bash
   bash <(curl -Ls https://raw.githubusercontent.com/hodacloud/n8n/refs/heads/main/n8n-install.sh)
