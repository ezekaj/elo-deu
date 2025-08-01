#!/bin/bash

# Start ngrok for Sofia dental calendar
echo "Starting ngrok tunnel for Sofia dental calendar..."

# Kill any existing ngrok processes
pkill ngrok 2>/dev/null

# Start ngrok in the background
nohup ngrok http 3005 --log=stdout > ngrok.log 2>&1 &

# Wait for ngrok to start
sleep 3

# Get the public URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | sed 's/"public_url":"//')

if [ -z "$NGROK_URL" ]; then
    echo "Error: Could not get ngrok URL"
    exit 1
fi

echo "Ngrok tunnel started: $NGROK_URL"
echo ""
echo "Next steps:"
echo "1. Update docs/config.js with the new ngrok URL: $NGROK_URL"
echo "2. Commit and push changes to GitHub"
echo "3. Access the site at: https://elosofia.site"
echo ""
echo "To stop ngrok: pkill ngrok"