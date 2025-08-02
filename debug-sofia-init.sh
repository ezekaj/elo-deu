#!/bin/bash
# Debug Sofia initialization issue

echo "=== Debugging Sofia Initialization ==="

# 1. Check what's actually running
echo "1. Container status:"
docker ps | grep -E "livekit|dental"
echo ""

# 2. Test if LiveKit is accessible
echo "2. Testing LiveKit accessibility:"
curl -v http://localhost:7880 2>&1 | grep -E "Connected|refused|Failed"
echo ""

# 3. Check LiveKit container logs
echo "3. LiveKit logs (checking for errors):"
docker logs $(docker ps --format "{{.Names}}" | grep livekit) --tail 30 2>&1 | grep -E "error|Error|ERROR|failed|Failed|FAILED|panic" || echo "No errors found"
echo ""

# 4. Test from inside the app container
echo "4. Testing from app container:"
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)
docker exec $APP_CONTAINER sh -c "
echo 'Can reach LiveKit?'
wget -O- http://livekit:7880 2>&1 | head -5 || echo 'Cannot reach LiveKit'
"
echo ""

# 5. Check if Sofia endpoint exists
echo "5. Testing Sofia endpoint:"
curl -s https://elosofia.site/api/sofia/test || echo "Sofia test endpoint not found"
echo ""

# 6. Create a detailed debug page
echo "6. Creating detailed debug page..."
cat > dental-calendar/public/sofia-debug-detailed.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Sofia Debug - Detailed</title>
    <script src="https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js"></script>
</head>
<body>
    <h1>Sofia Debug - Step by Step</h1>
    <button onclick="debugStepByStep()">Start Debug</button>
    <div id="log" style="font-family: monospace; white-space: pre;"></div>
    
    <script>
    function log(msg, isError = false) {
        const el = document.getElementById('log');
        const time = new Date().toLocaleTimeString();
        el.innerHTML += `[${time}] ${isError ? '❌' : '✓'} ${msg}\n`;
        console.log(msg);
    }
    
    async function debugStepByStep() {
        log('=== Starting Sofia Debug ===');
        
        // Step 1: Check LiveKit SDK
        log('\nStep 1: Checking LiveKit SDK...');
        const sdkLoaded = typeof LivekitClient !== 'undefined' || typeof livekit !== 'undefined';
        log(`LiveKit SDK loaded: ${sdkLoaded}`, !sdkLoaded);
        
        if (!sdkLoaded) {
            log('FATAL: LiveKit SDK not found!', true);
            return;
        }
        
        // Step 2: Test API endpoint
        log('\nStep 2: Testing Sofia API endpoint...');
        try {
            const testResponse = await fetch('/api/sofia/test');
            log(`API test response: ${testResponse.status}`);
            if (testResponse.ok) {
                const testData = await testResponse.json();
                log(`API test data: ${JSON.stringify(testData, null, 2)}`);
            }
        } catch (e) {
            log(`API test failed: ${e.message}`, true);
        }
        
        // Step 3: Request connection token
        log('\nStep 3: Requesting connection token...');
        try {
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'Debug-User-' + Date.now()
                })
            });
            
            log(`Token response: ${response.status}`);
            
            if (!response.ok) {
                const error = await response.text();
                log(`Token error: ${error}`, true);
                return;
            }
            
            const data = await response.json();
            log(`Token data: ${JSON.stringify(data, null, 2)}`);
            
            // Step 4: Try WebSocket connection
            log('\nStep 4: Testing WebSocket connection...');
            const wsUrl = window.location.protocol === 'https:' ? 'wss://elosofia.site/ws' : data.url;
            log(`WebSocket URL: ${wsUrl}`);
            
            const ws = new WebSocket(wsUrl);
            
            await new Promise((resolve) => {
                ws.onopen = () => {
                    log('WebSocket opened successfully!');
                    ws.close();
                    resolve();
                };
                ws.onerror = (e) => {
                    log('WebSocket error occurred', true);
                    resolve();
                };
                ws.onclose = (e) => {
                    log(`WebSocket closed: ${e.code} ${e.reason}`);
                    resolve();
                };
                
                setTimeout(() => {
                    log('WebSocket timeout', true);
                    resolve();
                }, 5000);
            });
            
            // Step 5: Try LiveKit connection
            log('\nStep 5: Attempting LiveKit connection...');
            const Room = window.LivekitClient?.Room || window.livekit?.Room;
            
            if (!Room) {
                log('Room constructor not found!', true);
                return;
            }
            
            const room = new Room({
                adaptiveStream: true,
                dynacast: true,
                logLevel: 'debug'
            });
            
            room.on('connectionStateChanged', (state) => {
                log(`Connection state: ${state}`);
            });
            
            room.on('connected', () => {
                log('🎉 CONNECTED TO LIVEKIT!');
            });
            
            room.on('error', (error) => {
                log(`Room error: ${error.message}`, true);
            });
            
            try {
                await room.connect(wsUrl, data.token);
                log('Connection attempt completed');
            } catch (e) {
                log(`Connection failed: ${e.message}`, true);
            }
            
        } catch (error) {
            log(`Fatal error: ${error.message}`, true);
            log(`Stack: ${error.stack}`, true);
        }
    }
    </script>
</body>
</html>
EOF

# Deploy debug page
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)
docker cp dental-calendar/public/sofia-debug-detailed.html $APP_CONTAINER:/app/public/

echo "✓ Created sofia-debug-detailed.html"

# 7. Quick fix attempt - restart with explicit config
echo ""
echo "7. Attempting quick fix..."
cat > quick-fix-sofia.sh << 'EOF'
#!/bin/bash
# Quick fix for Sofia

# Ensure LiveKit is running with correct config
docker-compose -f docker-compose.production.yml up -d livekit

# Wait for LiveKit
sleep 5

# Restart app
docker-compose -f docker-compose.production.yml up -d app

echo "Services restarted. Checking status..."
docker ps | grep -E "livekit|dental"
EOF

chmod +x quick-fix-sofia.sh

echo ""
echo "=== Debug Complete ==="
echo ""
echo "1. Check the output above for any obvious errors"
echo "2. Visit: https://elosofia.site/sofia-debug-detailed.html"
echo "3. Click 'Start Debug' to see step-by-step what's failing"
echo ""
echo "For quick fix, run: ./quick-fix-sofia.sh"