#!/bin/bash
# Verify sofia-final.js is properly deployed

echo "=== Verifying Sofia Final Setup ==="

# 1. Check if sofia-final.js exists
echo "1. Checking if sofia-final.js exists in container..."
docker exec dental-app ls -la /app/public/sofia-final.js || echo "sofia-final.js NOT FOUND!"

# 2. Check what's in production.html
echo ""
echo "2. Scripts in production.html:"
docker exec dental-app grep '<script' /app/public/production.html | tail -10

# 3. If sofia-final.js doesn't exist, create it
echo ""
echo "3. Creating/updating sofia-final.js..."
cat > /tmp/sofia-final.js << 'EOF'
// Sofia Voice - Clean Implementation
console.log('[Sofia] Script loaded');

(function() {
    let room = null;
    let isActive = false;
    
    function log(msg) {
        console.log('[Sofia]', msg);
    }
    
    function updateStatus(msg) {
        log(msg);
        const el = document.querySelector('.sofia-status');
        if (el) el.textContent = msg;
    }
    
    async function startSofia() {
        log('Starting Sofia...');
        
        if (isActive || room) {
            log('Already active');
            return;
        }
        
        try {
            isActive = true;
            updateStatus('Initialisiere...');
            
            // Load LiveKit SDK
            if (!window.LivekitClient) {
                log('Loading LiveKit SDK...');
                const script = document.createElement('script');
                script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
                await new Promise((resolve, reject) => {
                    script.onload = resolve;
                    script.onerror = reject;
                    document.head.appendChild(script);
                });
                log('SDK loaded');
            }
            
            // Get token
            updateStatus('Verbinde...');
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'User-' + Date.now()
                })
            });
            
            const data = await response.json();
            log('Got token:', data);
            
            // Create room
            room = new LivekitClient.Room();
            
            room.on('connected', async () => {
                log('Connected!');
                updateStatus('Mikrofon aktivieren...');
                await room.localParticipant.setMicrophoneEnabled(true);
                updateStatus('Sofia hört zu...');
            });
            
            room.on('disconnected', () => {
                log('Disconnected');
                cleanup();
            });
            
            // Connect
            const url = window.location.protocol === 'https:' ? 'wss://elosofia.site/ws' : data.url;
            log('Connecting to:', url);
            await room.connect(url, data.token);
            
        } catch (error) {
            log('Error:', error);
            updateStatus('Fehler: ' + error.message);
            cleanup();
        }
    }
    
    function cleanup() {
        if (room) {
            room.disconnect();
            room = null;
        }
        isActive = false;
        updateStatus('Bereit');
    }
    
    // Initialize button
    function init() {
        log('Initializing button...');
        const btn = document.querySelector('.sofia-agent-btn');
        if (!btn) {
            log('Button not found, retrying...');
            setTimeout(init, 500);
            return;
        }
        
        log('Button found!');
        btn.onclick = function(e) {
            e.preventDefault();
            log('Button clicked!');
            if (isActive) cleanup();
            else startSofia();
        };
        
        updateStatus('Bereit');
    }
    
    // Start when ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
    // Debug access
    window.Sofia = { start: startSofia, stop: cleanup };
})();
EOF

# Copy to container
docker cp /tmp/sofia-final.js dental-app:/app/public/

# 4. Ensure it's in production.html
echo ""
echo "4. Ensuring sofia-final.js is loaded..."
docker exec dental-app sh -c "
if ! grep -q 'sofia-final.js' /app/public/production.html; then
    sed -i '/<\\/body>/i \\    <script src=\"sofia-final.js\"></script>' /app/public/production.html
    echo 'Added sofia-final.js to production.html'
fi
"

# 5. Test the endpoint
echo ""
echo "5. Testing Sofia endpoint..."
curl -s -X POST http://localhost:3005/api/sofia/connect \
  -H "Content-Type: application/json" \
  -d '{"participantName":"Test"}' | head -20

echo ""
echo "=== Verification Complete ==="
echo ""
echo "Now:"
echo "1. Refresh the page (F5)"
echo "2. Open console (F12)"
echo "3. You should see: [Sofia] Script loaded"
echo "4. Click the Sofia button"
echo "5. Or type: Sofia.start()"