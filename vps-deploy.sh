#!/bin/bash
# VPS Deployment Script for Sofia

echo "🚀 Sofia VPS Deployment"
echo "======================"

# Stop and remove old containers
docker-compose down -v 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker network prune -f

# Get VPS IP
export VPS_IP=$(curl -s https://ipinfo.io/ip)
echo "VPS IP: $VPS_IP"

# Create production docker-compose
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
      - "7881:7881"
      - "30000-40000:30000-40000/udp"
    environment:
      - LIVEKIT_KEYS=devkey: secret
      - LIVEKIT_LOG_LEVEL=info
    command: --dev --bind 0.0.0.0
    restart: unless-stopped

  dental-calendar:
    build: ./dental-calendar
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://${VPS_IP}:7880
      - VPS_IP=${VPS_IP}
    restart: unless-stopped
    depends_on:
      - livekit

  sofia-agent:
    build:
      context: .
      dockerfile: Dockerfile.sofia
    environment:
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
      - GOOGLE_API_KEY=AIzaSyCGXSa68qIQNtp8WEH_zYFF3UjIHS4EW2M
      - CALENDAR_URL=http://dental-calendar:3005
    ports:
      - "8080:8080"
    restart: unless-stopped
    depends_on:
      - livekit
      - dental-calendar
EOF

# Start containers
docker-compose up -d --build

# Wait for services
sleep 10

# Show status
echo ""
echo "✅ Deployment complete!"
echo ""
echo "Access your services:"
echo "📅 Calendar: http://$VPS_IP:3005"
echo "📱 Production UI: http://$VPS_IP:3005/production.html"
echo "🏥 Health: http://$VPS_IP:8080/health"
echo ""
echo "Sofia voice features are ready to use!"