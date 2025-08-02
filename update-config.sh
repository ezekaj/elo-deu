#!/bin/bash
# Run this on your VPS to update the configuration

cat > /root/elo-deu/dental-calendar/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    // Use the actual domain now
    API_BASE_URL: window.location.protocol + '//' + window.location.host,
    
    LIVEKIT_URL: 'wss://' + window.location.host + '/ws',
    
    LIVEKIT_API_KEY: 'devkey',
    LIVEKIT_API_SECRET: 'secret',
    
    // Environment
    ENVIRONMENT: 'production',
    
    // Features
    FEATURES: {
        VOICE_ENABLED: true,
        DEMO_MODE: false
    }
};

console.log('Sofia Configuration:', window.SOFIA_CONFIG);
EOF

# Also create a simple API endpoint
cat > /root/elo-deu/dental-calendar/public/api-mock.js << 'EOF'
// Simple mock API responses
window.mockAPI = {
    appointments: []
};
EOF

echo "Configuration updated!"
echo "The site will now use elosofia.site instead of ngrok URLs"