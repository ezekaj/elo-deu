#!/bin/bash

echo "======================================"
echo "Deploying Sofia Dental to elosofia.site"
echo "======================================"
echo ""

# Stop existing tunnels
echo "Stopping existing tunnels..."
pkill cloudflared 2>/dev/null || true
pkill ngrok 2>/dev/null || true

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "❌ cloudflared not installed. Installing..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
fi

# Option 1: Use Cloudflare Tunnel with your domain
echo ""
echo "Choose deployment method:"
echo "1) Cloudflare Tunnel (recommended if you use Cloudflare DNS)"
echo "2) Direct server deployment with nginx"
echo "3) Quick tunnel (temporary URLs)"
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo "Setting up Cloudflare Tunnel for elosofia.site..."
        echo "================================================"
        
        # Login to Cloudflare (if not already)
        if [ ! -d ~/.cloudflared ]; then
            echo "Please login to your Cloudflare account:"
            cloudflared tunnel login
        fi
        
        # Delete old tunnel if exists
        cloudflared tunnel delete elosofia-dental 2>/dev/null || true
        
        # Create new tunnel
        echo "Creating tunnel..."
        cloudflared tunnel create elosofia-dental
        
        # Get tunnel ID
        TUNNEL_ID=$(cloudflared tunnel list | grep elosofia-dental | awk '{print $1}')
        echo "Tunnel ID: $TUNNEL_ID"
        
        # Create config
        cat > ~/.cloudflared/config.yml << EOF
tunnel: elosofia-dental
credentials-file: /home/$USER/.cloudflared/${TUNNEL_ID}.json

ingress:
  # Main calendar application
  - hostname: calendar.elosofia.site
    service: http://localhost:3005
    originRequest:
      noTLSVerify: true
      
  # LiveKit WebSocket service  
  - hostname: voice.elosofia.site
    service: http://localhost:7880
    originRequest:
      noTLSVerify: true
      
  # API endpoints
  - hostname: api.elosofia.site
    service: http://localhost:3005
    originRequest:
      noTLSVerify: true
      
  # CRM Dashboard
  - hostname: crm.elosofia.site
    service: http://localhost:5000
    originRequest:
      noTLSVerify: true
      
  # Main site redirect to calendar
  - hostname: elosofia.site
    service: http://localhost:3005
    originRequest:
      noTLSVerify: true
      
  # Catch-all
  - service: http_status:404
EOF

        echo ""
        echo "Add these DNS records to your domain:"
        echo "====================================="
        echo "Type: CNAME"
        echo ""
        echo "calendar.elosofia.site → ${TUNNEL_ID}.cfargotunnel.com"
        echo "voice.elosofia.site    → ${TUNNEL_ID}.cfargotunnel.com"
        echo "api.elosofia.site      → ${TUNNEL_ID}.cfargotunnel.com"
        echo "crm.elosofia.site      → ${TUNNEL_ID}.cfargotunnel.com"
        echo "elosofia.site          → ${TUNNEL_ID}.cfargotunnel.com"
        echo ""
        echo "Press Enter after adding DNS records..."
        read
        
        # Update config.js
        cat > /home/elo/elo-deu/docs/config.js << 'EOF'
/**
 * Dynamic Configuration for Sofia Dental Calendar
 * Deployed to elosofia.site
 */

window.SOFIA_CONFIG = {
    // API Endpoints
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
    
    // WebSocket for real-time updates
    WS_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:3005'
        : 'wss://calendar.elosofia.site',
    
    // Environment
    ENVIRONMENT: window.location.hostname === 'localhost' ? 'development' : 'production',
    
    // Features
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};

// Log configuration for debugging
console.log('Sofia Configuration:', {
    environment: window.SOFIA_CONFIG.ENVIRONMENT,
    apiBase: window.SOFIA_CONFIG.API_BASE_URL,
    livekit: window.SOFIA_CONFIG.LIVEKIT_URL
});
EOF

        echo "✅ Configuration updated for elosofia.site"
        
        # Start tunnel
        echo ""
        echo "Starting Cloudflare tunnel..."
        cloudflared tunnel run elosofia-dental &
        
        echo ""
        echo "✅ Deployment complete!"
        echo ""
        echo "Your services are available at:"
        echo "- https://calendar.elosofia.site (Main Calendar)"
        echo "- https://voice.elosofia.site (LiveKit Voice)"
        echo "- https://api.elosofia.site (API)"
        echo "- https://crm.elosofia.site (CRM Dashboard)"
        echo "- https://elosofia.site (Main Site)"
        ;;
        
    2)
        echo ""
        echo "Direct Server Deployment"
        echo "======================="
        echo ""
        echo "For direct deployment, you need:"
        echo "1. A VPS/Server with public IP"
        echo "2. Point elosofia.site DNS A records to your server IP"
        echo "3. Install nginx and certbot for SSL"
        echo ""
        echo "Would you like me to generate nginx configuration? (y/n)"
        read -p "> " nginx_config
        
        if [ "$nginx_config" = "y" ]; then
            cat > nginx-elosofia.conf << 'EOF'
server {
    listen 80;
    server_name elosofia.site calendar.elosofia.site api.elosofia.site;
    
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

server {
    listen 80;
    server_name voice.elosofia.site;
    
    location / {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

server {
    listen 80;
    server_name crm.elosofia.site;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
            echo "✅ Nginx configuration saved to nginx-elosofia.conf"
            echo ""
            echo "Next steps:"
            echo "1. Copy this file to /etc/nginx/sites-available/"
            echo "2. Enable it: ln -s /etc/nginx/sites-available/nginx-elosofia.conf /etc/nginx/sites-enabled/"
            echo "3. Get SSL: certbot --nginx -d elosofia.site -d calendar.elosofia.site -d voice.elosofia.site -d api.elosofia.site -d crm.elosofia.site"
            echo "4. Restart nginx: systemctl restart nginx"
        fi
        ;;
        
    3)
        echo "Using temporary tunnels..."
        ./run-tunnels.sh
        ;;
esac