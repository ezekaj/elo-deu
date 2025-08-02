#!/bin/bash

# Deploy to elosofia.site VPS
# This script deploys the dental calendar app to your VPS and configures it for elosofia.site

VPS_IP="167.235.67.1"
VPS_USER="root"
DOMAIN="elosofia.site"

echo "======================================"
echo "Deploying to elosofia.site (VPS: $VPS_IP)"
echo "======================================"

# SSH into VPS and execute deployment commands
ssh -o StrictHostKeyChecking=no $VPS_USER@$VPS_IP << 'ENDSSH'

# Update system
apt-get update -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Install nginx if not present
if ! command -v nginx &> /dev/null; then
    apt-get install -y nginx certbot python3-certbot-nginx
fi

# Clone or update repository
cd /root
if [ -d "elo-deu" ]; then
    cd elo-deu
    git pull
else
    git clone https://github.com/FrankZarate/elo-deu.git
    cd elo-deu
fi

# Create production docker-compose file
cat > docker-compose.production.yml << 'EOF'
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
      - "30000-40000:30000-40000/udp"
    environment:
      - LIVEKIT_KEYS=devkey: secret
    command: --dev
    restart: unless-stopped

  dental-calendar:
    build: ./dental-calendar
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
      - PUBLIC_URL=https://elosofia.site
    restart: unless-stopped
    depends_on:
      - livekit

  sofia-agent:
    build:
      context: .
      dockerfile: Dockerfile.sofia
    ports:
      - "8080:8080"
    environment:
      - LIVEKIT_URL=ws://livekit:7880
      - GOOGLE_API_KEY=AIzaSyCGXSa68qIQNtp8WEH_zYFF3UjIHS4EW2M
    restart: unless-stopped
    depends_on:
      - livekit
EOF

# Create nginx configuration for elosofia.site
cat > /etc/nginx/sites-available/elosofia.site << 'EOF'
server {
    listen 80;
    server_name elosofia.site www.elosofia.site;

    # Main app
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket for LiveKit
    location /ws {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # LiveKit API
    location /twirp/ {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/elosofia.site /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Stop existing containers
docker-compose -f docker-compose.production.yml down || true

# Build and start services
docker-compose -f docker-compose.production.yml up -d --build

# Restart nginx
systemctl restart nginx

# Get SSL certificate (will fail if DNS not pointing to this server yet)
certbot --nginx -d elosofia.site -d www.elosofia.site --non-interactive --agree-tos --email frankzarate77@gmail.com || true

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Services running:"
docker ps
echo ""
echo "Next steps:"
echo "1. Update your DNS A records:"
echo "   elosofia.site     → 167.235.67.1"
echo "   www.elosofia.site → 167.235.67.1"
echo ""
echo "2. Once DNS is updated, run this to get SSL:"
echo "   certbot --nginx -d elosofia.site -d www.elosofia.site"
echo ""
echo "3. Access your site at:"
echo "   http://167.235.67.1 (now)"
echo "   https://elosofia.site (after DNS update)"

ENDSSH

echo ""
echo "Local deployment script complete!"
echo "Check the output above for any errors."