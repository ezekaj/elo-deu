#!/bin/bash
# Run this on the VPS

echo "Deploying token fix..."

# 1. Update environment variables in docker-compose
cd /root/elo-deu
cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  livekit:
    environment:
      - LIVEKIT_KEYS=devkey:secret
    command: --dev --bind 0.0.0.0
    
  app:
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
EOF

# 2. Restart services
echo "Restarting services..."
docker-compose -f docker-compose.final.yml -f docker-compose.override.yml down
docker-compose -f docker-compose.final.yml -f docker-compose.override.yml up -d

# 3. Wait for services
echo "Waiting for services to start..."
sleep 10

# 4. Check logs
echo ""
echo "LiveKit logs:"
docker logs $(docker ps --format "{{.Names}}" | grep livekit) --tail 10

echo ""
echo "App logs:"
docker logs $(docker ps --format "{{.Names}}" | grep -E "app|dental") --tail 10

echo ""
echo "Fix deployed! Test at https://elosofia.site/test-livekit-secure.html"
