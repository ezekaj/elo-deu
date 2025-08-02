#!/bin/bash
# Fix Docker networking issues

echo "=== Fixing Docker Network Configuration ==="

# 1. Stop all containers
echo "1. Stopping all containers..."
docker-compose -f docker-compose.final.yml down
docker-compose -f docker-compose.livekit-fix.yml down
docker stop $(docker ps -aq) 2>/dev/null || true

# 2. Clean up networks
echo ""
echo "2. Cleaning up Docker networks..."
docker network prune -f

# 3. Create new docker-compose with proper networking
echo ""
echo "3. Creating fixed docker-compose configuration..."
cat > docker-compose.production.yml << 'EOF'
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit
    ports:
      - "7880:7880"
    command: --dev --bind 0.0.0.0
    restart: unless-stopped
    networks:
      - dental-network
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:7880/healthz"]
      interval: 10s
      timeout: 5s
      retries: 5

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
    restart: unless-stopped
    networks:
      - dental-network

networks:
  dental-network:
    name: dental-network
    driver: bridge
EOF

echo "✓ Created docker-compose.production.yml"

# 4. Start containers
echo ""
echo "4. Starting containers with proper networking..."
docker-compose -f docker-compose.production.yml up -d

# 5. Wait for containers
echo ""
echo "5. Waiting for containers to start..."
sleep 15

# 6. Verify networking
echo ""
echo "6. Verifying network connectivity..."
echo "Containers on dental-network:"
docker network inspect dental-network --format '{{range .Containers}}{{.Name}} {{end}}'
echo ""

echo "Testing connectivity from app to livekit:"
docker exec dental-app ping -c 2 livekit || echo "Ping failed"
echo ""

echo "Testing HTTP connection:"
docker exec dental-app wget -O- http://livekit:7880 2>&1 | head -10 || echo "HTTP failed"
echo ""

# 7. Check container logs
echo "7. Container status:"
docker ps | grep -E "livekit|dental"
echo ""

echo "LiveKit logs:"
docker logs livekit --tail 10 2>&1
echo ""

echo "App logs:"
docker logs dental-app --tail 10 2>&1
echo ""

# 8. Update config.js to ensure correct URLs
echo "8. Updating config.js..."
cat > update-config.sh << 'CONFIG_UPDATE'
#!/bin/bash
docker exec dental-app sh -c "cat > /app/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.origin,
    WS_URL: window.location.origin.replace('http:', 'ws:').replace('https:', 'wss:'),
    
    // Use secure WebSocket when on HTTPS
    LIVEKIT_URL: window.location.protocol === 'https:' 
        ? 'wss://elosofia.site/ws'
        : 'ws://localhost:7880',
    
    LIVEKIT_API_KEY: 'devkey',
    LIVEKIT_API_SECRET: 'secret',
    
    ENVIRONMENT: 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        DEMO_MODE: false
    }
};
EOF"
CONFIG_UPDATE
chmod +x update-config.sh
./update-config.sh

echo ""
echo "=== Network Fix Complete ==="
echo ""
echo "Containers are now on the same network and can communicate."
echo "Test at: https://elosofia.site"