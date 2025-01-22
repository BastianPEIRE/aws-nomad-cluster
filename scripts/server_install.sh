#!/bin/bash

# Install utilities
sudo yum install -y yum-utils shadow-utils

# Add HashiCorp repo and install Consul
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install consul

# Add HashiCorp repo and install Nomad
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install nomad

# Create Consul configuration
sudo mkdir -p /etc/consul.d
cat <<EOF | sudo tee /etc/consul.d/consul.hcl
datacenter = "dc1"
data_dir = "/opt/consul"
log_level = "INFO"
node_name = "$(hostname)"
server = true
bootstrap_expect = 1

ui_config {
  enabled = true
}
EOF

sudo mkdir -p /opt/consul

# Create Nomad configuration
sudo mkdir -p /etc/nomad.d
cat <<EOF | sudo tee /etc/nomad.d/nomad.hcl
datacenter = "dc1"
data_dir = "/opt/nomad"
bind_addr = "0.0.0.0"

server {
  enabled          = true
  bootstrap_expect = 1
}

EOF

sudo mkdir -p /opt/nomad

# Set permissions for the configuration files
sudo chmod 640 /etc/consul.d/consul.hcl
sudo chmod 640 /etc/nomad.d/nomad.hcl
sudo chown -R nomad:nomad /opt/nomad
sudo chmod +x /usr/bin/nomad

# Create systemd service file for Consul
cat <<EOF | sudo tee /etc/systemd/system/consul.service
[Unit]
Description=Consul
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

# Create systemd service file for Nomad
cat <<EOF | sudo tee /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/nomad agent -config=/etc/nomad.d
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
Restart=on-failure
User=nomad
Group=nomad
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to recognize the new services
sudo systemctl daemon-reload

# Enable and start Consul
sudo systemctl enable consul
sudo systemctl start consul

# Enable and start Nomad
sudo systemctl enable nomad
sudo systemctl start nomad

# Check statuses
sudo systemctl status consul
sudo systemctl status nomad

exit 0
