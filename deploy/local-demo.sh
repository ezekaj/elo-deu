#!/bin/bash
# Local Demo with Ngrok - Test Sofia without a server

echo "🚀 Starting Sofia locally with public access..."

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "Installing ngrok..."
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
    sudo apt update && sudo apt install ngrok
fi

# Start Sofia locally
cd /home/elo/elo-deu
docker-compose up -d

# Wait for services
sleep 10

# Start ngrok
echo "Starting ngrok tunnel..."
ngrok http 3005 --log=stdout > ngrok.log &
NGROK_PID=$!

sleep 5

# Get public URL
PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*"' | grep -o 'https://[^"]*' | head -1)

echo ""
echo "✅ Sofia is now accessible at:"
echo "   $PUBLIC_URL"
echo ""
echo "Share this URL to access Sofia from anywhere!"
echo "Press Ctrl+C to stop..."

# Wait for interrupt
trap "kill $NGROK_PID; docker-compose down; exit" INT
wait