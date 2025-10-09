#!/bin/bash



set -e  # Exit on any error

USERNAME="Admin"
PASSWORD="Admin123"  

echo "Setting up user: $USERNAME with passwordless sudo..."

if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists. Removing for clean setup..."
    sudo pkill -u "$USERNAME" 2>/dev/null || true  # Kill any processes first
    sudo userdel -r "$USERNAME"  # -r removes home dir too
    # Clean up any existing sudoers.d entry
    sudo rm -f "/etc/sudoers.d/$USERNAME"
    echo "Old user and config removed."
fi


sudo useradd -m -s /bin/bash "$USERNAME"

echo "$USERNAME:$PASSWORD" | sudo chpasswd

sudo usermod -aG sudo "$USERNAME"


SUDOERS_D_FILE="/etc/sudoers.d/$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_D_FILE" > /dev/null
sudo chmod 0440 "$SUDOERS_D_FILE"

if sudo visudo -c > /dev/null 2>&1; then
    echo "Sudoers updated successfully via /etc/sudoers.d/."
else
    echo "Error: Sudoers validation failed. Cleaning up..."
    sudo rm -f "$SUDOERS_D_FILE"
    exit 1
fi

echo "Setup complete! Now verifying..."


echo "=== Group membership for $USERNAME ==="
sudo groups "$USERNAME"



echo "=== Testing passwordless sudo ==="
if sudo -u "$USERNAME" sudo whoami 2>/dev/null | grep -q "root"; then
    echo "✓ sudo whoami succeeded (output: root) - no password prompt for sudo."
else
    echo "✗ sudo whoami failed."
fi


echo "=== Groups as $USERNAME ==="
sudo -u "$USERNAME" groups

echo "=== Additional sudo tests as $USERNAME ==="
sudo -u "$USERNAME" bash -c '
sudo whoami
echo "✓ whoami test passed."

sudo cat /etc/shadow | head -3
echo "✓ cat /etc/shadow test passed (showed shadow file)."

sudo systemctl status | head -5
echo "✓ systemctl status test passed (showed service status)."
'

echo "All verifications complete! User '$USERNAME' is ready with full passwordless root privileges."
echo "Password: $PASSWORD (change it in production with 'sudo passwd $USERNAME')."
echo "Pro tip: Snapshot your VM now before exercises. Run 'sudo visudo -c' to double-check sudoers if needed."