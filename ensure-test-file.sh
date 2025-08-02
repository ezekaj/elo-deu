#!/bin/bash
# Ensure test file is accessible

echo "=== Setting up LiveKit test file ==="

# 1. Check where files should go
echo "1. Finding public directory in container:"
docker exec $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1) \
    ls -la /app/public/ | head -10

# 2. Copy test file into container
echo ""
echo "2. Copying test file into container:"
docker cp /root/elo-deu/dental-calendar/public/test-livekit.html \
    $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1):/app/public/

# 3. Also copy debug script
docker cp /root/elo-deu/dental-calendar/public/sofia-voice-debug.js \
    $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1):/app/public/ 2>/dev/null || true

# 4. List files to confirm
echo ""
echo "3. Files in container public directory:"
docker exec $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1) \
    ls -la /app/public/ | grep -E "test-livekit|sofia-voice-debug"

# 5. Let's also test LiveKit directly with a simple Node.js script
echo ""
echo "4. Creating direct LiveKit test..."
cat > /tmp/test-livekit-direct.js << 'EOF'
// Direct LiveKit connection test
const http = require('http');

console.log('Testing LiveKit connection...');

// Test 1: Can we reach LiveKit?
const options = {
    hostname: 'livekit',
    port: 7880,
    path: '/',
    method: 'GET'
};

const req = http.request(options, (res) => {
    console.log(`LiveKit response: ${res.statusCode}`);
});

req.on('error', (e) => {
    console.error(`LiveKit connection error: ${e.message}`);
});

req.end();

// Test 2: Check WebSocket endpoint
const WebSocket = require('ws');
const ws = new WebSocket('ws://livekit:7880/rtc');

ws.on('open', () => {
    console.log('WebSocket connected!');
    ws.close();
});

ws.on('error', (err) => {
    console.log('WebSocket error:', err.message);
});
EOF

# 6. Run the direct test
echo ""
echo "5. Running direct LiveKit test from app container:"
docker cp /tmp/test-livekit-direct.js \
    $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1):/tmp/
    
docker exec $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1) \
    node /tmp/test-livekit-direct.js || echo "Test completed"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Now try: https://elosofia.site/test-livekit.html"
echo ""
echo "If still not found, restart the container:"
echo "docker restart \$(docker ps --format \"{{.Names}}\" | grep -E \"app|dental\" | head -1)"