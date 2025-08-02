#!/bin/bash
# Quick fix for LiveKit connection

echo "=== Quick LiveKit Fix ==="

# 1. Find actual container names
echo "Current containers:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo ""

# 2. Get the actual app container name
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental-calendar" | head -1)
LIVEKIT_CONTAINER=$(docker ps --format "{{.Names}}" | grep "livekit" | head -1)

echo "App container: $APP_CONTAINER"
echo "LiveKit container: $LIVEKIT_CONTAINER"
echo ""

# 3. Simple test - is LiveKit responding?
echo "Testing LiveKit directly on port 7880:"
nc -zv localhost 7880 || echo "Port 7880 not accessible"
echo ""

# 4. Update config to use direct IP connection (temporary fix)
echo "Updating config for direct connection..."
cat > /root/elo-deu/dental-calendar/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.origin,
    WS_URL: window.location.origin.replace('https:', 'wss:').replace('http:', 'ws:'),
    
    // Try direct IP connection for LiveKit
    LIVEKIT_URL: 'ws://167.235.67.1:7880',
    
    LIVEKIT_API_KEY: 'devkey',
    LIVEKIT_API_SECRET: 'devsecret',
    
    ENVIRONMENT: 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        DEMO_MODE: false
    }
};

console.log('Sofia Config - Direct LiveKit connection:', window.SOFIA_CONFIG.LIVEKIT_URL);
EOF

# 5. Restart the app container to pick up new config
if [ ! -z "$APP_CONTAINER" ]; then
    echo "Restarting app container..."
    docker restart $APP_CONTAINER
fi

# 6. Make sure firewall allows LiveKit
ufw allow 7880/tcp
ufw allow 7881/tcp

echo ""
echo "=== Fix applied ==="
echo "LiveKit should now be accessible at:"
echo "- ws://167.235.67.1:7880 (direct connection)"
echo ""
echo "Clear browser cache and try again!"