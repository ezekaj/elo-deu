#!/bin/bash
# Test LiveKit bypassing all proxies

echo "=== Testing LiveKit Direct Connection ==="

# 1. Check if LiveKit is actually running
echo "1. Checking LiveKit container:"
docker ps | grep livekit
echo ""

# 2. Check LiveKit logs for errors
echo "2. LiveKit logs (last 20 lines):"
docker logs $(docker ps --format "{{.Names}}" | grep livekit) --tail 20 2>&1
echo ""

# 3. Test direct connection to LiveKit
echo "3. Testing direct HTTP connection to LiveKit:"
curl -v http://localhost:7880 2>&1 | grep -E "Connected|HTTP|refused"
echo ""

# 4. Check if port 7880 is actually open
echo "4. Checking port 7880:"
netstat -tlnp | grep 7880 || echo "Port 7880 not found in netstat"
echo ""

# 5. Test from inside the network
echo "5. Testing LiveKit from app container:"
docker exec $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1) \
    curl -s http://livekit:7880 || echo "Cannot reach LiveKit from app container"
echo ""

# 6. Create a bypass test page
echo "6. Creating bypass test page..."
cat > dental-calendar/public/test-bypass.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LiveKit Bypass Test</title>
    <script src="https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js"></script>
</head>
<body>
    <h1>LiveKit Direct Connection Test (Bypass Proxy)</h1>
    <p>This test connects directly to LiveKit on port 7880</p>
    <button onclick="testDirect()">Test Direct Connection</button>
    <div id="log"></div>
    
    <script>
    function log(msg) {
        document.getElementById('log').innerHTML += msg + '<br>';
        console.log(msg);
    }
    
    async function testDirect() {
        log('Starting direct connection test...');
        
        try {
            // Get token from server
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'Bypass-Test-' + Date.now(),
                    roomName: 'bypass-test-' + Date.now()
                })
            });
            
            const data = await response.json();
            log('Token received for room: ' + data.roomName);
            
            // Try direct connection to port 7880
            const directUrl = 'ws://167.235.67.1:7880';
            log('');
            log('Attempting direct connection to: ' + directUrl);
            
            const room = new LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true,
                logLevel: 'debug'
            });
            
            room.on('connected', () => {
                log('✅ CONNECTED DIRECTLY TO LIVEKIT!');
                log('This confirms LiveKit is working!');
                log('The issue is with the proxy configuration.');
            });
            
            room.on('connectionStateChanged', (state) => {
                log('State: ' + state);
            });
            
            room.on('error', (error) => {
                log('Error: ' + error.message);
            });
            
            await room.connect(directUrl, data.token);
            
        } catch (error) {
            log('Error: ' + error.message);
            
            // Also try localhost
            log('');
            log('Testing WebSocket to localhost:7880...');
            try {
                const ws = new WebSocket('ws://localhost:7880');
                ws.onopen = () => log('✓ WebSocket opened to localhost');
                ws.onerror = () => log('✗ WebSocket error on localhost');
                ws.onclose = (e) => log('WebSocket closed: ' + e.code);
            } catch (e) {
                log('Cannot create WebSocket: ' + e.message);
            }
        }
    }
    
    // Also test if we can reach the VPS directly
    log('Your VPS IP: 167.235.67.1');
    log('Direct LiveKit URL would be: ws://167.235.67.1:7880');
    </script>
</body>
</html>
EOF

# Deploy the bypass test
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)
docker cp dental-calendar/public/test-bypass.html $APP_CONTAINER:/app/public/

echo "✓ Created test-bypass.html"
echo ""
echo "7. Opening port 7880 in firewall (if needed):"
# Check if ufw is active
if command -v ufw &> /dev/null; then
    sudo ufw status | grep 7880 || sudo ufw allow 7880/tcp
fi

# Check iptables
sudo iptables -L INPUT -n | grep 7880 || echo "Port 7880 not in iptables rules"

echo ""
echo "=== Test Complete ==="
echo ""
echo "Access: https://elosofia.site/test-bypass.html"
echo "This will test direct connection to LiveKit on port 7880"