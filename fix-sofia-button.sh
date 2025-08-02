#!/bin/bash
# Fix Sofia button selector

echo "=== Fixing Sofia Button Selector ==="

# 1. Update sofia-final.js with better button finding logic
echo "1. Creating updated Sofia script..."
cat > /tmp/sofia-final-fixed.js << 'EOF'
// Sofia Voice - Fixed Button Detection
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
    
    // Initialize button with multiple selectors
    function init() {
        log('Looking for Sofia button...');
        
        // Try multiple selectors
        const selectors = [
            '.sofia-agent-btn',
            '.sofia-agent-button',
            '[data-sofia-button]',
            'button[class*="sofia"]',
            'a[class*="sofia"]',
            '#sofia-button',
            '.btn-sofia'
        ];
        
        let btn = null;
        for (const selector of selectors) {
            btn = document.querySelector(selector);
            if (btn) {
                log(`Found button with selector: ${selector}`);
                break;
            }
        }
        
        // Also check for any element with Sofia in text
        if (!btn) {
            const allButtons = document.querySelectorAll('button, a.btn');
            for (const b of allButtons) {
                if (b.textContent.toLowerCase().includes('sofia') || 
                    b.innerHTML.toLowerCase().includes('sofia')) {
                    btn = b;
                    log('Found button by text content');
                    break;
                }
            }
        }
        
        if (!btn) {
            log('Button not found. Available buttons:');
            document.querySelectorAll('button, a.btn').forEach(b => {
                log(`- ${b.className}: ${b.textContent.trim()}`);
            });
            log('Retrying in 2 seconds...');
            setTimeout(init, 2000);
            return;
        }
        
        log('Attaching click handler to button');
        btn.onclick = function(e) {
            e.preventDefault();
            log('Button clicked!');
            if (isActive) cleanup();
            else startSofia();
        };
        
        // Also add visual indicator
        btn.style.position = 'relative';
        const indicator = document.createElement('span');
        indicator.className = 'sofia-status';
        indicator.style.position = 'absolute';
        indicator.style.top = '0';
        indicator.style.right = '0';
        indicator.style.fontSize = '10px';
        indicator.style.background = '#28a745';
        indicator.style.color = 'white';
        indicator.style.padding = '2px 5px';
        indicator.style.borderRadius = '3px';
        indicator.textContent = 'Bereit';
        btn.appendChild(indicator);
        
        log('Sofia ready!');
    }
    
    // Start initialization
    setTimeout(init, 1000); // Give page time to render
    
    // Debug access
    window.Sofia = { 
        start: startSofia, 
        stop: cleanup,
        findButton: init
    };
})();
EOF

# 2. Deploy the fixed script
echo ""
echo "2. Deploying fixed Sofia script..."
docker cp /tmp/sofia-final-fixed.js dental-app:/app/public/sofia-final.js

# 3. Force reload by adding timestamp
echo ""
echo "3. Updating calendar.js to force reload..."
TIMESTAMP=$(date +%s)
docker exec dental-app sh -c "
# Update the loader in calendar.js
sed -i \"s|script.src = '/sofia-final.js';|script.src = '/sofia-final.js?t=$TIMESTAMP';|\" /app/public/calendar.js
"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Now:"
echo "1. Refresh the page"
echo "2. Check console for button detection"
echo "3. Sofia will show all available buttons if it can't find the right one"
echo ""
echo "You can also manually trigger with:"
echo "Sofia.findButton() - to retry finding button"
echo "Sofia.start() - to start directly"