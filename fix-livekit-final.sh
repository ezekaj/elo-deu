#!/bin/bash
# Final comprehensive LiveKit fix

echo "=== Final LiveKit Fix ==="

# 1. First, check if LiveKit is actually running and accessible
echo "1. Checking LiveKit status..."
LIVEKIT_RUNNING=$(docker ps | grep livekit | wc -l)
if [ "$LIVEKIT_RUNNING" -eq "0" ]; then
    echo "❌ LiveKit container is not running!"
    echo "Starting LiveKit..."
    docker-compose -f docker-compose.production.yml up -d livekit
    sleep 10
fi

# 2. Test LiveKit directly
echo ""
echo "2. Testing LiveKit on localhost:7880..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:7880 || echo "Cannot reach LiveKit"

# 3. Create a working docker-compose configuration
echo ""
echo "3. Creating final working configuration..."
cat > docker-compose.working.yml << 'EOF'
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:v1.5.3
    container_name: livekit
    ports:
      - "7880:7880"
      - "7881:7881"
    environment:
      - LIVEKIT_KEYS=devkey:secret
      - LIVEKIT_LOG_LEVEL=info
    command: >
      --dev
      --bind 0.0.0.0
      --node-ip 127.0.0.1
    restart: unless-stopped
    networks:
      - dental-net

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
      - LIVEKIT_HOST=livekit
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
    depends_on:
      - livekit
    volumes:
      - ./dental-calendar/database:/app/database
    restart: unless-stopped
    networks:
      - dental-net

networks:
  dental-net:
    driver: bridge
EOF

# 4. Update Nginx to properly proxy WebSocket
echo ""
echo "4. Updating Nginx configuration..."
cat > /etc/nginx/sites-available/elosofia.site << 'EOF'
server {
    listen 80;
    server_name elosofia.site www.elosofia.site;
    return 301 https://$server_name$request_uri;
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 443 ssl;
    server_name elosofia.site www.elosofia.site;

    ssl_certificate /etc/letsencrypt/live/elosofia.site/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/elosofia.site/privkey.pem;

    # Main app
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # LiveKit WebSocket endpoint
    location /ws {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket specific
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_connect_timeout 60s;
        proxy_buffering off;
        tcp_nodelay on;
    }

    # LiveKit HTTP/RTC endpoints
    location ~ ^/(rtc|twirp) {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 5. Create a server patch to return correct URLs
echo ""
echo "5. Creating server patch..."
cat > patch-server-urls.sh << 'EOF'
#!/bin/bash
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)

# Update server to return correct URL based on client
docker exec $APP_CONTAINER sh -c "cat > /tmp/sofia-patch.js << 'PATCH'
// In /api/sofia/connect endpoint, ensure correct URL is returned:

const isHttps = req.get('x-forwarded-proto') === 'https';
const clientUrl = isHttps ? 'wss://elosofia.site/ws' : 'ws://localhost:7880';

res.json({
    token: jwt,
    url: clientUrl,  // Use client-appropriate URL
    roomName: roomName
});
PATCH"

echo "Server patch created - apply manually to server.js"
EOF
chmod +x patch-server-urls.sh

# 6. Restart everything
echo ""
echo "6. Restarting services..."
docker-compose -f docker-compose.working.yml down
docker-compose -f docker-compose.working.yml up -d

# Wait for services
echo "Waiting for services to start..."
sleep 15

# 7. Test everything
echo ""
echo "7. Running tests..."
echo "LiveKit health check:"
curl -s http://localhost:7880/healthz && echo " ✓ LiveKit is healthy" || echo " ❌ LiveKit health check failed"

echo ""
echo "WebSocket test through Nginx:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    https://elosofia.site/ws

echo ""
echo "Container status:"
docker ps | grep -E "livekit|dental"

# 8. Apply Nginx changes
echo ""
echo "8. Applying Nginx changes..."
nginx -t && systemctl reload nginx

echo ""
echo "=== Fix Complete ==="
echo ""
echo "LiveKit should now be accessible at:"
echo "- Direct: ws://167.235.67.1:7880"
echo "- Secure: wss://elosofia.site/ws"
echo ""
echo "Test at: https://elosofia.site/sofia-debug-detailed.html"