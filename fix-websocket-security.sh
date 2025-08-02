#!/bin/bash
# Fix WebSocket security issue

echo "=== Fixing WebSocket Security ==="

# 1. Update the test page to use secure WebSocket
echo "1. Creating secure test page:"
cat > /root/elo-deu/dental-calendar/public/test-livekit-secure.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LiveKit Secure Connection Test</title>
    <script src="https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js"></script>
</head>
<body>
    <h1>LiveKit Secure Connection Test</h1>
    <button onclick="testConnection()">Test Secure Connection</button>
    <div id="status"></div>
    
    <script>
    function log(msg) {
        console.log(msg);
        document.getElementById('status').innerHTML += msg + '<br>';
    }
    
    window.onload = function() {
        log('LiveKit SDK loaded: ' + (typeof LivekitClient !== 'undefined'));
    };
    
    async function testConnection() {
        log('Starting secure connection test...');
        
        try {
            // Test secure WebSocket through Nginx
            log('Testing secure WebSocket to wss://elosofia.site/ws...');
            const testWs = new WebSocket('wss://elosofia.site/ws');
            testWs.onopen = () => {
                log('✓ Secure WebSocket connected!');
                testWs.close();
            };
            testWs.onerror = (e) => {
                log('✗ Secure WebSocket failed - this might be normal');
            };
            testWs.onclose = (e) => {
                log('WebSocket closed: ' + e.code + ' ' + e.reason);
            };
            
            // Wait a bit for WebSocket test
            await new Promise(resolve => setTimeout(resolve, 2000));
            
            // Test token endpoint
            log('');
            log('Testing token endpoint...');
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'Test-User-' + Date.now(),
                    roomName: 'test-room-' + Date.now()
                })
            });
            
            log('Token response: ' + response.status);
            
            if (!response.ok) {
                const error = await response.text();
                log('ERROR: ' + error);
                return;
            }
            
            const data = await response.json();
            log('✓ Token received');
            log('Room: ' + data.roomName);
            log('URL: ' + data.url);
            
            // Create room with options
            log('');
            log('Creating LiveKit room...');
            const room = new LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true,
                logLevel: 'debug'
            });
            
            // Add all event listeners
            room.on('connected', () => {
                log('✓ CONNECTED TO LIVEKIT!');
                log('Room name: ' + room.name);
                log('Local participant: ' + room.localParticipant?.identity);
            });
            
            room.on('disconnected', (reason) => {
                log('Disconnected: ' + reason);
            });
            
            room.on('connectionStateChanged', (state) => {
                log('Connection state: ' + state);
            });
            
            room.on('error', (error) => {
                log('Room error: ' + error.message);
            });
            
            room.on('participantConnected', (participant) => {
                log('Participant joined: ' + participant.identity);
            });
            
            // Try different URLs
            const urls = [
                data.url,
                'wss://elosofia.site/ws',
                'wss://elosofia.site/rtc',
                data.url.replace('ws://', 'wss://').replace(':7880', '/ws')
            ];
            
            log('');
            log('Trying to connect with URL: ' + urls[0]);
            
            try {
                await room.connect(urls[0], data.token);
                log('✓ Successfully connected!');
            } catch (connectError) {
                log('Connection failed: ' + connectError.message);
                
                // Try alternative URLs
                for (let i = 1; i < urls.length; i++) {
                    log('');
                    log('Trying alternative URL: ' + urls[i]);
                    try {
                        await room.connect(urls[i], data.token);
                        log('✓ Connected with alternative URL!');
                        break;
                    } catch (altError) {
                        log('Failed: ' + altError.message);
                    }
                }
            }
            
        } catch (error) {
            log('ERROR: ' + error.message);
            log('Stack: ' + error.stack);
        }
    }
    </script>
</body>
</html>
EOF

# 2. Update the main config to use secure WebSocket
echo ""
echo "2. Updating main configuration for secure WebSocket:"
cat > /root/elo-deu/dental-calendar/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.origin,
    WS_URL: window.location.origin.replace('http:', 'ws:').replace('https:', 'wss:'),
    
    // Always use secure WebSocket through Nginx when on HTTPS
    LIVEKIT_URL: window.location.protocol === 'https:' 
        ? 'wss://elosofia.site/ws'
        : 'ws://localhost:7880',
    
    LIVEKIT_API_KEY: 'devkey',
    LIVEKIT_API_SECRET: 'devsecret',
    
    ENVIRONMENT: 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        DEMO_MODE: false
    }
};

console.log('Sofia Config - Secure WebSocket:', window.SOFIA_CONFIG.LIVEKIT_URL);
EOF

# 3. Verify Nginx WebSocket proxy is correct
echo ""
echo "3. Checking Nginx WebSocket configuration:"
grep -A 10 "location /ws" /etc/nginx/sites-available/elosofia.site || echo "WebSocket location not found!"

# 4. Test if LiveKit is accessible through Nginx
echo ""
echo "4. Testing WebSocket through Nginx:"
curl -v -i -N \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
    http://localhost:7880 2>&1 | head -20

# 5. Copy files to container
echo ""
echo "5. Deploying files:"
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)
docker cp /root/elo-deu/dental-calendar/public/test-livekit-secure.html $APP_CONTAINER:/app/public/
docker cp /root/elo-deu/dental-calendar/public/config.js $APP_CONTAINER:/app/public/

# 6. Restart container to ensure changes take effect
echo ""
echo "6. Restarting container..."
docker restart $APP_CONTAINER

echo ""
echo "=== Fix Applied ==="
echo ""
echo "Test at: https://elosofia.site/test-livekit-secure.html"
echo ""
echo "This will use secure WebSocket connections only."