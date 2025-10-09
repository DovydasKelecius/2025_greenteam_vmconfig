#!/bin/bash

set -e

echo "Configuring NGINX to run as root..."

if ! command -v nginx &> /dev/null; then
    sudo apt update
    sudo apt install -y nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "NGINX installed and started."
else
    echo "NGINX already installed."
fi

sudo sed -i 's/user www-data;/user root;/' /etc/nginx/nginx.conf

if sudo nginx -t > /dev/null 2>&1; then
    sudo systemctl reload nginx
    echo "NGINX configured to run as root and reloaded."
else
    echo "NGINX config test failed."
    exit 1
fi

echo "Setup complete! Now verifying..."

echo "=== Verifying NGINX runs as root ==="
if sudo ps aux | grep -q "[n]ginx: master process.*root"; then
    echo "✓ NGINX master process running as root (vulnerability created)."
else
    echo "✗ NGINX not running as root."
fi

sudo ps aux | grep nginx | head -3

echo "All verifications complete! NGINX runs as root for vuln testing."
