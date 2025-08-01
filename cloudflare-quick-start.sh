#!/bin/bash

echo "======================================"
echo "Cloudflare Tunnel Quick Start"
echo "======================================"
echo ""
echo "This will set up a tunnel without needing a custom domain."
echo ""

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "❌ cloudflared not installed. Run ./install-cloudflare.sh first"
    exit 1
fi

# Kill any existing ngrok
echo "Stopping ngrok if running..."
pkill ngrok || true

# Start cloudflare tunnel with quick tunnel (no domain needed)
echo ""
echo "Starting Cloudflare tunnels..."
echo "================================"

# Create a script to run both tunnels
cat > run-tunnels.sh << 'EOF'
#!/bin/bash

# Function to get URL from cloudflared output
get_tunnel_url() {
    local log_file=$1
    local url=""
    local attempts=0
    
    while [ -z "$url" ] && [ $attempts -lt 30 ]; do
        url=$(grep -o 'https://[^[:space:]]*\.trycloudflare\.com' "$log_file" 2>/dev/null | head -1)
        ((attempts++))
        sleep 1
    done
    
    echo "$url"
}

# Start calendar tunnel
echo "Starting calendar tunnel..."
cloudflared tunnel --url http://localhost:3005 > calendar-tunnel.log 2>&1 &
CALENDAR_PID=$!

# Start LiveKit tunnel
echo "Starting LiveKit tunnel..."
cloudflared tunnel --url http://localhost:7880 > livekit-tunnel.log 2>&1 &
LIVEKIT_PID=$!

# Wait for URLs
echo "Waiting for tunnel URLs..."
CALENDAR_URL=$(get_tunnel_url "calendar-tunnel.log")
LIVEKIT_URL=$(get_tunnel_url "livekit-tunnel.log")

# Clear screen and show URLs
clear
echo "======================================"
echo "✅ Cloudflare Tunnels Active!"
echo "======================================"
echo ""
echo "Calendar URL: $CALENDAR_URL"
echo "LiveKit URL:  $LIVEKIT_URL"
echo ""
echo "Update your config.js with these URLs!"
echo ""
echo "Press Ctrl+C to stop tunnels"
echo "======================================"

# Create config update script
cat > update-config.js << EOF
// Update docs/config.js with:

window.SOFIA_CONFIG = {
    API_BASE_URL: '$CALENDAR_URL',
    CRM_URL: '$CALENDAR_URL',
    LIVEKIT_URL: '$LIVEKIT_URL'.replace('https', 'wss'),
    LIVEKIT_API_URL: '$LIVEKIT_URL',
    WS_URL: '$CALENDAR_URL'.replace('https', 'wss'),
    ENVIRONMENT: 'production',
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};
EOF

echo ""
echo "Config saved to: update-config.js"
echo ""

# Keep running
trap "kill $CALENDAR_PID $LIVEKIT_PID; rm -f calendar-tunnel.log livekit-tunnel.log" EXIT
wait
EOF

chmod +x run-tunnels.sh

echo "✅ Setup complete!"
echo ""
echo "Run ./run-tunnels.sh to start the tunnels"
echo ""