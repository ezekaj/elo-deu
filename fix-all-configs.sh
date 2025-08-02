#!/bin/bash
# Run these commands on your VPS to fix ALL config files

echo "Fixing all configuration files..."

# 1. Find and update ALL config.js files
find /root/elo-deu -name "config.js" -type f -exec bash -c '
echo "Updating: {}"
cat > {} << "EOF"
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.protocol + "//" + window.location.host,
    LIVEKIT_URL: "wss://" + window.location.host + "/ws",
    LIVEKIT_API_KEY: "devkey",
    LIVEKIT_API_SECRET: "secret",
    ENVIRONMENT: "production",
    FEATURES: {
        VOICE_ENABLED: true,
        DEMO_MODE: false
    }
};
console.log("Sofia Configuration Updated:", window.SOFIA_CONFIG);
EOF
' \;

# 2. Clear any cached files
rm -f /root/elo-deu/dental-calendar/public/config.js?v=*
rm -f /root/elo-deu/dental-calendar/public/*.js.map

# 3. Create mock API endpoints
mkdir -p /root/elo-deu/dental-calendar/public/api
echo '[]' > /root/elo-deu/dental-calendar/public/api/appointments
echo '{"status":"ok"}' > /root/elo-deu/dental-calendar/public/api/health

# 4. Update production.html to force reload
sed -i 's/config\.js?v=[0-9]*/config.js?v='$(date +%s)'/g' /root/elo-deu/dental-calendar/public/production.html 2>/dev/null || true

echo "Done! Clear your browser cache and reload."