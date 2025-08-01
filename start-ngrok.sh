#\!/bin/bash
# Kill any existing ngrok processes
pkill ngrok

# Start ngrok with our tunnels
ngrok start calendar-api livekit-ws sofia-agent &

# Wait for ngrok to start
sleep 5

# Get the URLs
echo "Waiting for ngrok to start..."
sleep 3

# Get tunnel URLs
TUNNELS=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null)

if [ -z "$TUNNELS" ]; then
    echo "Error: ngrok not started properly"
    exit 1
fi

echo "ngrok tunnels started:"
echo "$TUNNELS" | jq -r '.tunnels[] | "\(.name): \(.public_url)"'
