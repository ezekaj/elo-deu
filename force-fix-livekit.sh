#!/bin/bash
# Force fix LiveKit startup issues

echo "=== Force Fixing LiveKit ==="

# 1. Kill everything related to LiveKit
echo "1. Killing all LiveKit processes..."
docker stop $(docker ps -a | grep livekit | awk '{print $1}') 2>/dev/null
docker rm $(docker ps -a | grep livekit | awk '{print $1}') 2>/dev/null
pkill -f livekit 2>/dev/null

# 2. Clean Docker system
echo ""
echo "2. Cleaning Docker system..."
docker system prune -f

# 3. Free up ports
echo ""
echo "3. Freeing up ports..."
fuser -k 7880/tcp 2>/dev/null || true
fuser -k 7890/tcp 2>/dev/null || true

# 4. Use the simplest possible LiveKit setup
echo ""
echo "4. Starting LiveKit with simplest setup..."
docker run -d \
  --name livekit-simple \
  -p 7880:7880 \
  --restart unless-stopped \
  livekit/livekit-server:latest \
  --dev

# Wait a moment
sleep 3

# 5. Check if it's running
echo ""
echo "5. Checking LiveKit status..."
if docker ps | grep livekit-simple > /dev/null; then
    echo "✅ LiveKit is running!"
    echo ""
    echo "Testing LiveKit health:"
    curl -s http://localhost:7880 && echo "" || echo "LiveKit not responding to HTTP"
else
    echo "❌ LiveKit failed to start"
    echo ""
    echo "Checking logs (first 20 lines):"
    docker logs livekit-simple 2>&1 | head -20
    echo ""
    echo "Trying alternative approach..."
    
    # 6. Try with Docker Compose minimal
    docker stop livekit-simple 2>/dev/null
    docker rm livekit-simple 2>/dev/null
    
    cat > docker-compose.minimal.yml << 'EOF'
version: '3'

services:
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
    command: --dev
    restart: always
    
  app:
    image: node:18-alpine
    command: sh -c "cd /app && npm start"
    ports:
      - "3005:3005"
    volumes:
      - ./dental-calendar:/app
    environment:
      - LIVEKIT_URL=ws://livekit:7880
    depends_on:
      - livekit
    restart: always
EOF
    
    echo ""
    echo "Starting with minimal docker-compose..."
    docker-compose -f docker-compose.minimal.yml up -d livekit
fi

# 7. Final status check
echo ""
echo "6. Final status:"
docker ps | grep -E "NAME|livekit"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "If LiveKit is still not starting, try:"
echo "1. Reboot the VPS: sudo reboot"
echo "2. After reboot, run this script again"
echo "3. Or try running LiveKit directly:"
echo "   docker run -it --rm -p 7880:7880 livekit/livekit-server:latest --dev"