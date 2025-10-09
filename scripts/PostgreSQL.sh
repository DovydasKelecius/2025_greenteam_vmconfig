#!/usr/bin/env bash

set -e

if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root!"
    exit 1
fi

apt update -y
apt install postgresql -y

# --- FIX START: Dynamic version detection ---

# Find the latest installed PostgreSQL version directory (e.g., "16")
# This command finds all directories in /etc/postgresql/, sorts them numerically, and takes the last one.
POSTGRES_VERSION_DIR=$(find /etc/postgresql -maxdepth 1 -type d -regextype posix-extended -regex ".*/[0-9]+$" | sort -V | tail -n 1)

# Check if a version directory was found
if [ -z "$POSTGRES_VERSION_DIR" ]; then
    echo "Error: Could not find a PostgreSQL version directory in /etc/postgresql/. Installation may have failed."
    exit 1
fi

# The main configuration path is the found directory + /main/
POSTGRES_CONF_PATH="$POSTGRES_VERSION_DIR/main"

echo "Detected PostgreSQL configuration path: $POSTGRES_CONF_PATH"

# --- FIX END ---


# 1. Modify postgresql.conf to listen on all addresses
# Using the dynamic path: "$POSTGRES_CONF_PATH/postgresql.conf"
sed -i "s/^.*listen_addresses =.*$/listen_addresses = '*'/" "$POSTGRES_CONF_PATH/postgresql.conf"


# 2. Overwrite pg_hba.conf to allow remote connections (vulnerability setup: "trust" on local network)
# Using the dynamic path: "$POSTGRES_CONF_PATH/pg_hba.conf"
cat << "EOF" > "$POSTGRES_CONF_PATH/pg_hba.conf"
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Allow all local connections (Unix domain socket and 127.0.0.1)
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256

# VULNERABILITY: Allow all IPv4 remote connections (0.0.0.0/0) using 'trust' authentication
# This means anyone on the network can connect without a password.
host    all             all             0.0.0.0/0               trust

# Allow replication connections from localhost (default secure settings)
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
EOF

# 3. Apply firewall rules and restart service
ufw allow 5432/tcp
ufw reload
systemctl daemon-reload
systemctl restart postgresql
