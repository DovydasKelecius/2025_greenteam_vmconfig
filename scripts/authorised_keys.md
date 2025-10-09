#!/bin/bash

set -e

echo "Setting up SSH authorized_keys misconfiguration vulnerability..."

# Create /root/.ssh if needed
sudo mkdir -p /root/.ssh

# Add dummy noise key if not exists
if [ ! -s /root/.ssh/authorized_keys ]; then
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... admin@fo1" | sudo tee /root/.ssh/authorized_keys > /dev/null
fi

# Set vuln perms
sudo chmod 777 /root/.ssh
sudo chmod 666 /root/.ssh/authorized_keys
sudo chown -R root:root /root/.ssh

# Configure sshd_config if needed
SSHD_CONFIG="/etc/ssh/sshd_config"
sudo cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"  # Backup
if ! sudo grep -q "^PermitRootLogin yes" "$SSHD_CONFIG"; then
    echo "PermitRootLogin yes" | sudo tee -a "$SSHD_CONFIG" > /dev/null
fi
if ! sudo grep -q "^PubkeyAuthentication yes" "$SSHD_CONFIG"; then
    echo "PubkeyAuthentication yes" | sudo tee -a "$SSHD_CONFIG" > /dev/null
fi
if ! sudo grep -q "^PasswordAuthentication yes" "$SSHD_CONFIG"; then
    echo "PasswordAuthentication yes" | sudo tee -a "$SSHD_CONFIG" > /dev/null
fi

sudo systemctl restart ssh
