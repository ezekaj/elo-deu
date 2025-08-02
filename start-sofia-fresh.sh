#!/bin/bash
# Start Sofia fresh and properly

echo "=== Starting Sofia Fresh ==="

# 1. Make sure everything is clean
echo "1. Ensuring clean state..."
docker ps -a | grep -E "livekit|dental|sofia" | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null
docker network prune -f

# 2. Create simple working configuration
echo ""
echo "2. Creating working configuration..."
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit
    ports:
      - "7880:7880"
    command: --dev
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "-O-", "http://localhost:7880/healthz"]
      interval: 5s
      timeout: 3s
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
      livekit:
        condition: service_healthy
    volumes:
      - ./dental-calendar/database:/app/database
      - ./dental-calendar/public:/app/public
    restart: unless-stopped
EOF

# 3. Start services
echo ""
echo "3. Starting services..."
docker-compose up -d

# 4. Wait for services
echo ""
echo "4. Waiting for services to start..."
for i in {1..30}; do
    if docker ps | grep -q "livekit.*Up" && docker ps | grep -q "dental-app.*Up"; then
        echo "✅ Services are up!"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

# 5. Check status
echo ""
echo "5. Service status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 6. Test LiveKit
echo ""
echo "6. Testing LiveKit..."
if curl -s http://localhost:7880/healthz > /dev/null; then
    echo "✅ LiveKit is healthy!"
else
    echo "❌ LiveKit not responding"
    echo "LiveKit logs:"
    docker logs livekit --tail 20
fi

# 7. Test app
echo ""
echo "7. Testing app..."
if curl -s http://localhost:3005 > /dev/null; then
    echo "✅ App is responding!"
else
    echo "❌ App not responding"
    echo "App logs:"
    docker logs dental-app --tail 20
fi

# 8. Update Nginx
echo ""
echo "8. Ensuring Nginx is configured..."
if [ -f /etc/nginx/sites-available/elosofia.site ]; then
    nginx -t && systemctl reload nginx
    echo "✅ Nginx reloaded"
else
    echo "⚠️  Nginx configuration not found"
fi

echo ""
echo "=== Sofia Started ==="
echo ""
echo "Services running:"
docker ps --format "table {{.Names}}\t{{.Status}}"
echo ""
echo "Access Sofia at: https://elosofia.site"
echo ""
echo "To check logs:"
echo "- LiveKit: docker logs -f livekit"
echo "- App: docker logs -f dental-app"
echo ""
echo "To test connection in browser console:"
echo "sofiaDebug.connect()"