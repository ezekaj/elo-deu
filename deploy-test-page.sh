#!/bin/bash
# Deploy the test page to the container

echo "=== Deploying Test Page ==="

# 1. Create the test page
echo "1. Creating test-livekit-secure.html..."
cat > dental-calendar/public/test-livekit-secure.html << 'EOF'
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
            
            // Connect with the URL from server
            log('');
            log('Connecting to: ' + data.url);
            
            try {
                await room.connect(data.url, data.token);
                log('✓ Successfully connected!');
            } catch (connectError) {
                log('Connection failed: ' + connectError.message);
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

echo "✓ Created test-livekit-secure.html"

# 2. Copy to container
echo ""
echo "2. Copying to container..."
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)

if [ -z "$APP_CONTAINER" ]; then
    echo "❌ No app container found!"
    exit 1
fi

docker cp dental-calendar/public/test-livekit-secure.html $APP_CONTAINER:/app/public/

echo "✓ Copied to container: $APP_CONTAINER"

# 3. Verify file exists
echo ""
echo "3. Verifying file in container..."
docker exec $APP_CONTAINER ls -la /app/public/test-livekit-secure.html

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Test at: https://elosofia.site/test-livekit-secure.html"