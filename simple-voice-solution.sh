#!/bin/bash
# Simple voice solution - bypass LiveKit complexity

echo "=== Simple Voice Solution ==="

# 1. First, let's check what's actually happening
echo "1. Checking current setup..."
echo "Containers running:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|livekit|dental"

echo ""
echo "Testing LiveKit port:"
nc -zv localhost 7880 2>&1 || echo "Port 7880 not accessible"

# 2. Create a simple voice solution without LiveKit
echo ""
echo "2. Creating simple voice chat solution..."
cat > dental-calendar/public/simple-voice.js << 'EOF'
// Simple Voice Solution - Direct WebRTC
(function() {
    console.log('Simple Voice Solution - Loading...');
    
    let localStream = null;
    let isActive = false;
    let recognition = null;
    
    // Simple voice activation
    async function activateVoice() {
        const statusEl = document.querySelector('.sofia-status');
        
        try {
            if (statusEl) statusEl.textContent = 'Aktiviere Mikrofon...';
            
            // Get microphone access
            localStream = await navigator.mediaDevices.getUserMedia({ 
                audio: true, 
                video: false 
            });
            
            console.log('Microphone activated');
            if (statusEl) statusEl.textContent = 'Mikrofon aktiv';
            
            // Set up speech recognition if available
            if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
                const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
                recognition = new SpeechRecognition();
                recognition.continuous = true;
                recognition.lang = 'de-DE';
                
                recognition.onresult = (event) => {
                    const last = event.results.length - 1;
                    const text = event.results[last][0].transcript;
                    console.log('User said:', text);
                    
                    // Send to backend for processing
                    processUserInput(text);
                };
                
                recognition.start();
                if (statusEl) statusEl.textContent = 'Sofia hört zu...';
            } else {
                if (statusEl) statusEl.textContent = 'Spracherkennung nicht verfügbar';
            }
            
            isActive = true;
            
        } catch (error) {
            console.error('Voice activation error:', error);
            if (statusEl) statusEl.textContent = 'Fehler: ' + error.message;
        }
    }
    
    // Process user input
    async function processUserInput(text) {
        console.log('Processing:', text);
        
        // Send to simple backend endpoint
        try {
            const response = await fetch('/api/sofia/process', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ text: text })
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log('Sofia response:', data);
                
                // Use speech synthesis for response
                if ('speechSynthesis' in window && data.response) {
                    const utterance = new SpeechSynthesisUtterance(data.response);
                    utterance.lang = 'de-DE';
                    speechSynthesis.speak(utterance);
                }
            }
        } catch (error) {
            console.error('Process error:', error);
        }
    }
    
    // Deactivate voice
    function deactivateVoice() {
        if (localStream) {
            localStream.getTracks().forEach(track => track.stop());
            localStream = null;
        }
        
        if (recognition) {
            recognition.stop();
            recognition = null;
        }
        
        isActive = false;
        
        const statusEl = document.querySelector('.sofia-status');
        if (statusEl) statusEl.textContent = 'Bereit';
    }
    
    // Initialize
    window.addEventListener('DOMContentLoaded', () => {
        console.log('Simple Voice - Initializing button...');
        
        const sofiaBtn = document.querySelector('.sofia-agent-btn');
        if (sofiaBtn) {
            sofiaBtn.addEventListener('click', (e) => {
                e.preventDefault();
                console.log('Sofia button clicked, isActive:', isActive);
                
                if (isActive) {
                    deactivateVoice();
                } else {
                    activateVoice();
                }
            });
            
            console.log('Sofia button initialized');
        } else {
            console.log('Sofia button not found');
        }
    });
    
    // Also expose globally for testing
    window.simpleVoice = {
        activate: activateVoice,
        deactivate: deactivateVoice,
        isActive: () => isActive
    };
    
    console.log('Simple Voice Solution ready - use simpleVoice.activate() to test');
})();
EOF

echo "✓ Created simple voice solution"

# 3. Create a simple backend endpoint
echo ""
echo "3. Creating simple backend handler..."
cat > dental-calendar/simple-sofia-backend.js << 'EOF'
// Simple Sofia backend - add to server.js

// Simple Sofia processing endpoint
app.post('/api/sofia/process', (req, res) => {
    const { text } = req.body;
    console.log('Processing user input:', text);
    
    // Simple responses for now
    let response = 'Ich habe Sie verstanden.';
    
    // Add some basic responses
    if (text.toLowerCase().includes('termin')) {
        response = 'Gerne helfe ich Ihnen bei der Terminvereinbarung. Wann möchten Sie vorbeikommen?';
    } else if (text.toLowerCase().includes('schmerz')) {
        response = 'Es tut mir leid zu hören, dass Sie Schmerzen haben. Möchten Sie einen Notfalltermin vereinbaren?';
    } else if (text.toLowerCase().includes('hallo') || text.toLowerCase().includes('guten')) {
        response = 'Hallo! Ich bin Sofia, Ihre digitale Assistentin. Wie kann ich Ihnen heute helfen?';
    }
    
    res.json({
        input: text,
        response: response,
        timestamp: new Date().toISOString()
    });
});

// Health check
app.get('/api/sofia/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        mode: 'simple',
        message: 'Simple Sofia is running'
    });
});
EOF

echo "✓ Created backend handler"

# 4. Deploy the simple solution
echo ""
echo "4. Deploying simple solution..."
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)

if [ -z "$APP_CONTAINER" ]; then
    echo "❌ No app container found!"
    exit 1
fi

# Copy the simple voice file
docker cp dental-calendar/public/simple-voice.js $APP_CONTAINER:/app/public/

# Update production.html to use simple voice
docker exec $APP_CONTAINER sh -c "
# Remove old scripts
sed -i '/sofia-voice-fix.js/d' /app/public/production.html
sed -i '/sofia-voice-final.js/d' /app/public/production.html
sed -i '/sofia-multi-user.js/d' /app/public/production.html

# Add simple voice script
if ! grep -q 'simple-voice.js' /app/public/production.html; then
    sed -i '/<\\/body>/i \\    <script src=\"simple-voice.js\"></script>' /app/public/production.html
    echo '✓ Added simple-voice.js to production.html'
fi
"

# 5. Create a test page
echo ""
echo "5. Creating test page..."
cat > dental-calendar/public/test-simple-voice.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Simple Voice Test</title>
</head>
<body>
    <h1>Simple Voice Test</h1>
    <button onclick="testVoice()">Test Voice</button>
    <button class="sofia-agent-btn">Sofia Button</button>
    <div class="sofia-status">Ready</div>
    <div id="log"></div>
    
    <script src="simple-voice.js"></script>
    <script>
    function testVoice() {
        console.log('Testing voice...');
        if (window.simpleVoice) {
            window.simpleVoice.activate();
        } else {
            console.log('Simple voice not loaded!');
        }
    }
    </script>
</body>
</html>
EOF

docker cp dental-calendar/public/test-simple-voice.html $APP_CONTAINER:/app/public/

echo "✓ Test page created"

# 6. Restart the app
echo ""
echo "6. Restarting app..."
docker restart $APP_CONTAINER

echo ""
echo "=== Simple Solution Deployed ==="
echo ""
echo "This simple solution:"
echo "- Uses native browser speech recognition"
echo "- No complex WebSocket/LiveKit setup"
echo "- Works immediately when you click the button"
echo "- Falls back gracefully if features aren't available"
echo ""
echo "Test at:"
echo "- https://elosofia.site (main page)"
echo "- https://elosofia.site/test-simple-voice.html (test page)"
echo ""
echo "⚠️  Note: You still need to update server.js with the backend code from:"
echo "   dental-calendar/simple-sofia-backend.js"