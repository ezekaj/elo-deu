#!/bin/bash
# Fix LiveKit URL in server response

echo "=== Fixing LiveKit URL Configuration ==="

# 1. Create a server patch to return the correct URL
echo "1. Creating server URL fix..."
cat > patch-livekit-url.sh << 'EOF'
#!/bin/bash
# Patch the server to return correct LiveKit URL

APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)

echo "Patching server in container: $APP_CONTAINER"

# Create a patch file
docker exec $APP_CONTAINER sh -c "cat > /tmp/url-patch.js << 'PATCH'
// Find the /api/sofia/connect endpoint and update it to return correct URL

// The response should return the internal URL for LiveKit
// but we need to handle the client-side connection differently

// Look for lines like:
// url: LIVEKIT_URL,
// or
// url: 'ws://elosofia.site:7880',

// And ensure it returns:
// url: 'ws://livekit:7880',
PATCH"

# Apply the patch - update the server to return internal URL
docker exec $APP_CONTAINER sh -c "
sed -i \"s|url: .*LIVEKIT_URL.*|url: 'ws://livekit:7880',|g\" server.js
sed -i \"s|url: 'ws://elosofia.site:7880'|url: 'ws://livekit:7880'|g\" server.js
"

echo "✓ Server patched to return internal URL"
EOF

chmod +x patch-livekit-url.sh

# 2. Update the test page to handle URL mapping
echo ""
echo "2. Updating test page with URL mapping..."
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
            // Test token endpoint
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
            log('Server URL: ' + data.url);
            
            // Map internal URL to public WebSocket URL
            let connectUrl = data.url;
            if (connectUrl.includes('livekit:7880') || connectUrl.includes('elosofia.site:7880')) {
                // When on HTTPS, use secure WebSocket through Nginx
                if (window.location.protocol === 'https:') {
                    connectUrl = 'wss://elosofia.site/ws';
                    log('Mapped to secure URL: ' + connectUrl);
                } else {
                    connectUrl = 'ws://167.235.67.1:7880';
                    log('Mapped to direct URL: ' + connectUrl);
                }
            }
            
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
                log('');
                log('🎉 SUCCESS! LiveKit is working!');
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
            
            // Connect with mapped URL
            log('');
            log('Connecting to: ' + connectUrl);
            
            try {
                await room.connect(connectUrl, data.token);
                log('✓ Connection initiated');
            } catch (connectError) {
                log('Connection failed: ' + connectError.message);
                
                // Try alternative URLs
                const alternatives = [
                    'wss://elosofia.site/rtc',
                    'ws://167.235.67.1:7880'
                ];
                
                for (const altUrl of alternatives) {
                    log('');
                    log('Trying alternative: ' + altUrl);
                    try {
                        await room.connect(altUrl, data.token);
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

echo "✓ Updated test page with URL mapping"

# 3. Update config.js with proper URL mapping
echo ""
echo "3. Updating config.js..."
cat > dental-calendar/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.origin,
    WS_URL: window.location.origin.replace('http:', 'ws:').replace('https:', 'wss:'),
    
    // Map LiveKit URL based on protocol
    LIVEKIT_URL: window.location.protocol === 'https:' 
        ? 'wss://elosofia.site/ws'
        : 'ws://localhost:7880',
    
    // Internal URL for server-side
    LIVEKIT_INTERNAL_URL: 'ws://livekit:7880',
    
    LIVEKIT_API_KEY: 'devkey',
    LIVEKIT_API_SECRET: 'secret',
    
    ENVIRONMENT: 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        DEMO_MODE: false
    }
};

console.log('Sofia Config:', {
    protocol: window.location.protocol,
    livekitUrl: window.SOFIA_CONFIG.LIVEKIT_URL
});
EOF

echo "✓ Updated config.js"

# 4. Create deployment script
echo ""
echo "4. Creating deployment script..."
cat > deploy-url-fix.sh << 'EOF'
#!/bin/bash
# Deploy URL fix

echo "Deploying URL fix..."

# 1. Apply server patch
./patch-livekit-url.sh

# 2. Copy updated files to container
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)
docker cp dental-calendar/public/test-livekit-secure.html $APP_CONTAINER:/app/public/
docker cp dental-calendar/public/config.js $APP_CONTAINER:/app/public/

# 3. Restart app
docker restart $APP_CONTAINER

echo ""
echo "Waiting for restart..."
sleep 5

echo ""
echo "✓ URL fix deployed!"
echo ""
echo "Test at: https://elosofia.site/test-livekit-secure.html"
EOF

chmod +x deploy-url-fix.sh

echo ""
echo "=== Fix Created ==="
echo ""
echo "To apply, run:"
echo "./deploy-url-fix.sh"