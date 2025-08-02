#!/bin/bash
# Quick VPS deployment for Sofia

# Stop everything first
docker-compose down 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Set VPS IP
export VPS_IP=167.235.67.1

# Start only essential services
docker run -d \
  --name livekit \
  -p 7880:7880 \
  -p 30000-40000:30000-40000/udp \
  -e LIVEKIT_KEYS="devkey: secret" \
  livekit/livekit-server:latest --dev

sleep 5

# Run dental calendar
docker run -d \
  --name dental-calendar \
  -p 3005:3005 \
  -e LIVEKIT_URL=ws://167.235.67.1:7880 \
  -e VPS_IP=167.235.67.1 \
  -v $(pwd)/dental-calendar:/app \
  -w /app \
  node:18-alpine \
  sh -c "npm install && npm start"

echo "Deployment complete!"
echo "Access: http://167.235.67.1:3005/production.html"