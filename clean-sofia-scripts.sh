#!/bin/bash
# Clean up all old Sofia scripts and ensure only the new one loads

echo "=== Cleaning Sofia Scripts ==="

# 1. Remove all old Sofia scripts from production.html
echo "1. Cleaning production.html..."
docker exec dental-app sh -c "
# Create backup
cp /app/public/production.html /app/public/production.html.backup

# Remove ALL sofia script references
sed -i '/sofia-voice/d' /app/public/production.html
sed -i '/sofia-multi/d' /app/public/production.html
sed -i '/sofia-working/d' /app/public/production.html
sed -i '/sofia-force/d' /app/public/production.html
sed -i '/sofia-debug/d' /app/public/production.html
sed -i '/sofia.js/d' /app/public/production.html

echo 'Removed all Sofia script references'
"

# 2. Create the ONLY Sofia script we need
echo ""
echo "2. Creating clean Sofia implementation..."
cat > dental-calendar/public/sofia-final.js << 'EOF'
// Sofia Voice - Final Clean Implementation
console.log('Sofia Final - Loading...');

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
        if (isActive || room) {
            log('Already active');
            return;
        }
        
        try {
            isActive = true;
            updateStatus('Initialisiere...');
            
            // Load LiveKit SDK if needed
            if (typeof window.LivekitClient === 'undefined') {
                log('Loading LiveKit SDK...');
                await new Promise((resolve, reject) => {
                    if (document.querySelector('script[src*="livekit-client"]')) {
                        // Already loading
                        setTimeout(resolve, 1000);
                        return;
                    }
                    const script = document.createElement('script');
                    script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
                    script.onload = () => {
                        log('SDK loaded');
                        resolve();
                    };
                    script.onerror = () => {
                        log('SDK load failed');
                        reject(new Error('SDK load failed'));
                    };
                    document.head.appendChild(script);
                });
            }
            
            updateStatus('Verbinde mit Server...');
            
            // Get connection token
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'User-' + Date.now(),
                    roomName: 'room-' + Date.now()
                })
            });
            
            if (!response.ok) {
                throw new Error(`Server error: ${response.status}`);
            }
            
            const data = await response.json();
            log('Got connection data:', data);
            
            // Create LiveKit room
            updateStatus('Erstelle Raum...');
            room = new window.LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true,
                logLevel: 'warn'
            });
            
            // Set up event handlers
            room.on('connected', async () => {
                log('Connected to room');
                updateStatus('Aktiviere Mikrofon...');
                
                try {
                    await room.localParticipant.setMicrophoneEnabled(true);
                    updateStatus('Sofia hört zu... 🎤');
                    log('Microphone enabled');
                } catch (error) {
                    log('Microphone error:', error);
                    updateStatus('Mikrofon-Fehler');
                }
            });
            
            room.on('disconnected', (reason) => {
                log('Disconnected:', reason);
                cleanup();
            });
            
            room.on('participantConnected', (participant) => {
                log('Participant connected:', participant.identity);
                if (participant.identity.includes('Sofia') || participant.identity.includes('Agent')) {
                    updateStatus('Sofia ist da! 🤖');
                }
            });
            
            // Determine connection URL
            const connectUrl = window.location.protocol === 'https:' 
                ? 'wss://elosofia.site/ws' 
                : 'ws://localhost:7880';
                
            log('Connecting to:', connectUrl);
            
            // Connect to room
            await room.connect(connectUrl, data.token);
            
        } catch (error) {
            log('Error:', error);
            updateStatus('Fehler: ' + error.message);
            cleanup();
        }
    }
    
    function stopSofia() {
        log('Stopping Sofia...');
        updateStatus('Trenne Verbindung...');
        cleanup();
    }
    
    function cleanup() {
        if (room) {
            room.disconnect();
            room = null;
        }
        isActive = false;
        updateStatus('Bereit');
    }
    
    // Initialize when DOM is ready
    function init() {
        log('Initializing...');
        
        const btn = document.querySelector('.sofia-agent-btn');
        if (!btn) {
            log('Button not found, retrying...');
            setTimeout(init, 1000);
            return;
        }
        
        log('Button found, attaching handler');
        btn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            log('Button clicked');
            
            if (isActive || room) {
                stopSofia();
            } else {
                startSofia();
            }
        });
        
        updateStatus('Bereit');
        log('Initialization complete');
    }
    
    // Start initialization
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
    // Global access for debugging
    window.SofiaVoice = {
        start: startSofia,
        stop: stopSofia,
        status: () => ({ isActive, hasRoom: !!room })
    };
    
})();

log('Sofia Final - Ready');
EOF

# 3. Copy the new script
echo ""
echo "3. Deploying new Sofia script..."
docker cp dental-calendar/public/sofia-final.js dental-app:/app/public/

# 4. Add ONLY the new script to production.html
echo ""
echo "4. Adding sofia-final.js to production.html..."
docker exec dental-app sh -c "
# Add the new script before </body>
sed -i '/<\\/body>/i \\    <script src=\"sofia-final.js\"></script>' /app/public/production.html
echo 'Added sofia-final.js'

# Show what scripts are loaded
echo ''
echo 'Scripts in production.html:'
grep '<script' /app/public/production.html | grep -E 'sofia|livekit'
"

# 5. Clear browser cache reminder
echo ""
echo "5. IMPORTANT: Clear your browser cache!"
echo "   - Press Ctrl+Shift+R or Cmd+Shift+R"
echo "   - Or open Developer Tools > Network > Disable cache"

# 6. Test the endpoint
echo ""
echo "6. Testing Sofia endpoint..."
curl -s -X POST http://localhost:3005/api/sofia/connect \
  -H "Content-Type: application/json" \
  -d '{"participantName":"Test"}' | jq . || echo "Endpoint test failed"

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Now:"
echo "1. Clear your browser cache (Ctrl+Shift+R)"
echo "2. Go to https://elosofia.site"
echo "3. Open browser console (F12)"
echo "4. Click the Sofia button"
echo ""
echo "In console, you can also test with:"
echo "SofiaVoice.start()"
echo ""
echo "The console will show [Sofia] messages for debugging"