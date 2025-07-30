#!/bin/bash
# Sofia Dental Assistant - Production Deployment Script
# This script deploys Sofia with full voice functionality on a production server

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
   print_warning "This script should not be run as root directly"
   print_warning "It will request sudo permissions when needed"
   exit 1
fi

print_status "Starting Sofia Dental Assistant deployment..."

# Get domain name or IP
if [ -z "$1" ]; then
    read -p "Enter your domain name or public IP address: " DOMAIN
else
    DOMAIN=$1
fi

print_status "Deploying to: $DOMAIN"

# Step 1: System Update and Dependencies
print_status "Step 1: Updating system and installing dependencies..."

sudo apt update && sudo apt upgrade -y
sudo apt install -y \
    docker.io \
    docker-compose \
    nginx \
    certbot \
    python3-certbot-nginx \
    git \
    ufw \
    curl \
    net-tools \
    htop \
    iotop

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add current user to docker group
sudo usermod -aG docker $USER
print_success "System dependencies installed"

# Step 2: Configure Firewall
print_status "Step 2: Configuring firewall..."

# Enable firewall
sudo ufw --force enable

# Allow SSH (adjust port if needed)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow LiveKit ports
sudo ufw allow 7880/tcp
sudo ufw allow 7881/tcp

# Allow WebRTC UDP ports (critical for voice)
sudo ufw allow 50000:60000/udp

# Show status
sudo ufw status
print_success "Firewall configured"

# Step 3: Clone Repository
print_status "Step 3: Setting up project directory..."

DEPLOY_DIR="/opt/sofia-dental"

# Clean up if exists
if [ -d "$DEPLOY_DIR" ]; then
    print_warning "Deployment directory exists. Backing up..."
    sudo mv $DEPLOY_DIR ${DEPLOY_DIR}.backup.$(date +%Y%m%d_%H%M%S)
fi

# Clone repository
sudo git clone https://github.com/ezekaj/elo-deu.git $DEPLOY_DIR
sudo chown -R $USER:$USER $DEPLOY_DIR
cd $DEPLOY_DIR

# Create necessary directories
mkdir -p data/calendar data/crm logs
print_success "Project directory prepared"

# Step 4: Configure Environment Variables
print_status "Step 4: Creating environment configuration..."

cat > .env << EOF
# LiveKit Configuration
LIVEKIT_URL=ws://livekit:7880
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
LIVEKIT_LOG_LEVEL=info

# Public URLs
PUBLIC_URL=https://${DOMAIN}
LIVEKIT_WS_URL=wss://${DOMAIN}:7881

# Google API (already in the code)
GOOGLE_API_KEY=AIzaSyCGXSa68qIQNtp8WEH_zYFF3UjIHS4EW2M

# Internal Service URLs
CALENDAR_URL=http://dental-calendar:3005
CRM_URL=http://crm-dashboard:5000

# Database
DATABASE_URL=sqlite:///data/dental_calendar.db

# Production Mode
NODE_ENV=production
PYTHON_ENV=production
EOF

# Copy to dental-calendar directory
cp .env dental-calendar/.env
print_success "Environment variables configured"

# Step 5: Create Production Docker Compose
print_status "Step 5: Creating production Docker configuration..."

cat > docker-compose.production.yml << 'EOF'
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
      - "7881:7881"
      - "50000-60000:50000-60000/udp"
    environment:
      - LIVEKIT_KEYS=devkey:secret
      - LIVEKIT_WEBHOOK_URL=http://sofia-agent:8080/webhook
      - LIVEKIT_LOG_LEVEL=info
    command: --dev --bind 0.0.0.0
    networks:
      - sofia-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7880/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  sofia-agent:
    build:
      context: .
      dockerfile: Dockerfile.sofia
    environment:
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - CALENDAR_URL=http://dental-calendar:3005
      - PYTHON_ENV=production
      - LOG_LEVEL=INFO
    depends_on:
      - livekit
      - dental-calendar
    networks:
      - sofia-network
    restart: unless-stopped
    volumes:
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  dental-calendar:
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - PORT=3005
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
    volumes:
      - ./data/calendar:/app/data
      - ./dental-calendar/public:/app/public
    networks:
      - sofia-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3005/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  crm-dashboard:
    build:
      context: ./crm
      dockerfile: Dockerfile
    ports:
      - "5000:5000"
    volumes:
      - ./data/calendar:/app/data
    networks:
      - sofia-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  calendar-data:
  livekit-data:

networks:
  sofia-network:
    driver: bridge
EOF

print_success "Docker configuration created"

# Step 6: Configure Nginx
print_status "Step 6: Configuring Nginx reverse proxy..."

sudo tee /etc/nginx/sites-available/sofia-dental > /dev/null << EOF
# Main website and calendar
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    # SSL will be configured by certbot
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval'" always;
    
    # Main calendar interface
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Socket.IO support
    location /socket.io/ {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # CRM Dashboard
    location /crm/ {
        proxy_pass http://localhost:5000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# LiveKit WebSocket server
server {
    listen 7881 ssl http2;
    server_name ${DOMAIN};

    # SSL will be configured by certbot
    
    location / {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/sofia-dental /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
print_success "Nginx configured"

# Step 7: Configure SSL (if domain, not IP)
if [[ ! $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_status "Step 7: Configuring SSL certificates..."
    
    # Get email for SSL
    read -p "Enter email for SSL certificate notifications: " SSL_EMAIL
    
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $SSL_EMAIL
    
    # Set up auto-renewal
    echo "0 0 * * * root certbot renew --quiet" | sudo tee -a /etc/crontab
    print_success "SSL certificates configured"
else
    print_warning "Skipping SSL setup for IP address. Use a domain for HTTPS."
fi

# Step 8: Update Frontend Configuration
print_status "Step 8: Updating frontend configuration..."

# Update WebSocket URLs in the frontend
if [[ $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # IP address - use ws://
    sed -i "s|ws://localhost:7880|ws://${DOMAIN}:7880|g" dental-calendar/public/sofia-real-connection.js
    sed -i "s|http://localhost:3005|http://${DOMAIN}|g" dental-calendar/public/sofia-real-connection.js
else
    # Domain - use wss://
    sed -i "s|ws://localhost:7880|wss://${DOMAIN}:7881|g" dental-calendar/public/sofia-real-connection.js
    sed -i "s|http://localhost:3005|https://${DOMAIN}|g" dental-calendar/public/sofia-real-connection.js
fi

print_success "Frontend configuration updated"

# Step 9: Build and Deploy
print_status "Step 9: Building and deploying services..."

# Build images
docker-compose -f docker-compose.production.yml build

# Start services
docker-compose -f docker-compose.production.yml up -d

# Wait for services to start
print_status "Waiting for services to start..."
sleep 30

# Check status
docker-compose -f docker-compose.production.yml ps
print_success "Services deployed"

# Step 10: Verify Deployment
print_status "Step 10: Verifying deployment..."

# Check health endpoints
if curl -sf http://localhost:3005/api/health > /dev/null; then
    print_success "Calendar service is healthy"
else
    print_error "Calendar service health check failed"
fi

if curl -sf http://localhost:7880/health > /dev/null; then
    print_success "LiveKit service is healthy"
else
    print_error "LiveKit service health check failed"
fi

# Final instructions
echo ""
print_success "Sofia Dental Assistant deployment complete!"
echo ""
echo "Access your deployment at:"
if [[ $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "  → http://${DOMAIN}"
else
    echo "  → https://${DOMAIN}"
fi
echo ""
echo "CRM Dashboard:"
if [[ $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "  → http://${DOMAIN}/crm/"
else
    echo "  → https://${DOMAIN}/crm/"
fi
echo ""
echo "To test Sofia:"
echo "  1. Open the calendar interface"
echo "  2. Click the 'Sofia Agent' button"
echo "  3. Allow microphone access"
echo "  4. Speak in German to interact with Sofia"
echo ""
echo "Useful commands:"
echo "  • View logs: docker-compose -f docker-compose.production.yml logs -f"
echo "  • Restart services: docker-compose -f docker-compose.production.yml restart"
echo "  • Stop services: docker-compose -f docker-compose.production.yml down"
echo ""
print_warning "Remember to change default LiveKit API keys for production use!"