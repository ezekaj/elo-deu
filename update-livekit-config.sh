#!/bin/bash
# Update the client-side configuration to connect directly to LiveKit

echo "Updating client configuration for direct LiveKit connection..."

# Update config.js to use direct LiveKit connection on port 7880
cat > /root/elo-deu/dental-calendar/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    // API configuration
    API_BASE_URL: window.location.origin,
    WS_URL: window.location.origin.replace('https:', 'wss:').replace('http:', 'ws:'),
    
    // LiveKit configuration - Direct connection
    LIVEKIT_URL: window.location.protocol === 'https:' 
        ? 'wss://' + window.location.hostname + ':7881'  // Use TCP port 7881 for WSS
        : 'ws://' + window.location.hostname + ':7880',  // Use port 7880 for WS
    
    // For development/testing - Use proxy through Nginx
    // LIVEKIT_URL: window.location.origin.replace('https:', 'wss:').replace('http:', 'ws:') + '/ws',
    
    // API credentials
    LIVEKIT_API_KEY: 'devkey',
    LIVEKIT_API_SECRET: 'devsecret',
    
    // Environment
    ENVIRONMENT: window.location.hostname === 'localhost' ? 'development' : 'production',
    
    // Features
    FEATURES: {
        VOICE_ENABLED: true,
        DEMO_MODE: false
    }
};

// Log configuration for debugging
console.log('Sofia Configuration:', {
    origin: window.location.origin,
    livekitUrl: window.SOFIA_CONFIG.LIVEKIT_URL,
    environment: window.SOFIA_CONFIG.ENVIRONMENT
});
EOF

# Rebuild and restart the app container
cd /root/elo-deu
docker-compose -f docker-compose.final.yml build app
docker-compose -f docker-compose.final.yml up -d app

echo "Configuration updated!"
echo ""
echo "Try these connection methods:"
echo "1. Through Nginx proxy: wss://elosofia.site/ws"
echo "2. Direct WebSocket: wss://elosofia.site:7881"
echo "3. Direct insecure: ws://167.235.67.1:7880"
echo ""
echo "Clear your browser cache and try again!"