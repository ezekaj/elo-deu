#!/bin/bash

# Interactive deployment script for elosofia.site
VPS_IP="167.235.67.1"
VPS_USER="root"

echo "======================================"
echo "Deploying to elosofia.site (VPS: $VPS_IP)"
echo "======================================"
echo ""
echo "This script will:"
echo "1. Connect to your VPS"
echo "2. Install Docker and nginx"
echo "3. Deploy your dental calendar app"
echo "4. Configure it for elosofia.site"
echo ""
echo "You'll need to enter your VPS password when prompted."
echo ""
read -p "Press Enter to continue..."

# Create deployment script
cat > /tmp/deploy-commands.sh << 'EOF'
#!/bin/bash

# Update system
apt-get update -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Install nginx if not present
if ! command -v nginx &> /dev/null; then
    echo "Installing nginx..."
    apt-get install -y nginx certbot python3-certbot-nginx
fi

# Clone or update repository
cd /root
if [ -d "elo-deu" ]; then
    echo "Updating repository..."
    cd elo-deu
    git pull
else
    echo "Cloning repository..."
    git clone https://github.com/FrankZarate/elo-deu.git
    cd elo-deu
fi

# Create production docker-compose file
echo "Creating docker-compose.production.yml..."
cat > docker-compose.production.yml << 'EOFDOCKER'
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
EOFDOCKER

# Create nginx configuration
echo "Configuring nginx..."
cat > /etc/nginx/sites-available/elosofia.site << 'EOFNGINX'
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
EOFNGINX

# Enable the site
ln -sf /etc/nginx/sites-available/elosofia.site /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Stop existing containers
echo "Stopping existing containers..."
docker-compose -f docker-compose.production.yml down || true
docker stop $(docker ps -aq) || true
docker rm $(docker ps -aq) || true

# Build and start services
echo "Building and starting services..."
docker-compose -f docker-compose.production.yml up -d --build

# Restart nginx
systemctl restart nginx

# Try to get SSL certificate
echo "Attempting to get SSL certificate..."
certbot --nginx -d elosofia.site -d www.elosofia.site --non-interactive --agree-tos --email frankzarate77@gmail.com || echo "SSL cert will be available after DNS propagation"

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Services running:"
docker ps
echo ""
echo "Access your site at:"
echo "- http://167.235.67.1 (now)"
echo "- https://elosofia.site (after DNS propagates)"
echo ""
echo "To get SSL after DNS propagates, run:"
echo "certbot --nginx -d elosofia.site -d www.elosofia.site"
EOF

# Copy script to VPS and execute
echo ""
echo "Connecting to VPS. Enter password when prompted..."
scp /tmp/deploy-commands.sh $VPS_USER@$VPS_IP:/tmp/
ssh $VPS_USER@$VPS_IP "chmod +x /tmp/deploy-commands.sh && /tmp/deploy-commands.sh"

echo ""
echo "Local deployment complete!"