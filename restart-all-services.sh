#!/bin/bash

echo "🔧 Restarting All Services for elosofia.site"
echo "==========================================="
echo ""

# Kill existing processes
echo "Stopping existing services..."
pkill -f cloudflared
pkill -f "node.*server.js"
sleep 3

# Start calendar server
echo "Starting calendar server..."
cd /home/elo/elo-deu/dental-calendar
npm start > ../calendar-server.log 2>&1 &
echo "Calendar server PID: $!"
sleep 3

# Test local connection
echo "Testing local server..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3005/api/appointments | grep -q "200"; then
    echo "✅ Calendar server is running"
else
    echo "❌ Calendar server failed to start"
    exit 1
fi

# Start tunnels
echo ""
echo "Starting Cloudflare tunnels..."
cloudflared tunnel --url http://localhost:3005 > ../calendar-tunnel.log 2>&1 &
CALENDAR_PID=$!
echo "Calendar tunnel PID: $CALENDAR_PID"

cloudflared tunnel --url http://localhost:7880 > ../voice-tunnel.log 2>&1 &
VOICE_PID=$!
echo "Voice tunnel PID: $VOICE_PID"

# Wait for tunnels to establish
echo ""
echo "Waiting for tunnels to establish..."
sleep 10

# Extract URLs
CALENDAR_URL=$(grep -o "https://[^ ]*" ../calendar-tunnel.log | tail -1)
VOICE_URL=$(grep -o "https://[^ ]*" ../voice-tunnel.log | tail -1)

echo ""
echo "📡 Tunnel URLs:"
echo "Calendar: $CALENDAR_URL"
echo "Voice: $VOICE_URL"

# Create updated config
cat > /home/elo/elo-deu/docs/config.js << EOF
/**
 * Dynamic Configuration for Sofia Dental Calendar
 * Auto-generated at $(date)
 */

window.SOFIA_CONFIG = {
    // API Endpoints - using Cloudflare tunnels
    API_BASE_URL: window.location.hostname === 'localhost' 
        ? 'http://localhost:3005' 
        : '$CALENDAR_URL',
    
    CRM_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:5000'
        : '$CALENDAR_URL',
    
    LIVEKIT_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:7880'
        : '${VOICE_URL/https:/wss:}',  // Direct LiveKit tunnel
    
    LIVEKIT_API_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:7880'
        : '$VOICE_URL',
    
    // WebSocket for real-time updates
    WS_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:3005'
        : '${CALENDAR_URL/https:/wss:}',
    
    // Environment
    ENVIRONMENT: window.location.hostname === 'localhost' ? 'development' : 'production',
    
    // Features
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};

// Log configuration for debugging
console.log('Sofia Configuration:', {
    environment: window.SOFIA_CONFIG.ENVIRONMENT,
    apiBase: window.SOFIA_CONFIG.API_BASE_URL,
    livekit: window.SOFIA_CONFIG.LIVEKIT_URL
});
EOF

# Copy to server public directory
cp /home/elo/elo-deu/docs/config.js /home/elo/elo-deu/dental-calendar/public/config.js

echo ""
echo "📝 Configuration updated!"
echo ""
echo "🚀 To deploy to GitHub:"
echo "git add docs/config.js"
echo "git commit -m 'Update tunnel URLs'"
echo "git push origin master"
echo ""
echo "✅ All services started!"
echo "Keep this terminal open to maintain the tunnels."