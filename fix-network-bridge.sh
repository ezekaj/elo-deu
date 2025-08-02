#!/bin/bash
# Fix Docker network bridge issue

echo "=== Fixing Docker Network Bridge ==="

# 1. Stop all containers
echo "1. Stopping all containers..."
docker stop dental-app livekit 2>/dev/null
docker rm dental-app livekit 2>/dev/null

# 2. List current networks
echo ""
echo "2. Current Docker networks:"
docker network ls

# 3. Create a proper network
echo ""
echo "3. Creating sofia-network..."
docker network create sofia-network 2>/dev/null || echo "Network already exists"

# 4. Start LiveKit on the network
echo ""
echo "4. Starting LiveKit on sofia-network..."
docker run -d \
  --name livekit \
  --network sofia-network \
  -p 7880:7880 \
  livekit/livekit-server:latest \
  --dev

# 5. Start the app on the same network
echo ""
echo "5. Starting app on sofia-network..."
docker run -d \
  --name dental-app \
  --network sofia-network \
  -p 3005:3005 \
  -v $(pwd)/dental-calendar:/app \
  -v $(pwd)/dental-calendar/database:/app/database \
  -w /app \
  -e NODE_ENV=production \
  -e LIVEKIT_URL=ws://livekit:7880 \
  -e LIVEKIT_API_KEY=devkey \
  -e LIVEKIT_API_SECRET=secret \
  node:18-alpine \
  sh -c "npm install && node server.js"

# 6. Wait for services
echo ""
echo "6. Waiting for services to start..."
sleep 10

# 7. Verify network connectivity
echo ""
echo "7. Verifying network connectivity..."
echo "Containers on sofia-network:"
docker network inspect sofia-network --format '{{range .Containers}}{{.Name}} {{end}}'

echo ""
echo "Testing connectivity from app to livekit:"
docker exec dental-app ping -c 2 livekit || echo "Ping failed (some containers don't have ping)"

# 8. Check container status
echo ""
echo "8. Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 9. Test the app
echo ""
echo "9. Testing app on port 3005..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:3005

# 10. Check logs
echo ""
echo "10. App logs:"
docker logs dental-app --tail 15

# 11. Create docker-compose with network
echo ""
echo "11. Creating docker-compose with proper network..."
cat > docker-compose.network.yml << 'EOF'
version: '3'

services:
  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit
    ports:
      - "7880:7880"
    command: --dev
    networks:
      - sofia-network
    restart: unless-stopped

  app:
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile.simple
    container_name: dental-app
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
    depends_on:
      - livekit
    volumes:
      - ./dental-calendar/database:/app/database
    networks:
      - sofia-network
    restart: unless-stopped

networks:
  sofia-network:
    driver: bridge
EOF

echo "✓ Created docker-compose.network.yml"
echo ""
echo "To use docker-compose with proper networking:"
echo "docker-compose -f docker-compose.network.yml down"
echo "docker-compose -f docker-compose.network.yml up -d"

echo ""
echo "=== Network Fix Complete ==="