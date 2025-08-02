#!/bin/bash
# Debug LiveKit connection issues

echo "=== Debugging LiveKit Connection ==="

# 1. Check if LiveKit container is running
echo "1. Checking LiveKit container..."
docker ps | grep livekit
echo ""

# 2. Check LiveKit logs
echo "2. LiveKit logs (last 20 lines):"
docker logs elo-deu_livekit_1 --tail 20
echo ""

# 3. Test LiveKit internally
echo "3. Testing LiveKit from inside container:"
docker exec elo-deu_app_1 wget -qO- http://livekit:7880 || echo "No HTTP endpoint"
echo ""

# 4. Test WebSocket connection
echo "4. Testing WebSocket connection:"
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: test" http://localhost:7880/rtc
echo ""

# 5. Check Nginx error logs
echo "5. Recent Nginx errors:"
tail -20 /var/log/nginx/error.log | grep -E "livekit|ws|websocket" || echo "No WebSocket errors in Nginx logs"
echo ""

# 6. Test from outside
echo "6. Testing WebSocket proxy through Nginx:"
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: test" https://elosofia.site/ws
echo ""

# 7. Update LiveKit to use external IP
echo "7. Updating LiveKit configuration for external access..."
cat > /root/elo-deu/docker-compose.final.yml << 'EOF'
version: '3.8'

services:
  # LiveKit Server - Dev mode with external access
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
      - "7881:7881"
    environment:
      - LIVEKIT_RTC_USE_EXTERNAL_IP=true
    command: --dev --bind 0.0.0.0
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:7880/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Dental Calendar Application
  app:
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile.simple
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=devsecret
    depends_on:
      - livekit
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3005/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

# 8. Restart containers with new config
echo "8. Restarting containers with updated configuration..."
cd /root/elo-deu
docker-compose -f docker-compose.final.yml down
docker-compose -f docker-compose.final.yml up -d

# 9. Open firewall for LiveKit ports (in case direct connection is needed)
echo "9. Opening firewall ports..."
ufw allow 7880/tcp
ufw allow 7881/tcp
ufw reload

echo ""
echo "=== Debug complete ==="
echo "Check the output above for any errors."
echo "LiveKit should now be accessible through wss://elosofia.site/ws"