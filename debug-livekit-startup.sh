#!/bin/bash
# Debug why LiveKit won't start

echo "=== Debugging LiveKit Startup ==="

# 1. Check if container exists
echo "1. Checking LiveKit container status:"
docker ps -a | grep livekit

# 2. Check LiveKit logs
echo ""
echo "2. LiveKit container logs:"
docker logs sofia-livekit 2>&1 | tail -50

# 3. Check if port 7880 is already in use
echo ""
echo "3. Checking if port 7880 is already in use:"
sudo lsof -i :7880 || netstat -tlnp | grep 7880 || echo "Port 7880 is free"

# 4. Try starting LiveKit with minimal config
echo ""
echo "4. Trying minimal LiveKit startup..."
docker stop sofia-livekit 2>/dev/null
docker rm sofia-livekit 2>/dev/null

# Start with explicit port mapping and simpler command
docker run -d \
  --name sofia-livekit-test \
  -p 7880:7880 \
  -e LIVEKIT_KEYS=devkey:secret \
  livekit/livekit-server:v1.5.2 \
  --dev

sleep 5

# Check if it started
echo ""
echo "5. Test container status:"
docker ps | grep livekit-test

# Check logs
echo ""
echo "6. Test container logs:"
docker logs sofia-livekit-test 2>&1 | tail -20

# 5. Create alternative setup with different port
echo ""
echo "7. Creating alternative setup with port 7890..."
cat > docker-compose.livekit-alt.yml << 'EOF'
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:v1.5.2
    container_name: livekit-alt
    command: --dev --bind 0.0.0.0 --port 7890
    ports:
      - "7890:7890"
    environment:
      - LIVEKIT_KEYS=devkey:secret
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
      - LIVEKIT_URL=ws://livekit:7890
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
    depends_on:
      - livekit
    volumes:
      - ./dental-calendar/database:/app/database
    restart: unless-stopped
EOF

echo "✓ Created alternative config with port 7890"

# 6. Clean up test container
docker stop sofia-livekit-test 2>/dev/null
docker rm sofia-livekit-test 2>/dev/null

echo ""
echo "=== Debug Complete ==="
echo ""
echo "If port 7880 is in use, try:"
echo "1. Kill the process using port 7880"
echo "2. Or use the alternative config:"
echo "   docker-compose -f docker-compose.livekit-alt.yml up -d"
echo ""
echo "This will run LiveKit on port 7890 instead"