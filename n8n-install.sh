#!/bin/bash
# ======================================================
# n8n Auto Installer on Docker with SSL + Nginx
# Author: hodacloud.com
# ======================================================

set -e

# -------------------------------
# Step 1: Check root privileges
# -------------------------------
echo -e "\033[1;36m[Step 1] Checking root privileges...\033[0m"
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[1;31mPlease run this script as root (sudo).\033[0m"
  exit 1
fi
echo -e "\033[1;32m✔ Root privileges confirmed\033[0m"

# -------------------------------
# Step 2: Check Docker and Docker Compose
# -------------------------------
echo -e "\n\033[1;36m[Step 2] Checking Docker and Docker Compose...\033[0m"
if ! command -v docker &> /dev/null; then
  echo -e "\033[1;31m✘ Docker is not installed! Please install Docker first.\033[0m"
  exit 1
else
  docker --version
fi

# Flag for docker-compose binary
COMPOSE_CMD=""

if command -v docker &> /dev/null && docker compose version &> /dev/null; then
  docker compose version
  COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
  docker-compose --version
  COMPOSE_CMD="docker-compose"
else
  echo -e "\033[1;31m✘ Neither 'docker compose' nor 'docker-compose' is installed!\033[0m"
  exit 1
fi

echo -e "\033[1;32m✔ Docker and Compose available ($COMPOSE_CMD)\033[0m"

# -------------------------------
# Step 3: Get domain from user
# -------------------------------
echo -e "\n\033[1;36m[Step 3] Getting domain name...\033[0m"
read -p "Enter your domain (example: n8n.example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
  echo -e "\033[1;31m✘ Domain not provided!\033[0m"
  exit 1
fi

# -------------------------------
# Step 4: Create installation directory
# -------------------------------
echo -e "\n\033[1;36m[Step 4] Creating installation directory...\033[0m"
mkdir -p /root/n8n && cd /root/n8n
echo -e "\033[1;32m✔ Directory /root/n8n created\033[0m"

# -------------------------------
# Step 5: Create .env file
# -------------------------------
echo -e "\n\033[1;36m[Step 5] Creating .env file...\033[0m"
cat > .env <<EOF
# domain and protocol
N8N_HOST=$DOMAIN
N8N_PROTOCOL=https
WEBHOOK_TUNNEL_URL=https://$DOMAIN

N8N_PORT=443

N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=foreveraluku
N8N_BASICAUTH_PASSWORD=Foreverage1294

GENERIC_TIMEZONE=Asia/Tehran
EOF
echo -e "\033[1;32m✔ .env file created\033[0m"

# -------------------------------
# Step 6: Create docker-compose.yml
# -------------------------------
echo -e "\n\033[1;36m[Step 6] Creating docker-compose.yml...\033[0m"
cat > docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:443"
    env_file:
      - .env
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n_network

volumes:
  n8n_data:

networks:
  n8n_network:
    driver: bridge
EOF
echo -e "\033[1;32m✔ docker-compose.yml created\033[0m"

# -------------------------------
# Step 7: Check port 80
# -------------------------------
echo -e "\n\033[1;36m[Step 7] Checking port 80...\033[0m"
if lsof -i:80 &>/dev/null; then
  PID=$(lsof -ti:80)
  echo -e "\033[1;31m✘ Port 80 is in use. PID: $PID\033[0m"
  read -p "Do you want to kill this process? (y/n): " CHOICE
  if [[ "$CHOICE" == "y" ]]; then
    kill -9 $PID
    echo -e "\033[1;32m✔ Process killed\033[0m"
  else
    echo -e "\033[1;31m✘ Port 80 must be free to continue.\033[0m"
    exit 1
  fi
else
  echo -e "\033[1;32m✔ Port 80 is free\033[0m"
fi

# -------------------------------
# Step 8: Install Snap and Certbot
# -------------------------------
echo -e "\n\033[1;36m[Step 8] Installing Snap and Certbot...\033[0m"
apt update -y
apt install -y snapd
snap install core && snap refresh core
snap install --classic certbot

# Create symlink only if it doesn't exist
if [ ! -e /usr/bin/certbot ]; then
  ln -s /snap/bin/certbot /usr/bin/certbot
fi

# -------------------------------
# Step 9: Obtain SSL Certificate
# -------------------------------
echo -e "\n\033[1;36m[Step 9] Obtaining SSL certificate with Certbot...\033[0m"
read -p "Enter your email for Certbot (can be empty): " EMAIL
if [ -z "$EMAIL" ]; then
  certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email
else
  certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
fi
echo -e "\033[1;32m✔ SSL certificate issued\033[0m"

# -------------------------------
# Step 10: Install and configure Nginx
# -------------------------------
echo -e "\n\033[1;36m[Step 10] Installing and configuring Nginx...\033[0m"
apt install -y nginx

cat > /etc/nginx/sites-available/n8n <<EOF
server {
    listen 80;
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    client_max_body_size 50M;

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        client_max_body_size 50M;
    }
}
EOF

ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx && systemctl enable nginx
echo -e "\033[1;32m✔ Nginx installed and configured\033[0m"

# -------------------------------
# Step 11: Start Docker Compose
# -------------------------------
echo -e "\n\033[1;36m[Step 11] Starting n8n with $COMPOSE_CMD...\033[0m"
cd /root/n8n
$COMPOSE_CMD up -d
echo -e "\033[1;32m✔ n8n started successfully\033[0m"

# -------------------------------
# Finish
# -------------------------------
echo -e "\n\033[1;35m✅ n8n installation completed successfully!\033[0m"
echo -e "\033[1;33mAccess your instance at: https://$DOMAIN\033[0m"

echo -e "\n\033[1;35mAuthor: hodacloud.com!\033[0m"
