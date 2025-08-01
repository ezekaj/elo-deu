#!/bin/bash
# Direct deployment script for Sofia on VPS
set -e

echo "🚀 Sofia Direct Deployment"
echo "========================="

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
apt install -y docker-compose

# Create directories
mkdir -p /opt/elo-deu
cd /opt/elo-deu

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # LiveKit Server
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
      - "7881:7881/tcp"
    environment:
      - "LIVEKIT_KEYS=devkey: devsecret_that_is_at_least_32_characters_long"
      - "LIVEKIT_LOG_LEVEL=info"
    command: --dev --bind 0.0.0.0
    networks:
      - sofia-network
    restart: unless-stopped

  # Dental Calendar
  dental-calendar:
    image: ezekaj/dental-calendar:latest
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=devsecret_that_is_at_least_32_characters_long
    networks:
      - sofia-network
    restart: unless-stopped

  # Sofia Agent
  sofia-agent:
    image: ezekaj/sofia-agent:latest
    environment:
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=devsecret_that_is_at_least_32_characters_long
      - GOOGLE_API_KEY=AIzaSyCGXSa68qIQNtp8WEH_zYFF3UjIHS4EW2M
      - CALENDAR_URL=http://dental-calendar:3005
    ports:
      - "8080:8080"
    depends_on:
      - livekit
      - dental-calendar
    networks:
      - sofia-network
    restart: unless-stopped

  # CRM
  crm-dashboard:
    image: ezekaj/crm:latest
    ports:
      - "5000:5000"
    networks:
      - sofia-network
    restart: unless-stopped

networks:
  sofia-network:
    driver: bridge
EOF

# Create .env file
cat > .env << 'EOF'
GOOGLE_API_KEY=AIzaSyCGXSa68qIQNtp8WEH_zYFF3UjIHS4EW2M
LIVEKIT_URL=ws://localhost:7880
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=devsecret_that_is_at_least_32_characters_long
VPS_IP=167.235.67.1
EOF

# Pull and start services
docker-compose pull
docker-compose up -d

# Configure firewall
ufw allow 22/tcp
ufw allow 3005/tcp
ufw allow 5000/tcp
ufw allow 7880/tcp
ufw allow 8080/tcp
ufw allow 50000:60000/udp
ufw --force enable

echo "✅ Deployment complete!"
echo "Services running at:"
echo "  Calendar: http://167.235.67.1:3005"
echo "  LiveKit: http://167.235.67.1:7880"
echo "  Sofia: http://167.235.67.1:8080"
echo "  CRM: http://167.235.67.1:5000"