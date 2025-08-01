#!/bin/bash

echo "======================================"
echo "Alternative Deployment Options"
echo "Without Cloudflare Account"
echo "======================================"
echo ""
echo "Choose your preferred method:"
echo ""
echo "1) LocalTunnel (Free, no account needed)"
echo "2) Serveo.net (Free SSH tunnel)"
echo "3) Bore.pub (Free, minimal setup)"
echo "4) Keep using current Cloudflare temporary URLs"
echo "5) Deploy to GitHub Pages (for static parts)"
echo ""
read -p "Enter choice (1-5): " choice

case $choice in
    1)
        echo ""
        echo "Setting up LocalTunnel..."
        echo "========================="
        
        # Install localtunnel
        npm install -g localtunnel 2>/dev/null || sudo npm install -g localtunnel
        
        # Create start script
        cat > start-localtunnel.sh << 'EOF'
#!/bin/bash
echo "Starting LocalTunnel for Sofia Dental..."

# Start calendar tunnel
lt --port 3005 --subdomain sofia-calendar &
CALENDAR_PID=$!

# Start LiveKit tunnel  
lt --port 7880 --subdomain sofia-voice &
VOICE_PID=$!

# Wait for URLs
sleep 5

echo ""
echo "======================================"
echo "✅ LocalTunnel Active!"
echo "======================================"
echo ""
echo "Calendar: https://sofia-calendar.loca.lt"
echo "Voice: https://sofia-voice.loca.lt"
echo ""
echo "Note: Users will see a warning page first time"
echo "Press Ctrl+C to stop"
echo "======================================"

# Update config
cat > docs/config.js << 'CONFIG'
window.SOFIA_CONFIG = {
    API_BASE_URL: window.location.hostname === 'localhost' 
        ? 'http://localhost:3005' 
        : 'https://sofia-calendar.loca.lt',
    
    CRM_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:5000'
        : 'https://sofia-calendar.loca.lt',
    
    LIVEKIT_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:7880'
        : 'wss://sofia-voice.loca.lt',
    
    LIVEKIT_API_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:7880'
        : 'https://sofia-voice.loca.lt',
    
    WS_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:3005'
        : 'wss://sofia-calendar.loca.lt',
    
    ENVIRONMENT: window.location.hostname === 'localhost' ? 'development' : 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};
CONFIG

trap "kill $CALENDAR_PID $VOICE_PID" EXIT
wait
EOF
        chmod +x start-localtunnel.sh
        
        echo "✅ LocalTunnel configured!"
        echo "Run: ./start-localtunnel.sh"
        ;;
        
    2)
        echo ""
        echo "Setting up Serveo.net..."
        echo "========================"
        
        cat > start-serveo.sh << 'EOF'
#!/bin/bash
echo "Starting Serveo.net tunnels..."
echo "=============================="

# Function to extract serveo URL
get_serveo_url() {
    local log_file=$1
    grep -o 'https://[^[:space:]]*\.serveo\.net' "$log_file" | head -1
}

# Start tunnels in background
ssh -R 80:localhost:3005 serveo.net > calendar-serveo.log 2>&1 &
CALENDAR_PID=$!

ssh -R 80:localhost:7880 serveo.net > voice-serveo.log 2>&1 &
VOICE_PID=$!

# Wait for URLs
sleep 5

CALENDAR_URL=$(get_serveo_url calendar-serveo.log)
VOICE_URL=$(get_serveo_url voice-serveo.log)

echo ""
echo "✅ Serveo.net tunnels active!"
echo ""
echo "Calendar: $CALENDAR_URL"
echo "Voice: $VOICE_URL"
echo ""
echo "Press Ctrl+C to stop"

trap "kill $CALENDAR_PID $VOICE_PID; rm -f *-serveo.log" EXIT
wait
EOF
        chmod +x start-serveo.sh
        
        echo "✅ Serveo configured!"
        echo "Run: ./start-serveo.sh"
        echo "Note: No account needed, just SSH!"
        ;;
        
    3)
        echo ""
        echo "Setting up Bore.pub..."
        echo "======================"
        
        # Download bore if not exists
        if [ ! -f /usr/local/bin/bore ]; then
            echo "Installing bore..."
            wget -q https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz
            tar -xf bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz
            sudo mv bore /usr/local/bin/ 2>/dev/null || mv bore ~/.local/bin/
            rm bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz
        fi
        
        cat > start-bore.sh << 'EOF'
#!/bin/bash
echo "Starting Bore.pub tunnels..."
echo "==========================="

bore local 3005 --to bore.pub &
CALENDAR_PID=$!
echo "Calendar starting..."

sleep 3

bore local 7880 --to bore.pub &  
VOICE_PID=$!
echo "Voice starting..."

sleep 3

echo ""
echo "✅ Bore.pub tunnels active!"
echo ""
echo "Check the URLs above ☝️"
echo "They look like: bore.pub:XXXXX"
echo ""
echo "Press Ctrl+C to stop"

trap "kill $CALENDAR_PID $VOICE_PID" EXIT
wait
EOF
        chmod +x start-bore.sh
        
        echo "✅ Bore.pub configured!"
        echo "Run: ./start-bore.sh"
        ;;
        
    4)
        echo ""
        echo "Current Cloudflare URLs"
        echo "======================="
        echo ""
        echo "Your app is already running at:"
        echo "- Calendar: https://impacts-approximate-florist-cartridges.trycloudflare.com"
        echo "- Voice: wss://maximum-topic-malawi-ltd.trycloudflare.com"
        echo ""
        echo "These will work until you stop the tunnels."
        echo "No account needed!"
        ;;
        
    5)
        echo ""
        echo "GitHub Pages Deployment"
        echo "======================="
        echo ""
        echo "Since you already have elosofia.site on GitHub Pages,"
        echo "we can deploy the frontend there and use tunnels for backend."
        echo ""
        echo "Creating GitHub Pages version..."
        
        # Create static version
        mkdir -p github-pages
        cp -r docs/* github-pages/
        
        # Update config for GitHub Pages
        cat > github-pages/config.js << 'EOF'
window.SOFIA_CONFIG = {
    // Use the tunnel URLs for API
    API_BASE_URL: 'https://impacts-approximate-florist-cartridges.trycloudflare.com',
    CRM_URL: 'https://impacts-approximate-florist-cartridges.trycloudflare.com',
    LIVEKIT_URL: 'wss://maximum-topic-malawi-ltd.trycloudflare.com',
    LIVEKIT_API_URL: 'https://maximum-topic-malawi-ltd.trycloudflare.com',
    WS_URL: 'wss://impacts-approximate-florist-cartridges.trycloudflare.com',
    
    ENVIRONMENT: 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};
EOF
        
        echo "✅ GitHub Pages version created in ./github-pages/"
        echo ""
        echo "To deploy:"
        echo "1. Push github-pages folder to your repo"
        echo "2. Enable GitHub Pages in repo settings"
        echo "3. Access at https://elosofia.site"
        ;;
esac

echo ""
echo "======================================"
echo "Recommendation"
echo "======================================"
echo ""
echo "For easiest setup without accounts:"
echo "- Option 1 (LocalTunnel) - Most reliable"
echo "- Option 4 (Current URLs) - Already working"
echo ""
echo "For custom domain (elosofia.site):"
echo "- Option 5 (GitHub Pages) + tunnels for backend"