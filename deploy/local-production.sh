#!/bin/bash
# Production deployment on local server with public access

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Sofia Local Production Deployment${NC}"
echo "===================================="
echo ""

# Check if running Sofia already
if docker-compose ps 2>/dev/null | grep -q "Up"; then
    echo -e "${YELLOW}Sofia is already running!${NC}"
    docker-compose ps
    echo ""
    echo "To restart: docker-compose restart"
    echo "To view logs: docker-compose logs -f"
    exit 0
fi

# Get public access method
echo "How do you want to expose Sofia to the internet?"
echo "1) Port forwarding (if you have router access)"
echo "2) Cloudflare Tunnel (recommended - free)"
echo "3) Ngrok (easiest but temporary URL)"
echo "4) Local only (no internet access)"
echo ""
read -p "Choose option (1-4): " OPTION

case $OPTION in
    1)
        echo ""
        echo -e "${BLUE}Port Forwarding Setup:${NC}"
        echo "1. Access your router admin panel"
        echo "2. Forward these ports to your server IP:"
        echo "   - TCP 80 → 80 (HTTP)"
        echo "   - TCP 443 → 443 (HTTPS)"
        echo "   - TCP 7880 → 7880 (LiveKit)"
        echo "   - TCP 7881 → 7881 (LiveKit WSS)"
        echo "   - UDP 50000-60000 → 50000-60000 (WebRTC)"
        echo ""
        read -p "Enter your public IP or domain: " PUBLIC_ADDR
        
        # Update configuration
        cd /home/elo/elo-deu
        sed -i "s|ws://localhost:7880|ws://${PUBLIC_ADDR}:7880|g" dental-calendar/public/sofia-real-connection.js
        sed -i "s|http://localhost:3005|http://${PUBLIC_ADDR}:3005|g" dental-calendar/public/sofia-real-connection.js
        
        # Start services
        docker-compose up -d
        
        echo ""
        echo -e "${GREEN}✅ Sofia is running!${NC}"
        echo "Access at: http://${PUBLIC_ADDR}:3005"
        ;;
        
    2)
        echo ""
        echo -e "${BLUE}Cloudflare Tunnel Setup:${NC}"
        
        # Install cloudflared if not present
        if ! command -v cloudflared &> /dev/null; then
            echo "Installing Cloudflare Tunnel..."
            wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
            sudo dpkg -i cloudflared-linux-amd64.deb
            rm cloudflared-linux-amd64.deb
        fi
        
        # Start services first
        cd /home/elo/elo-deu
        docker-compose up -d
        
        echo ""
        echo "Creating Cloudflare Tunnel..."
        echo "You'll need to:"
        echo "1. Login to your Cloudflare account"
        echo "2. Select your domain"
        echo "3. Authorize the tunnel"
        echo ""
        
        # Create tunnel
        cloudflared tunnel login
        cloudflared tunnel create sofia-dental
        
        # Configure tunnel
        cat > ~/.cloudflared/config.yml << EOF
tunnel: sofia-dental
credentials-file: /home/$USER/.cloudflared/*.json

ingress:
  - hostname: sofia.your-domain.com
    service: http://localhost:3005
  - hostname: sofia-ws.your-domain.com
    service: ws://localhost:7880
  - service: http_status:404
EOF
        
        echo ""
        read -p "Enter your domain (e.g., sofia.example.com): " DOMAIN
        sed -i "s/your-domain.com/${DOMAIN}/g" ~/.cloudflared/config.yml
        
        # Update frontend
        sed -i "s|ws://localhost:7880|wss://sofia-ws.${DOMAIN}|g" dental-calendar/public/sofia-real-connection.js
        sed -i "s|http://localhost:3005|https://sofia.${DOMAIN}|g" dental-calendar/public/sofia-real-connection.js
        
        # Start tunnel
        cloudflared tunnel route dns sofia-dental sofia.${DOMAIN}
        cloudflared tunnel route dns sofia-dental sofia-ws.${DOMAIN}
        cloudflared tunnel run sofia-dental &
        
        echo ""
        echo -e "${GREEN}✅ Sofia is accessible at:${NC}"
        echo "   https://sofia.${DOMAIN}"
        ;;
        
    3)
        echo ""
        echo -e "${BLUE}Ngrok Setup:${NC}"
        
        # Start services
        cd /home/elo/elo-deu
        docker-compose up -d
        
        # Install ngrok if needed
        if ! command -v ngrok &> /dev/null; then
            echo "Installing ngrok..."
            curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
            echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
            sudo apt update && sudo apt install -y ngrok
        fi
        
        # Start ngrok
        ngrok http 3005 --log=stdout > ngrok.log &
        sleep 5
        
        # Get URL
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*"' | grep -o 'https://[^"]*' | head -1)
        
        echo ""
        echo -e "${GREEN}✅ Sofia is accessible at:${NC}"
        echo "   $NGROK_URL"
        echo ""
        echo -e "${YELLOW}Note: This URL will change when ngrok restarts${NC}"
        ;;
        
    4)
        echo ""
        echo -e "${BLUE}Local Only Setup:${NC}"
        
        # Start services
        cd /home/elo/elo-deu
        docker-compose up -d
        
        echo ""
        echo -e "${GREEN}✅ Sofia is running locally!${NC}"
        echo "Access at: http://localhost:3005"
        ;;
esac

echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "• View logs: docker-compose logs -f"
echo "• Restart: docker-compose restart"
echo "• Stop: docker-compose down"
echo "• Status: docker-compose ps"
echo ""

# Create systemd service for auto-start
echo -e "${BLUE}Setting up auto-start on boot...${NC}"
sudo tee /etc/systemd/system/sofia-dental.service > /dev/null << EOF
[Unit]
Description=Sofia Dental Assistant
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/elo/elo-deu
ExecStart=/usr/bin/docker-compose up
ExecStop=/usr/bin/docker-compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable sofia-dental
echo -e "${GREEN}✅ Sofia will auto-start on system boot${NC}"

echo ""
echo -e "${GREEN}🎉 Deployment Complete!${NC}"