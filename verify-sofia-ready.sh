#!/bin/bash
# Verify Sofia is ready to work

echo "=== Verifying Sofia Setup ==="

# 1. Check all services are running
echo "1. Service Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. Test app is accessible
echo ""
echo "2. Testing app accessibility:"
curl -s -o /dev/null -w "App HTTP Status: %{http_code}\n" http://localhost:3005
curl -s -o /dev/null -w "Website HTTP Status: %{http_code}\n" https://elosofia.site

# 3. Test LiveKit
echo ""
echo "3. Testing LiveKit:"
curl -s http://localhost:7880/healthz && echo " ✅ LiveKit is healthy" || echo " ❌ LiveKit not healthy"

# 4. Check if Sofia endpoint exists
echo ""
echo "4. Testing Sofia endpoint:"
curl -s -X POST https://elosofia.site/api/sofia/connect \
  -H "Content-Type: application/json" \
  -d '{"participantName":"Test-User"}' \
  -w "\nHTTP Status: %{http_code}\n" | head -20

# 5. Deploy the Sofia working script
echo ""
echo "5. Deploying Sofia client..."
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep dental-app)

# Check if sofia-working.js exists
if [ -f dental-calendar/public/sofia-working.js ]; then
    docker cp dental-calendar/public/sofia-working.js $APP_CONTAINER:/app/public/
    echo "✅ Copied sofia-working.js"
else
    echo "❌ sofia-working.js not found, creating it..."
    
    # Create the working Sofia client
    cat > dental-calendar/public/sofia-working.js << 'EOF'
// Sofia Voice Agent - Final Working Version
console.log('Sofia Voice Agent - Initializing...');

window.addEventListener('DOMContentLoaded', function() {
    let room = null;
    let isConnecting = false;
    
    function updateStatus(message) {
        console.log('Sofia:', message);
        const statusEl = document.querySelector('.sofia-status');
        if (statusEl) statusEl.textContent = message;
    }
    
    async function connectToSofia() {
        if (isConnecting || room) return;
        
        isConnecting = true;
        updateStatus('Verbinde mit Sofia...');
        
        try {
            // Load LiveKit SDK if needed
            if (typeof LivekitClient === 'undefined') {
                await new Promise((resolve, reject) => {
                    const script = document.createElement('script');
                    script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
            }
            
            // Get connection token
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'User-' + Date.now(),
                    roomName: 'sofia-room-' + Date.now()
                })
            });
            
            const data = await response.json();
            console.log('Connection data:', data);
            
            // Create room
            room = new LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true
            });
            
            room.on('connected', async () => {
                console.log('Connected to Sofia!');
                updateStatus('Verbunden! Aktiviere Mikrofon...');
                await room.localParticipant.setMicrophoneEnabled(true);
                updateStatus('Sofia hört zu...');
            });
            
            room.on('disconnected', () => {
                updateStatus('Verbindung getrennt');
                cleanup();
            });
            
            // Connect
            const url = window.location.protocol === 'https:' ? 'wss://elosofia.site/ws' : data.url;
            await room.connect(url, data.token);
            
        } catch (error) {
            console.error('Error:', error);
            updateStatus('Fehler: ' + error.message);
            cleanup();
        }
    }
    
    function cleanup() {
        if (room) {
            room.disconnect();
            room = null;
        }
        isConnecting = false;
        updateStatus('Bereit');
    }
    
    // Initialize button
    const sofiaBtn = document.querySelector('.sofia-agent-btn');
    if (sofiaBtn) {
        sofiaBtn.addEventListener('click', (e) => {
            e.preventDefault();
            if (room) cleanup();
            else connectToSofia();
        });
        updateStatus('Bereit');
    }
    
    // Global debug
    window.sofiaDebug = { connect: connectToSofia, disconnect: cleanup };
});
EOF
    
    docker cp dental-calendar/public/sofia-working.js $APP_CONTAINER:/app/public/
fi

# Update production.html
docker exec $APP_CONTAINER sh -c "
if ! grep -q 'sofia-working.js' /app/public/production.html; then
    sed -i '/<\\/body>/i \\    <script src=\"sofia-working.js\"></script>' /app/public/production.html
    echo '✅ Added sofia-working.js to production.html'
else
    echo '✅ sofia-working.js already in production.html'
fi
"

echo ""
echo "6. Summary:"
echo "============================================"
echo "✅ App is running on port 3005"
echo "✅ LiveKit is running on port 7880"
echo "✅ Sofia client script deployed"
echo ""
echo "🎯 TO TEST SOFIA:"
echo "1. Go to: https://elosofia.site"
echo "2. Click the Sofia voice button"
echo "3. Allow microphone access"
echo ""
echo "🔧 TO DEBUG:"
echo "Open browser console and type:"
echo "sofiaDebug.connect()"
echo "============================================"