#!/bin/bash

echo "🌐 MAKING ELOSOFIA.SITE GLOBALLY ACCESSIBLE"
echo "==========================================="

# Start fresh tunnels
echo "Starting backend services..."
cloudflared tunnel --url http://localhost:3005 2>&1 | tee calendar-new.log &
CALENDAR_PID=$!
sleep 5

cloudflared tunnel --url http://localhost:7880 2>&1 | tee voice-new.log &
VOICE_PID=$!
sleep 5

# Get the new URLs
CALENDAR_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' calendar-new.log | head -1)
VOICE_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' voice-new.log | head -1)

echo ""
echo "✅ Backend Services Running:"
echo "Calendar API: $CALENDAR_URL"
echo "Voice Service: $VOICE_URL"

# Create the config.js for GitHub Pages
cat > config-production.js << EOF
/**
 * Sofia Dental Configuration
 * Live at elosofia.site
 */
window.SOFIA_CONFIG = {
    API_BASE_URL: '${CALENDAR_URL}',
    CRM_URL: '${CALENDAR_URL}',
    LIVEKIT_URL: '${VOICE_URL}'.replace('https', 'wss'),
    LIVEKIT_API_URL: '${VOICE_URL}',
    WS_URL: '${CALENDAR_URL}'.replace('https', 'wss'),
    ENVIRONMENT: 'production',
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};

console.log('Sofia Dental - Live Configuration');
console.log('API:', window.SOFIA_CONFIG.API_BASE_URL);
console.log('Voice:', window.SOFIA_CONFIG.LIVEKIT_URL);
EOF

echo ""
echo "📋 UPDATE YOUR GITHUB PAGES:"
echo "============================"
echo ""
echo "1. Copy this new config.js to your GitHub repository:"
echo "   cp config-production.js [YOUR-GITHUB-REPO]/config.js"
echo ""
echo "2. Commit and push:"
echo "   cd [YOUR-GITHUB-REPO]"
echo "   git add config.js"
echo "   git commit -m 'Update backend URLs'"
echo "   git push"
echo ""
echo "3. Your site at https://elosofia.site will work globally!"
echo ""
echo "Backend URLs (keep these tunnels running):"
echo "- Calendar: $CALENDAR_URL"
echo "- Voice: $VOICE_URL"
echo ""
echo "Press Ctrl+C to stop (but keep running for the site to work!)"

# Keep running
trap "kill $CALENDAR_PID $VOICE_PID" EXIT
wait