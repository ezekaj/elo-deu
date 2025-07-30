#!/bin/bash
# Fix cloudflared configuration

echo "Fixing cloudflared setup..."

# Kill all cloudflared processes
echo "Stopping all cloudflared processes..."
pkill -f cloudflared || true
sleep 2

# Copy config to system location
echo "Copying configuration..."
sudo cp /home/elo/elo-deu/fixed-config.yml /etc/cloudflared/config.yml
sudo cp /home/elo/.cloudflared/b2367174-aec8-4b55-9f57-6ecd2771e235.json /etc/cloudflared/

# Update service to use the correct config
echo "Updating systemd service..."
sudo tee /etc/systemd/system/cloudflared.service > /dev/null << 'EOF'
[Unit]
Description=cloudflared
After=network.target

[Service]
TimeoutStartSec=0
Type=notify
ExecStart=/usr/bin/cloudflared --config /etc/cloudflared/config.yml tunnel run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Reload and start service
echo "Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl restart cloudflared

echo "Waiting for service to start..."
sleep 5

# Check status
sudo systemctl status cloudflared --no-pager

echo ""
echo "Testing connectivity..."
curl -s -I https://elosofia.site | head -5 || echo "Still waiting for DNS/tunnel..."

echo ""
echo "Done! Your site should be accessible at:"
echo "- https://elosofia.site"
echo "- https://crm.elosofia.site"