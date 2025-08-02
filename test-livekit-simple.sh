#!/bin/bash
# Simple test to check LiveKit connection

echo "=== Simple LiveKit Connection Test ==="

# 1. Check if sofia-voice-debug.js was added
echo "1. Checking if debug script exists:"
ls -la /root/elo-deu/dental-calendar/public/sofia-voice-debug.js

# 2. Test LiveKit WebSocket directly
echo ""
echo "2. Testing LiveKit WebSocket connection:"
curl -v -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" \
  -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" \
  https://elosofia.site/ws 2>&1 | grep -E "HTTP|Connected|Error|failed"

# 3. Create a simple test page
echo ""
echo "3. Creating simple test page..."
cat > /root/elo-deu/dental-calendar/public/test-livekit.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LiveKit Connection Test</title>
    <script src="https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js"></script>
</head>
<body>
    <h1>LiveKit Connection Test</h1>
    <button onclick="testConnection()">Test LiveKit Connection</button>
    <div id="status"></div>
    
    <script>
    function log(msg) {
        console.log(msg);
        document.getElementById('status').innerHTML += msg + '<br>';
    }
    
    async function testConnection() {
        log('Starting test...');
        
        // Check if SDK loaded
        if (typeof livekit === 'undefined') {
            log('ERROR: LiveKit SDK not found!');
            return;
        }
        log('✓ LiveKit SDK loaded');
        
        try {
            // Test token endpoint
            log('Testing token endpoint...');
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'Test-User',
                    roomName: 'test-room'
                })
            });
            
            log('Token response: ' + response.status);
            
            if (!response.ok) {
                log('ERROR: Token request failed');
                return;
            }
            
            const data = await response.json();
            log('Token received');
            log('URL: ' + data.url);
            
            // Try to create room
            log('Creating room...');
            const room = new livekit.Room();
            
            room.on('connected', () => log('✓ CONNECTED!'));
            room.on('disconnected', () => log('Disconnected'));
            room.on('error', (e) => log('ERROR: ' + e.message));
            
            log('Connecting to: ' + data.url);
            await room.connect(data.url, data.token);
            
        } catch (error) {
            log('ERROR: ' + error.message);
        }
    }
    </script>
</body>
</html>
EOF

# 4. Check if the app can reach LiveKit internally
echo ""
echo "4. Testing internal LiveKit connection:"
docker exec $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1) \
  wget -O- http://livekit:7880 2>&1 | grep -E "404|refused|connected" || echo "No response"

# 5. Check LiveKit container status
echo ""
echo "5. LiveKit container status:"
docker ps | grep livekit
docker logs $(docker ps --format "{{.Names}}" | grep livekit | head -1) --tail 5 2>&1

echo ""
echo "=== Test Complete ==="
echo ""
echo "To test manually:"
echo "1. Go to https://elosofia.site/test-livekit.html"
echo "2. Click 'Test LiveKit Connection'"
echo "3. Check the output on the page"