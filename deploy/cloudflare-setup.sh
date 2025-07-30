#!/bin/bash
# Cloudflare Tunnel Setup for elosofia.site

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🌐 Setting up Sofia at elosofia.site${NC}"
echo "======================================="
echo ""

# Install cloudflared if not present
if ! command -v cloudflared &> /dev/null; then
    echo "Installing Cloudflare Tunnel..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
    echo -e "${GREEN}✅ Cloudflare Tunnel installed${NC}"
fi

# Start Sofia services first
echo -e "${BLUE}Starting Sofia services...${NC}"
cd /home/elo/elo-deu
docker-compose up -d

# Wait for services
echo "Waiting for services to start..."
sleep 10

# Login to Cloudflare
echo ""
echo -e "${YELLOW}⚠️  You'll be redirected to Cloudflare to login${NC}"
echo "After login, return to this terminal"
echo ""
read -p "Press Enter to continue..."

cloudflared tunnel login

# Create tunnel
echo -e "${BLUE}Creating tunnel...${NC}"
cloudflared tunnel create elosofia

# Get tunnel ID
TUNNEL_ID=$(cloudflared tunnel list | grep elosofia | awk '{print $1}')
echo "Tunnel ID: $TUNNEL_ID"

# Create config file
echo -e "${BLUE}Creating tunnel configuration...${NC}"
mkdir -p ~/.cloudflared

cat > ~/.cloudflared/config.yml << EOF
tunnel: elosofia
credentials-file: /home/$USER/.cloudflared/$TUNNEL_ID.json

ingress:
  # Main calendar interface
  - hostname: elosofia.site
    service: http://localhost:3005
  - hostname: app.elosofia.site
    service: http://localhost:3005
    
  # WebSocket for voice
  - hostname: ws.elosofia.site
    service: ws://localhost:7880
    
  # CRM Dashboard
  - hostname: crm.elosofia.site
    service: http://localhost:5000
    
  # 404 for everything else
  - service: http_status:404
EOF

echo -e "${GREEN}✅ Configuration created${NC}"

# Update frontend to use the domain
echo -e "${BLUE}Updating frontend configuration...${NC}"
sed -i "s|ws://localhost:7880|wss://ws.elosofia.site|g" dental-calendar/public/sofia-real-connection.js
sed -i "s|http://localhost:3005|https://elosofia.site|g" dental-calendar/public/sofia-real-connection.js

# Restart calendar to apply changes
docker-compose restart dental-calendar

echo ""
echo -e "${BLUE}📝 DNS Configuration for Namecheap${NC}"
echo "===================================="
echo ""
echo -e "${YELLOW}Add these DNS records in your Namecheap dashboard:${NC}"
echo ""
echo "1. Go to: https://ap.www.namecheap.com/domains/domaincontrolpanel/elosofia.site/advancedns"
echo ""
echo "2. Add these CNAME records:"
echo ""
echo "   Type: CNAME    Host: @          Value: $TUNNEL_ID.cfargotunnel.com"
echo "   Type: CNAME    Host: app        Value: $TUNNEL_ID.cfargotunnel.com"
echo "   Type: CNAME    Host: ws         Value: $TUNNEL_ID.cfargotunnel.com"
echo "   Type: CNAME    Host: crm        Value: $TUNNEL_ID.cfargotunnel.com"
echo ""
echo -e "${YELLOW}⏱️  DNS propagation takes 5-30 minutes${NC}"
echo ""
read -p "Press Enter after adding DNS records..."

# Create the routes
echo -e "${BLUE}Creating Cloudflare routes...${NC}"
cloudflared tunnel route dns elosofia elosofia.site
cloudflared tunnel route dns elosofia app.elosofia.site
cloudflared tunnel route dns elosofia ws.elosofia.site
cloudflared tunnel route dns elosofia crm.elosofia.site

# Start tunnel as service
echo -e "${BLUE}Installing tunnel as system service...${NC}"
sudo cloudflared service install

# Create systemd service override
sudo mkdir -p /etc/systemd/system/cloudflared.service.d
sudo tee /etc/systemd/system/cloudflared.service.d/override.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/cloudflared --config /home/$USER/.cloudflared/config.yml tunnel run
User=$USER
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

echo ""
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo ""
echo "Sofia is now accessible at:"
echo -e "${GREEN}✅ Main App: https://elosofia.site${NC}"
echo -e "${GREEN}✅ CRM Dashboard: https://crm.elosofia.site${NC}"
echo ""
echo "Test the voice assistant:"
echo "1. Open https://elosofia.site"
echo "2. Click 'Sofia Agent' button"
echo "3. Allow microphone access"
echo "4. Speak in German!"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "• Check tunnel status: sudo systemctl status cloudflared"
echo "• View tunnel logs: sudo journalctl -u cloudflared -f"
echo "• Restart tunnel: sudo systemctl restart cloudflared"
echo "• View Sofia logs: docker-compose logs -f"