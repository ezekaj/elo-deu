#!/bin/bash
# Direct VPS deployment

echo "Installing sshpass..."
which sshpass || {
    echo "Please install sshpass first:"
    echo "sudo apt-get update && sudo apt-get install -y sshpass"
    exit 1
}

VPS_IP="167.235.67.1"
VPS_PASS="Fzconstruction.1"

echo "🚀 Deploying to VPS..."

# Run deployment commands on VPS
sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no root@$VPS_IP << 'ENDSSH'
cd /root
git clone https://github.com/FrankZarate/elo-deu.git 2>/dev/null || echo "Repo exists"
cd /root/elo-deu

# Stop old containers
docker-compose down 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Create simple docker-compose
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  livekit:
    image: livekit/livekit-server:latest
    network_mode: host
    environment:
      - LIVEKIT_KEYS=devkey: secret
    command: --dev
    restart: unless-stopped

  dental-calendar:
    build: ./dental-calendar
    network_mode: host
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://167.235.67.1:7880
      - VPS_IP=167.235.67.1
      - PORT=3005
    restart: unless-stopped
EOF

# Deploy
export VPS_IP=167.235.67.1
docker-compose up -d --build

echo "✅ Deployment complete!"
ENDSSH

echo "✅ Done! Access Sofia at: http://$VPS_IP:3005/production.html"