#!/bin/bash
# Fix Nginx WebSocket proxy configuration

echo "=== Fixing Nginx WebSocket Proxy ==="

# 1. Create proper Nginx configuration
echo "1. Creating updated Nginx configuration..."
cat > nginx-websocket-fix.conf << 'EOF'
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

    # Main app proxy
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # LiveKit WebSocket proxy - primary endpoint
    location /ws {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket specific settings
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60s;
        
        # Disable buffering for WebSocket
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # LiveKit RTC endpoint
    location /rtc {
        proxy_pass http://localhost:7880/rtc;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket specific settings
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        proxy_connect_timeout 60s;
        
        # Disable buffering for WebSocket
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # LiveKit TWIRP endpoint (for RPC calls)
    location /twirp {
        proxy_pass http://localhost:7880/twirp;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

echo "✓ Created nginx-websocket-fix.conf"

# 2. Test LiveKit directly
echo ""
echo "2. Creating LiveKit connection test..."
cat > test-livekit-direct.sh << 'EOF'
#!/bin/bash
# Test LiveKit connection directly

echo "Testing LiveKit endpoints..."

# Test LiveKit HTTP endpoint
echo "1. Testing LiveKit HTTP:"
curl -s http://localhost:7880/ | head -5

# Test WebSocket upgrade
echo ""
echo "2. Testing WebSocket upgrade:"
curl -v -i -N \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
    http://localhost:7880 2>&1 | grep -E "HTTP|Upgrade|Connection"

# Check LiveKit logs
echo ""
echo "3. LiveKit recent logs:"
docker logs $(docker ps --format "{{.Names}}" | grep livekit) --tail 10 2>&1
EOF

chmod +x test-livekit-direct.sh

# 3. Create deployment script
echo ""
echo "3. Creating deployment script..."
cat > deploy-nginx-fix.sh << 'EOF'
#!/bin/bash
# Deploy Nginx fix

echo "Deploying Nginx WebSocket fix..."

# 1. Backup current config
sudo cp /etc/nginx/sites-available/elosofia.site /etc/nginx/sites-available/elosofia.site.backup

# 2. Update Nginx config
sudo cp nginx-websocket-fix.conf /etc/nginx/sites-available/elosofia.site

# 3. Test Nginx config
echo "Testing Nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx config is valid"
    
    # 4. Reload Nginx
    sudo systemctl reload nginx
    echo "✓ Nginx reloaded"
else
    echo "❌ Nginx config has errors! Restoring backup..."
    sudo cp /etc/nginx/sites-available/elosofia.site.backup /etc/nginx/sites-available/elosofia.site
    exit 1
fi

# 5. Test LiveKit connection
echo ""
./test-livekit-direct.sh

echo ""
echo "✓ Nginx WebSocket proxy updated!"
echo ""
echo "Test at: https://elosofia.site/test-livekit-secure.html"
EOF

chmod +x deploy-nginx-fix.sh

# 4. Create a simple WebSocket test
echo ""
echo "4. Creating simple WebSocket test..."
cat > dental-calendar/public/ws-test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>WebSocket Test</title>
</head>
<body>
    <h1>WebSocket Proxy Test</h1>
    <button onclick="testWS()">Test WebSocket</button>
    <div id="log"></div>
    
    <script>
    function log(msg) {
        document.getElementById('log').innerHTML += msg + '<br>';
        console.log(msg);
    }
    
    function testWS() {
        log('Testing WebSocket connections...');
        
        // Test different endpoints
        const endpoints = [
            'wss://elosofia.site/ws',
            'wss://elosofia.site/rtc',
            'ws://167.235.67.1:7880'
        ];
        
        endpoints.forEach(url => {
            log('');
            log('Testing: ' + url);
            try {
                const ws = new WebSocket(url);
                ws.onopen = () => log('✓ Connected to ' + url);
                ws.onerror = (e) => log('✗ Error on ' + url);
                ws.onclose = (e) => log('Closed ' + url + ': ' + e.code + ' ' + e.reason);
                
                setTimeout(() => {
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.close();
                    }
                }, 3000);
            } catch (e) {
                log('✗ Failed to create WebSocket: ' + e.message);
            }
        });
    }
    </script>
</body>
</html>
EOF

echo "✓ Created ws-test.html"

echo ""
echo "=== Fix Created ==="
echo ""
echo "To deploy, run:"
echo "./deploy-nginx-fix.sh"
echo ""
echo "This will:"
echo "1. Update Nginx with proper WebSocket proxy configuration"
echo "2. Test the configuration before applying"
echo "3. Verify LiveKit is accessible"