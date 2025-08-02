#!/bin/bash
# Fix Sofia agent connection issues

echo "=== Fixing Sofia Agent Connection ==="

# 1. Check if LiveKit is actually running
echo "1. Checking LiveKit status:"
LIVEKIT_RUNNING=$(docker ps | grep livekit | wc -l)
if [ $LIVEKIT_RUNNING -eq 0 ]; then
    echo "❌ LiveKit is NOT running!"
else
    echo "✅ LiveKit is running"
    docker ps | grep livekit
fi
echo ""

# 2. Check LiveKit logs for errors
echo "2. LiveKit logs:"
docker logs $(docker ps --format "{{.Names}}" | grep livekit | head -1) --tail 20 2>&1 || echo "No LiveKit container found"
echo ""

# 3. Test LiveKit port accessibility
echo "3. Testing LiveKit ports:"
nc -zv localhost 7880 && echo "✅ Port 7880 is open" || echo "❌ Port 7880 is closed"
nc -zv localhost 7881 && echo "✅ Port 7881 is open" || echo "❌ Port 7881 is closed"
echo ""

# 4. Update Nginx to properly proxy WebSocket
echo "4. Updating Nginx WebSocket configuration..."
cat > /tmp/nginx-ws-fix.conf << 'EOF'
# WebSocket configuration
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name elosofia.site www.elosofia.site;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name elosofia.site www.elosofia.site;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/elosofia.site/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/elosofia.site/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

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

    # Socket.IO
    location /socket.io/ {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # LiveKit WebSocket - Multiple endpoints for compatibility
    location /ws {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Disable buffering for WebSocket
        proxy_buffering off;
        proxy_read_timeout 86400;
    }

    # LiveKit RTC endpoint
    location /rtc {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_buffering off;
    }
}
EOF

# Backup current config and apply new one
cp /etc/nginx/sites-available/elosofia.site /etc/nginx/sites-available/elosofia.site.backup
cp /tmp/nginx-ws-fix.conf /etc/nginx/sites-available/elosofia.site
nginx -t && systemctl reload nginx
echo ""

# 5. Update client config to use multiple connection methods
echo "5. Updating client configuration..."
cat > /root/elo-deu/dental-calendar/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.origin,
    WS_URL: window.location.origin.replace('https:', 'wss:').replace('http:', 'ws:'),
    
    // LiveKit URLs - try multiple options
    LIVEKIT_URL: window.location.protocol === 'https:' 
        ? 'wss://elosofia.site/ws'           // Primary: Through Nginx proxy
        : 'ws://167.235.67.1:7880',          // Fallback: Direct connection
    
    // Alternative LiveKit URLs for debugging
    LIVEKIT_URL_ALTERNATIVES: [
        'wss://elosofia.site/ws',            // Through Nginx
        'wss://elosofia.site/rtc',           // Alternative path
        'ws://167.235.67.1:7880',            // Direct IP
        'ws://elosofia.site:7880'            // Direct port
    ],
    
    LIVEKIT_API_KEY: 'devkey',
    LIVEKIT_API_SECRET: 'devsecret',
    
    ENVIRONMENT: 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        DEMO_MODE: false
    }
};

console.log('Sofia Config:', window.SOFIA_CONFIG);
console.log('Primary LiveKit URL:', window.SOFIA_CONFIG.LIVEKIT_URL);
EOF

# 6. Restart containers to ensure clean state
echo "6. Restarting containers..."
cd /root/elo-deu
docker-compose -f docker-compose.final.yml restart
sleep 5

# 7. Open all necessary ports
echo "7. Ensuring firewall allows WebSocket connections..."
ufw allow 7880/tcp
ufw allow 7881/tcp
ufw allow 443/tcp
ufw reload

# 8. Test the connection
echo ""
echo "8. Testing WebSocket connection:"
timeout 2 bash -c 'echo -e "GET /ws HTTP/1.1\r\nHost: elosofia.site\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: test\r\nSec-WebSocket-Version: 13\r\n\r\n" | nc localhost 7880' || echo "Direct WebSocket test completed"

echo ""
echo "=== Fix Applied ==="
echo ""
echo "Sofia should now be accessible. Try:"
echo "1. Clear browser cache (Ctrl+Shift+R)"
echo "2. Click the Sofia voice button"
echo "3. Check browser console for any remaining errors"
echo ""
echo "If still not working, check:"
echo "- Browser console for WebSocket errors"
echo "- docker logs for LiveKit errors"