#!/bin/bash
# Restart LiveKit properly

echo "=== Restarting LiveKit Properly ==="

# 1. Stop everything
echo "1. Stopping all containers..."
docker-compose down
docker stop $(docker ps -aq) 2>/dev/null || true

# 2. Clean up
echo ""
echo "2. Cleaning up..."
docker system prune -f

# 3. Start ONLY LiveKit first to debug
echo ""
echo "3. Starting LiveKit in foreground to see errors..."
echo "Press Ctrl+C after you see the error or if it starts successfully"
echo ""
docker run --rm \
  --name livekit-debug \
  -p 7880:7880 \
  livekit/livekit-server:v1.5.2 \
  --dev

# If we get here, user pressed Ctrl+C
echo ""
echo "4. Now let's try a simpler approach..."
echo "Starting LiveKit with docker-compose..."

# Create minimal docker-compose
cat > docker-compose.minimal.yml << 'EOF'
version: '3'

services:
  livekit:
    image: livekit/livekit-server:v1.5.2
    container_name: livekit
    ports:
      - "7880:7880"
    command: --dev
    restart: always

  app:
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile
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
      - ./dental-calendar/public:/app/public
    restart: always
EOF

# Start with minimal config
docker-compose -f docker-compose.minimal.yml up -d

echo ""
echo "5. Waiting for services..."
sleep 10

echo ""
echo "6. Checking status:"
docker ps
echo ""
docker logs livekit --tail 20

echo ""
echo "=== Complete ==="
echo "Check the LiveKit logs above for any errors"