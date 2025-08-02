#!/bin/bash
# Fix WebSocket 502 error - LiveKit connection issue

echo "=== Fixing WebSocket 502 Error ==="

# 1. Check if LiveKit is actually running
echo "1. Checking LiveKit status..."
docker ps | grep livekit
if [ $? -ne 0 ]; then
    echo "❌ LiveKit is not running!"
    echo "Starting LiveKit..."
    docker-compose up -d livekit
    sleep 5
fi

# 2. Test LiveKit directly
echo ""
echo "2. Testing LiveKit on port 7880..."
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:7880
curl -s http://localhost:7880/healthz && echo " ✓ LiveKit is healthy" || echo " ❌ LiveKit not responding"

# 3. Fix Nginx configuration for /ws/rtc path
echo ""
echo "3. Updating Nginx configuration..."
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
        proxy_pass http://127.0.0.1:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Socket.io
    location /socket.io/ {
        proxy_pass http://127.0.0.1:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # LiveKit WebSocket - all paths under /ws
    location /ws {
        proxy_pass http://127.0.0.1:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket specific settings
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        proxy_connect_timeout 60s;
        
        # Disable buffering for WebSocket
        proxy_buffering off;
        proxy_request_buffering off;
        tcp_nodelay on;
        
        # Handle all sub-paths
        proxy_redirect off;
    }
}
EOF

# 4. Test and reload Nginx
echo ""
echo "4. Testing Nginx configuration..."
nginx -t
if [ $? -eq 0 ]; then
    echo "✓ Nginx configuration valid"
    systemctl reload nginx
    echo "✓ Nginx reloaded"
else
    echo "❌ Nginx configuration error!"
    exit 1
fi

# 5. Test WebSocket endpoints
echo ""
echo "5. Testing WebSocket endpoints..."
echo "Testing /ws endpoint:"
curl -v -i -N \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
    http://localhost:7880 2>&1 | grep -E "HTTP|101" | head -5

# 6. Restart the app to ensure fresh connections
echo ""
echo "6. Restarting app container..."
docker restart dental-app

# 7. Show final status
echo ""
echo "7. Final status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "The WebSocket proxy is now configured to handle:"
echo "- /ws -> LiveKit WebSocket"
echo "- /ws/rtc -> LiveKit RTC endpoint"
echo "- /socket.io -> App Socket.io"
echo ""
echo "Try clicking the Sofia button again!"