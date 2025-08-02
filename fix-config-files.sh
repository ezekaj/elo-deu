#!/bin/bash
# Fix all config.js files to use elosofia.site instead of ngrok

echo "Fixing configuration files..."

# Update all config.js files in the project
find . -name "config.js" -type f | while read file; do
    echo "Updating $file"
    # Replace ngrok URLs with current domain
    sed -i 's|https://[a-z0-9]*.ngrok-free.app|https://elosofia.site|g' "$file"
    sed -i 's|wss://[a-z0-9]*.ngrok-free.app|wss://elosofia.site|g' "$file"
    sed -i 's|http://localhost:[0-9]*|https://elosofia.site|g' "$file"
    sed -i 's|ws://localhost:[0-9]*|wss://elosofia.site|g' "$file"
done

# Also update any JavaScript files that might have hardcoded URLs
find . -name "*.js" -path "*/public/*" -type f | while read file; do
    if grep -q "ngrok" "$file"; then
        echo "Found ngrok reference in $file"
        sed -i 's|https://[a-z0-9]*.ngrok-free.app|https://elosofia.site|g' "$file"
        sed -i 's|wss://[a-z0-9]*.ngrok-free.app|wss://elosofia.site|g' "$file"
    fi
done

# Create a new config.js that uses the current domain
cat > dental-calendar/public/config.js << 'EOF'
window.SOFIA_CONFIG = {
    // Dynamic configuration that uses the current domain
    API_BASE_URL: window.location.origin,
    WS_URL: window.location.origin.replace('https:', 'wss:').replace('http:', 'ws:'),
    LIVEKIT_URL: window.location.origin.replace('https:', 'wss:').replace('http:', 'ws:') + '/ws',
    
    // API endpoints
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

console.log('Sofia Configuration Updated:', window.SOFIA_CONFIG);
EOF

# Rebuild the Docker container to include the new config
docker-compose -f docker-compose.final.yml build app
docker-compose -f docker-compose.final.yml up -d

echo "Configuration fixed! Clear your browser cache and reload."