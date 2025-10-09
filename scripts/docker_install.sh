#!/usr/bin/env bash

set -e

if [[ "$EUID" -ne 0 ]]; then
	echo "Run as root!"
	exit 1
fi

apt-get update
apt-get install ca-certificates curl -y
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
docker run hello-world

docker_script="/usr/local/bin/docker_script.sh"

cat << "EOF" > "$docker_script"
#!/usr/bin/env bash

chmod 777 /var/run/docker.sock
chmod 777 /var/run/debugging.sock
EOF

chmod +x "$docker_script"

cat << "EOF" > "/usr/lib/systemd/system/docker.service"
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target nss-lookup.target docker.socket firewalld.service containerd.service time-set.target
Wants=network-online.target containerd.service
Requires=docker.socket
StartLimitBurst=3
StartLimitIntervalSec=60

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock -H unix:///var/run/debugging.sock -H tcp://0.0.0.0:2375
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF

cat << "EOF" > "/usr/lib/systemd/system/docker.socket"
[Unit]
Description=Docker Socket for the API

[Socket]
# If /var/run is not implemented as a symlink to /run, you may need to
# specify ListenStream=/var/run/docker.sock instead.
ListenStream=/run/docker.sock
SocketMode=0777
SocketUser=root
SocketGroup=docker

[Install]
WantedBy=sockets.target
EOF

cat << EOF > "/etc/systemd/system/docker_chmod.service"
[Unit]
Description=Easy docker access
Requires=docker.service
After=docker.service

[Service]
Type=simple
ExecStart=$docker_script

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable --now docker_chmod
$docker_script
systemctl enable --now docker
