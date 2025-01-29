#!/bin/bash

SERVER_IP=$1

mkdir -p /opt/alloc_mounts
chown -R nomad:nomad /opt/alloc_mounts
chmod -R 755 /opt/alloc_mounts

# Install utilities
yum install -y yum-utils shadow-utils

# Add HashiCorp repo and install Consul
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install consul

# Add HashiCorp repo and install Nomad
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install nomad


# Docker installation
amazon-linux-extras enable docker
yum install -y docker

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Set permissions for the user
usermod -G docker -a nomad
usermod -aG docker nomad

# Install CNI plugin
ARCH_CNI=$( [ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "amd64" )
CNI_PLUGIN_VERSION="v1.6.2"

CNI_URL="https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-linux-${ARCH_CNI}-${CNI_PLUGIN_VERSION}.tgz"
curl -L -o cni-plugins.tgz "$CNI_URL"

mkdir -p /opt/cni/bin
tar -C /opt/cni/bin -xzf cni-plugins.tgz

# Set the tunable parameters to allow iptables processing for the bridge network.
echo 1 > /proc/sys/net/bridge/bridge-nf-call-arptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables

cat <<EOF | tee /etc/sysctl.d/bridge.conf
net.bridge.bridge-nf-call-arptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# CNI Create CNI configuration
cat <<EOF | tee /etc/cni/net.d/network-1.conf
{
  "cniVersion": "0.4.0",
  "name": "nomad-bridge",
  "type": "bridge",
  "bridge": "nomad0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [
        {
          "subnet": "10.0.0.0/16",
          "rangeStart": "10.0.1.1",
          "rangeEnd": "10.0.255.254",
          "gateway": "10.0.0.1"
        }
      ]
    ],
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
EOF

# Create Consul configuration
mkdir -p /etc/consul.d
cat <<EOF | tee /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
log_level = "INFO"
node_name = "$(hostname -I | awk '{print $1}')"
client_addr = "0.0.0.0"
retry_join = ["$SERVER_IP"]
bind_addr = "$(hostname -I | awk '{print $1}')"
advertise_addr = "$(hostname -I | awk '{print $1}')"
EOF

mkdir -p /opt/consul

# Create Nomad configuration
mkdir -p /etc/nomad.d
cat <<EOF | tee /etc/nomad.d/nomad.hcl
datacenter = "dc1"
data_dir = "/opt/nomad"
bind_addr = "0.0.0.0"

advertise {
  http = "$(hostname -I | awk '{print $1}')"
  rpc  = "$(hostname -I | awk '{print $1}')"
  serf = "$(hostname -I | awk '{print $1}')"
}

client {
  enabled = true
  servers = ["$SERVER_IP"]
  cni_path = "/opt/cni/bin"
  cni_config_dir = "/etc/cni/net.d"
}

plugin "docker" {
  config {
    allow_privileged = true
    allow_caps       = ["audit_write", "chown", "dac_override", "fowner", "fsetid", "kill", "mknod", "net_bind_service", "setfcap", "setgid", "setpcap", "setuid", "sys_chroot", "net_admin"]
    volumes {
      enabled = true
    }
  }
}

EOF

mkdir -p /opt/nomad

# Set permissions for the configuration files
chown -R nomad:nomad /etc/cni/
chmod 750 /etc/cni/net.d
chmod -R 755 /etc/cni/net.d/
chmod 640 /etc/consul.d/consul.hcl
chmod 640 /etc/nomad.d/nomad.hcl
chown -R nomad:nomad /opt/nomad
chmod +x /opt/cni/bin/*
chmod +x /usr/bin/nomad
setcap cap_net_admin+ep /usr/bin/nomad

# Create systemd service file for Consul (Client Mode)
cat <<EOF | tee /etc/systemd/system/consul.service
[Unit]
Description=Consul Client
Documentation=https://www.consul.io/
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
Restart=on-failure
User=consul
Group=consul
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service file for Nomad (Client Mode)
cat <<EOF | tee /etc/systemd/system/nomad.service
[Unit]
Description=Nomad Client
Documentation=https://www.nomadproject.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/nomad agent -config=/etc/nomad.d
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
Restart=on-failure
User=root
Group=root
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


setcap cap_net_admin+ep /usr/bin/nomad

# Reload systemd to recognize the new services
systemctl daemon-reload

# Enable and start Consul
systemctl enable consul
systemctl start consul

# Enable and start Nomad
systemctl enable nomad
systemctl start nomad

# Check statuses
systemctl status consul
systemctl status nomad

exit 0
