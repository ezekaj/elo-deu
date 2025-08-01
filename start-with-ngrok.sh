#!/bin/bash

echo "🚀 Starting Sofia Dental AI with ngrok"
echo "====================================="
echo ""

# Kill existing processes
echo "Stopping existing services..."
pkill -f ngrok
pkill -f cloudflared
sleep 2

# Start ngrok for calendar API
echo "Starting ngrok tunnel for calendar API..."
ngrok http 3005 --log=stdout > ngrok-calendar.log 2>&1 &
NGROK_PID=$!
echo "Ngrok PID: $NGROK_PID"

# Wait for ngrok to start
echo "Waiting for ngrok to establish tunnel..."
sleep 5

# Get ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | grep -o 'https://[^"]*' | head -1)

if [ -z "$NGROK_URL" ]; then
    echo "❌ Failed to get ngrok URL"
    echo "Trying to parse from log..."
    NGROK_URL=$(grep -o 'https://.*\.ngrok-free\.app' ngrok-calendar.log | head -1)
fi

echo ""
echo "📡 Ngrok URL: $NGROK_URL"

# Update configuration
cat > /home/elo/elo-deu/docs/config.js << EOF
/**
 * Dynamic Configuration for Sofia Dental Calendar
 * Using ngrok tunnel
 */

window.SOFIA_CONFIG = {
    // API Endpoints - using ngrok tunnel
    API_BASE_URL: window.location.hostname === 'localhost' 
        ? 'http://localhost:3005' 
        : '$NGROK_URL',
    
    CRM_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:5000'
        : '$NGROK_URL',
    
    LIVEKIT_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:7880'
        : '$NGROK_URL/livekit-proxy',  // Using proxy through ngrok
    
    LIVEKIT_API_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:7880'
        : '$NGROK_URL',
    
    // WebSocket for real-time updates
    WS_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:3005'
        : '${NGROK_URL/https:/wss:}',
    
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
echo "✅ Configuration updated!"
echo ""
echo "📝 ngrok Dashboard: http://localhost:4040"
echo "🌐 Public URL: $NGROK_URL"
echo ""
echo "To deploy to GitHub:"
echo "git add docs/config.js && git commit -m 'Update with ngrok URL' && git push"