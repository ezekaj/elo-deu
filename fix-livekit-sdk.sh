#!/bin/bash
# Fix LiveKit SDK loading issue

echo "=== Fixing LiveKit SDK Loading ==="

# 1. Check if the CDN is accessible
echo "1. Testing LiveKit CDN:"
curl -I https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js | head -5

# 2. Download LiveKit SDK locally
echo ""
echo "2. Downloading LiveKit SDK locally:"
cd /root/elo-deu/dental-calendar/public
wget -O livekit-client.umd.js https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js

# 3. Update test file to check different SDK locations
echo ""
echo "3. Creating updated test file:"
cat > test-livekit-fixed.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LiveKit Connection Test - Fixed</title>
    <script src="https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js"></script>
    <script src="livekit-client.umd.js"></script>
</head>
<body>
    <h1>LiveKit Connection Test - Fixed</h1>
    <button onclick="testConnection()">Test LiveKit Connection</button>
    <div id="status"></div>
    
    <script>
    function log(msg) {
        console.log(msg);
        document.getElementById('status').innerHTML += msg + '<br>';
    }
    
    // Check multiple possible SDK locations
    window.onload = function() {
        log('Checking for LiveKit SDK...');
        
        if (typeof LivekitClient !== 'undefined') {
            log('✓ Found LivekitClient (global)');
            window.livekit = LivekitClient;
        } else if (typeof livekit !== 'undefined') {
            log('✓ Found livekit (global)');
        } else if (window.LivekitClient) {
            log('✓ Found window.LivekitClient');
            window.livekit = window.LivekitClient;
        } else if (window.livekit) {
            log('✓ Found window.livekit');
        } else {
            log('❌ LiveKit SDK not found in any location!');
            log('Checking all window properties...');
            for (let prop in window) {
                if (prop.toLowerCase().includes('livekit') || prop.toLowerCase().includes('room')) {
                    log('Found property: ' + prop);
                }
            }
        }
    };
    
    async function testConnection() {
        log('Starting test...');
        
        // Try different SDK namespaces
        const Room = window.livekit?.Room || 
                     window.LivekitClient?.Room || 
                     window.LiveKit?.Room ||
                     window.Room;
                     
        if (!Room) {
            log('ERROR: Cannot find Room constructor!');
            log('Available globals: ' + Object.keys(window).filter(k => k.toLowerCase().includes('live')).join(', '));
            return;
        }
        
        log('✓ Room constructor found');
        
        try {
            // Test direct WebSocket first
            log('Testing direct WebSocket to ws://167.235.67.1:7880...');
            const testWs = new WebSocket('ws://167.235.67.1:7880');
            testWs.onopen = () => {
                log('✓ Direct WebSocket connected!');
                testWs.close();
            };
            testWs.onerror = (e) => {
                log('✗ Direct WebSocket failed');
            };
            
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
                const error = await response.text();
                log('ERROR: ' + error);
                return;
            }
            
            const data = await response.json();
            log('Token received');
            log('URL: ' + data.url);
            
            // Try to create room
            log('Creating room...');
            const room = new Room();
            
            room.on('connected', () => log('✓ CONNECTED!'));
            room.on('disconnected', () => log('Disconnected'));
            room.on('connectionStateChanged', (state) => log('State: ' + state));
            room.on('error', (e) => log('ERROR: ' + e.message));
            
            log('Connecting to: ' + data.url);
            await room.connect(data.url, data.token);
            
        } catch (error) {
            log('ERROR: ' + error.message);
            log('Stack: ' + error.stack);
        }
    }
    </script>
</body>
</html>
EOF

# 4. Copy files to container
echo ""
echo "4. Copying files to container:"
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)
docker cp test-livekit-fixed.html $APP_CONTAINER:/app/public/
docker cp livekit-client.umd.js $APP_CONTAINER:/app/public/

# 5. Update production.html to use local SDK as fallback
echo ""
echo "5. Updating production.html with local SDK fallback:"
cat > fix-production-sdk.js << 'EOF'
// Add this to production.html before other scripts
(function() {
    // Function to load LiveKit SDK with fallbacks
    function loadLiveKitSDK() {
        // First try: CDN
        const script1 = document.createElement('script');
        script1.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
        script1.onerror = function() {
            console.log('CDN failed, trying local copy...');
            // Fallback: Local copy
            const script2 = document.createElement('script');
            script2.src = 'livekit-client.umd.js';
            script2.onload = function() {
                console.log('LiveKit SDK loaded from local copy');
            };
            document.head.appendChild(script2);
        };
        script1.onload = function() {
            console.log('LiveKit SDK loaded from CDN');
        };
        document.head.appendChild(script1);
    }
    
    // Load on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', loadLiveKitSDK);
    } else {
        loadLiveKitSDK();
    }
})();
EOF

docker cp fix-production-sdk.js $APP_CONTAINER:/app/public/

echo ""
echo "=== Fix Applied ==="
echo ""
echo "Try these URLs:"
echo "1. https://elosofia.site/test-livekit-fixed.html"
echo "2. https://elosofia.site/production.html"
echo ""
echo "The SDK should now load either from CDN or local fallback"