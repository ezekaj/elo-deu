#!/bin/bash

echo "==================================="
echo "Cloudflare Tunnel Setup for Sofia"
echo "==================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "Please don't run this script as root"
   exit 1
fi

# Step 1: Install cloudflared
echo "Step 1: Installing cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
    echo "✅ cloudflared installed"
else
    echo "✅ cloudflared already installed"
fi

# Step 2: Create config directory
echo ""
echo "Step 2: Creating configuration directory..."
mkdir -p ~/.cloudflared
echo "✅ Config directory created"

# Step 3: Login to Cloudflare
echo ""
echo "Step 3: Cloudflare Authentication"
echo "================================="
echo "You'll need a Cloudflare account (free)."
echo "The next command will open a browser to authenticate."
echo ""
read -p "Press Enter to continue..."
cloudflared tunnel login

# Step 4: Create tunnel
echo ""
echo "Step 4: Creating tunnel..."
cloudflared tunnel create sofia-dental

# Get tunnel ID
TUNNEL_ID=$(cloudflared tunnel list | grep sofia-dental | awk '{print $1}')
echo "✅ Tunnel created with ID: $TUNNEL_ID"

# Step 5: Create configuration
echo ""
echo "Step 5: Creating tunnel configuration..."
cat > ~/.cloudflared/config.yml << EOF
tunnel: sofia-dental
credentials-file: /home/$USER/.cloudflared/${TUNNEL_ID}.json

ingress:
  # Calendar application
  - hostname: sofia-calendar.localhost.com
    service: http://localhost:3005
    originRequest:
      noTLSVerify: true
  # LiveKit WebSocket
  - hostname: sofia-livekit.localhost.com
    service: ws://localhost:7880
    originRequest:
      noTLSVerify: true
  # Default catch-all
  - service: http_status:404
EOF

echo "✅ Configuration created"

# Step 6: DNS instructions
echo ""
echo "Step 6: DNS Configuration"
echo "========================"
echo "You need to add CNAME records in your Cloudflare dashboard:"
echo ""
echo "1. Go to your Cloudflare dashboard"
echo "2. Select your domain"
echo "3. Go to DNS settings"
echo "4. Add these CNAME records:"
echo "   - Name: sofia-calendar → Target: ${TUNNEL_ID}.cfargotunnel.com"
echo "   - Name: sofia-livekit → Target: ${TUNNEL_ID}.cfargotunnel.com"
echo ""
echo "Or use these subdomains if you don't have a domain:"
echo "   - ${TUNNEL_ID}.cfargotunnel.com"
echo ""
read -p "Press Enter when DNS is configured..."

# Step 7: Create systemd service
echo ""
echo "Step 7: Creating systemd service..."
sudo tee /etc/systemd/system/cloudflared.service > /dev/null << EOF
[Unit]
Description=Cloudflare Tunnel for Sofia Dental
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
ExecStart=/usr/bin/cloudflared tunnel run sofia-dental
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
echo "✅ Systemd service created"

echo ""
echo "================================"
echo "Setup Complete!"
echo "================================"
echo ""
echo "To start the tunnel:"
echo "  sudo systemctl start cloudflared"
echo ""
echo "To enable auto-start on boot:"
echo "  sudo systemctl enable cloudflared"
echo ""
echo "To check status:"
echo "  sudo systemctl status cloudflared"
echo ""
echo "Your services will be available at:"
echo "  - https://sofia-calendar.your-domain.com"
echo "  - wss://sofia-livekit.your-domain.com"
echo ""