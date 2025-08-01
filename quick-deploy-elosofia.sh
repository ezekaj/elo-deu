#!/bin/bash

echo "======================================"
echo "Quick Deploy to elosofia.site"
echo "======================================"

# Stop existing tunnels
pkill cloudflared 2>/dev/null || true

# Check if we have Cloudflare credentials
if [ ! -d ~/.cloudflared ]; then
    echo "⚠️  First time setup - you'll need to login to Cloudflare"
    echo "This will open a browser window"
    echo ""
    read -p "Press Enter to continue..."
    cloudflared tunnel login
fi

# Create or recreate tunnel
echo "Setting up tunnel..."
cloudflared tunnel delete elosofia-dental 2>/dev/null || true
cloudflared tunnel create elosofia-dental

# Get tunnel ID
TUNNEL_ID=$(cloudflared tunnel list | grep elosofia-dental | awk '{print $1}')

# Create config
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml << EOF
tunnel: elosofia-dental
credentials-file: /home/$USER/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: calendar.elosofia.site
    service: http://localhost:3005
  - hostname: voice.elosofia.site
    service: http://localhost:7880
  - hostname: api.elosofia.site
    service: http://localhost:3005
  - hostname: crm.elosofia.site
    service: http://localhost:5000
  - hostname: elosofia.site
    service: http://localhost:3005
  - service: http_status:404
EOF

# Update config.js for production
cat > /home/elo/elo-deu/docs/config.js << 'EOF'
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.hostname === 'localhost' 
        ? 'http://localhost:3005' 
        : 'https://calendar.elosofia.site',
    
    CRM_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:5000'
        : 'https://crm.elosofia.site',
    
    LIVEKIT_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:7880'
        : 'wss://voice.elosofia.site',
    
    LIVEKIT_API_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:7880'
        : 'https://voice.elosofia.site',
    
    WS_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:3005'
        : 'wss://calendar.elosofia.site',
    
    ENVIRONMENT: window.location.hostname === 'localhost' ? 'development' : 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};
EOF

# Show DNS configuration
echo ""
echo "======================================"
echo "📋 DNS Configuration Required"
echo "======================================"
echo ""
echo "Add these CNAME records to elosofia.site:"
echo ""
echo "Name                Type    Value"
echo "----                ----    -----"
echo "calendar            CNAME   ${TUNNEL_ID}.cfargotunnel.com"
echo "voice               CNAME   ${TUNNEL_ID}.cfargotunnel.com"
echo "api                 CNAME   ${TUNNEL_ID}.cfargotunnel.com"
echo "crm                 CNAME   ${TUNNEL_ID}.cfargotunnel.com"
echo "@                   CNAME   ${TUNNEL_ID}.cfargotunnel.com"
echo ""
echo "Or if using Cloudflare DNS, run these commands:"
echo ""
echo "cloudflared tunnel route dns elosofia-dental calendar.elosofia.site"
echo "cloudflared tunnel route dns elosofia-dental voice.elosofia.site"
echo "cloudflared tunnel route dns elosofia-dental api.elosofia.site"
echo "cloudflared tunnel route dns elosofia-dental crm.elosofia.site"
echo "cloudflared tunnel route dns elosofia-dental elosofia.site"
echo ""
echo "======================================"
echo ""
read -p "Have you added the DNS records? (y/n): " dns_done

if [ "$dns_done" = "y" ]; then
    # Start tunnel
    echo "Starting tunnel..."
    cloudflared tunnel run elosofia-dental &
    TUNNEL_PID=$!
    
    # Wait a bit
    sleep 5
    
    # Test connection
    echo ""
    echo "Testing deployment..."
    if curl -s -o /dev/null -w "%{http_code}" https://calendar.elosofia.site | grep -q "200\|301\|302"; then
        echo "✅ calendar.elosofia.site is working!"
    else
        echo "⚠️  calendar.elosofia.site not responding yet (DNS might be propagating)"
    fi
    
    echo ""
    echo "======================================"
    echo "✅ Deployment Complete!"
    echo "======================================"
    echo ""
    echo "Your sites:"
    echo "- https://elosofia.site"
    echo "- https://calendar.elosofia.site"
    echo "- https://voice.elosofia.site"
    echo "- https://api.elosofia.site"
    echo "- https://crm.elosofia.site"
    echo ""
    echo "Tunnel PID: $TUNNEL_PID"
    echo "To stop: kill $TUNNEL_PID"
else
    echo ""
    echo "Please add the DNS records first, then run this script again."
fi