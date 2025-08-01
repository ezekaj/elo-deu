#!/bin/bash

echo "Setting up LocalTunnel (Free ngrok alternative)"
echo "=============================================="

# Install localtunnel
npm install -g localtunnel

# Create startup script
cat > start-tunnels.sh << 'EOF'
#!/bin/bash

# Start calendar tunnel
echo "Starting calendar tunnel..."
lt --port 3005 --subdomain sofia-calendar &
CALENDAR_PID=$!

# Start LiveKit tunnel
echo "Starting LiveKit tunnel..."
lt --port 7880 --subdomain sofia-livekit &
LIVEKIT_PID=$!

echo "Tunnels started!"
echo "Calendar: https://sofia-calendar.loca.lt"
echo "LiveKit: https://sofia-livekit.loca.lt"
echo ""
echo "Press Ctrl+C to stop"

# Wait for Ctrl+C
trap "kill $CALENDAR_PID $LIVEKIT_PID" INT
wait
EOF

chmod +x start-tunnels.sh

echo "Run ./start-tunnels.sh to start both tunnels"