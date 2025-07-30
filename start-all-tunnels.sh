#!/bin/bash
# Start all ngrok tunnels for Sofia

echo "🚀 Starting all Sofia tunnels..."

# Kill existing ngrok processes
pkill -f ngrok || true
sleep 2

# Start ngrok with all tunnels
cat > /tmp/ngrok-config.yml << EOF
version: "2"
authtoken: 30bHgFrMVhObTijLQEzroz32D80_288PHDpAPbskFAnRDQzoF
tunnels:
  sofia-web:
    proto: http
    addr: 3005
    inspect: false
  livekit:
    proto: http
    addr: 7880
    inspect: false
  crm:
    proto: http
    addr: 5000
    inspect: false
EOF

# Start ngrok with multiple tunnels
nohup ngrok start --all --config /tmp/ngrok-config.yml > /tmp/ngrok-all.log 2>&1 &

echo "Waiting for tunnels to start..."
sleep 5

# Get tunnel URLs
echo ""
echo "📌 Your public URLs:"
echo "==================="

TUNNELS=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for tunnel in data.get('tunnels', []):
    if 'https' in tunnel['public_url']:
        print(f\"{tunnel['name']}: {tunnel['public_url']}\")
")

echo "$TUNNELS"

echo ""
echo "🌐 Configure these URLs at: https://elosofia.site"
echo ""
echo "To stop: pkill -f ngrok"
echo "To view logs: tail -f /tmp/ngrok-all.log"