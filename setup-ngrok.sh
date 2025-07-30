#!/bin/bash
# Setup Ngrok for Sofia

echo "🚀 Setting up Ngrok for secure HTTPS access"
echo "=========================================="
echo ""
echo "Step 1: Create a free Ngrok account"
echo "👉 Go to: https://dashboard.ngrok.com/signup"
echo ""
echo "Step 2: Get your authtoken"
echo "👉 After signup, go to: https://dashboard.ngrok.com/get-started/your-authtoken"
echo ""
read -p "Paste your authtoken here: " AUTHTOKEN

# Configure ngrok
ngrok config add-authtoken $AUTHTOKEN

echo ""
echo "✅ Ngrok configured!"
echo ""
echo "Starting tunnels..."

# Kill any existing ngrok
pkill -f ngrok || true
sleep 2

# Start web service tunnel
echo "Starting web tunnel on port 3005..."
nohup ngrok http 3005 --log=stdout > /tmp/ngrok-web.log 2>&1 &
NGROK_WEB_PID=$!
sleep 5

# Get the public URL
WEB_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*"' | grep -o 'https://[^"]*' | head -1)

if [ -z "$WEB_URL" ]; then
    echo "❌ Failed to start web tunnel. Check /tmp/ngrok-web.log"
    exit 1
fi

echo ""
echo "✅ Ngrok tunnels are running!"
echo ""
echo "🌐 Your public URLs:"
echo "Web Interface: $WEB_URL"
echo ""
echo "📝 Next steps:"
echo "1. Update your GitHub Pages site with these URLs"
echo "2. The URLs will change each time you restart ngrok"
echo "3. For permanent URLs, upgrade to ngrok paid plan"
echo ""
echo "To stop ngrok: pkill -f ngrok"
echo "To view logs: tail -f /tmp/ngrok-web.log"