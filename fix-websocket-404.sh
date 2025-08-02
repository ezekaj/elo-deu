#!/bin/bash
# Fix WebSocket 404 error

echo "=== Fixing WebSocket 404 Error ==="

# 1. Create correct Nginx configuration
echo "1. Creating fixed Nginx configuration..."
cat > /etc/nginx/sites-available/elosofia.site << 'EOF'
server {
    listen 80;
    server_name elosofia.site www.elosofia.site;
    return 301 https://$server_name$request_uri;
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

    # LiveKit WebSocket - must come before other locations
    location /ws {
        proxy_pass http://127.0.0.1:7880/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Important for WebSocket
        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
        proxy_buffering off;
        proxy_request_buffering off;
        
        # Remove any path from the proxied request
        proxy_redirect off;
    }

    # LiveKit HTTP endpoints
    location /rtc {
        proxy_pass http://127.0.0.1:7880/rtc;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /twirp {
        proxy_pass http://127.0.0.1:7880/twirp;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

echo "✓ Nginx configuration updated"

# 2. Test Nginx configuration
echo ""
echo "2. Testing Nginx configuration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx configuration is valid"
    
    # 3. Reload Nginx
    echo ""
    echo "3. Reloading Nginx..."
    systemctl reload nginx
    echo "✓ Nginx reloaded"
else
    echo "❌ Nginx configuration has errors!"
    exit 1
fi

# 4. Test WebSocket endpoint directly
echo ""
echo "4. Testing WebSocket endpoint..."
curl -v -i -N \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
    https://elosofia.site/ws 2>&1 | grep -E "HTTP|101|404|WebSocket"

# 5. Update config to use correct LiveKit URL
echo ""
echo "5. Updating client configuration..."
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)

docker exec $APP_CONTAINER sh -c "cat > /app/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.origin,
    WS_URL: window.location.origin.replace('http:', 'ws:').replace('https:', 'wss:'),
    
    // LiveKit URL mapping
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

console.log('Sofia Config Updated:', {
    protocol: window.location.protocol,
    livekitUrl: window.SOFIA_CONFIG.LIVEKIT_URL
});
EOF"

echo "✓ Configuration updated"

# 6. Create a simple WebSocket test
echo ""
echo "6. Creating WebSocket test page..."
cat > /tmp/ws-simple-test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Simple WebSocket Test</title>
</head>
<body>
    <h1>Simple WebSocket Test</h1>
    <button onclick="testWS()">Test WebSocket</button>
    <div id="log"></div>
    
    <script>
    function log(msg) {
        document.getElementById('log').innerHTML += msg + '<br>';
        console.log(msg);
    }
    
    function testWS() {
        log('Testing wss://elosofia.site/ws ...');
        const ws = new WebSocket('wss://elosofia.site/ws');
        
        ws.onopen = () => log('✅ WebSocket opened!');
        ws.onerror = (e) => log('❌ WebSocket error');
        ws.onclose = (e) => log('WebSocket closed: ' + e.code + ' ' + e.reason);
        ws.onmessage = (e) => log('Message: ' + e.data);
    }
    </script>
</body>
</html>
EOF

docker cp /tmp/ws-simple-test.html $APP_CONTAINER:/app/public/

echo "✓ Test page created"

echo ""
echo "=== Fix Applied ==="
echo ""
echo "Test WebSocket at: https://elosofia.site/ws-simple-test.html"
echo "Test Sofia at: https://elosofia.site/sofia-debug-detailed.html"