#!/bin/bash

echo "🚀 STARTING EVERYTHING FOR ELOSOFIA.SITE"
echo "========================================"

# Kill existing tunnels
pkill cloudflared 2>/dev/null

# Start fresh tunnels and capture URLs
echo "Starting calendar tunnel..."
cloudflared tunnel --url http://localhost:3005 > /tmp/calendar-tunnel.log 2>&1 &
CALENDAR_PID=$!

echo "Starting voice tunnel..."
cloudflared tunnel --url http://localhost:7880 > /tmp/voice-tunnel.log 2>&1 &
VOICE_PID=$!

# Wait for URLs
echo "Waiting for tunnels to start..."
sleep 8

# Extract URLs
CALENDAR_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' /tmp/calendar-tunnel.log | head -1)
VOICE_URL=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' /tmp/voice-tunnel.log | head -1)

echo ""
echo "✅ SERVICES RUNNING!"
echo "==================="
echo "Calendar: $CALENDAR_URL"
echo "Voice: $VOICE_URL"

# Update the deployment config
cat > elosofia-site-deploy/config.js << EOF
window.SOFIA_CONFIG = {
    API_BASE_URL: '$CALENDAR_URL',
    CRM_URL: '$CALENDAR_URL',
    LIVEKIT_URL: '${VOICE_URL}'.replace('https', 'wss'),
    LIVEKIT_API_URL: '$VOICE_URL',
    WS_URL: '${CALENDAR_URL}'.replace('https', 'wss'),
    ENVIRONMENT: 'production',
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};
EOF

# Commit the update
cd elosofia-site-deploy
git add config.js
git commit -m "Update tunnel URLs"

echo ""
echo "📋 DEPLOYMENT INSTRUCTIONS"
echo "========================="
echo ""
echo "Option 1: If you have GitHub account:"
echo "-------------------------------------"
echo "1. Go to: https://github.com/new"
echo "2. Repository name: elosofia-site"
echo "3. Make it Public"
echo "4. Create repository"
echo "5. Then run:"
echo ""
echo "cd $(pwd)"
echo "git remote add origin https://github.com/YOUR_USERNAME/elosofia-site.git"
echo "git push -u origin main"
echo ""
echo "6. Go to Settings > Pages"
echo "7. Source: Deploy from branch"
echo "8. Branch: main, folder: / (root)"
echo "9. Save"
echo ""
echo "Option 2: Use existing GitHub Pages:"
echo "------------------------------------"
echo "Just copy all files from elosofia-site-deploy/"
echo "to your existing GitHub Pages repository"
echo ""
echo "✅ Your site will be live at https://elosofia.site"
echo ""
echo "Press Ctrl+C to stop tunnels"

# Keep running
trap "kill $CALENDAR_PID $VOICE_PID" EXIT
wait