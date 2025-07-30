#!/bin/bash
# Update cloudflared service configuration

echo "Updating cloudflared service..."

# Create systemd override directory
sudo mkdir -p /etc/systemd/system/cloudflared.service.d

# Create override configuration
sudo tee /etc/systemd/system/cloudflared.service.d/override.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/cloudflared --config /home/elo/.cloudflared/config.yml --no-autoupdate tunnel run
EOF

# Reload systemd and restart service
sudo systemctl daemon-reload
sudo systemctl restart cloudflared
sudo systemctl status cloudflared

echo "Service updated!"