#!/bin/bash

echo "🌐 KEEPING ELOSOFIA.SITE ONLINE"
echo "==============================="
echo ""
echo "Starting backend services..."
echo ""

# Start tunnels if not running
if ! pgrep -f "cloudflared.*3005" > /dev/null; then
    cloudflared tunnel --url http://localhost:3005 &
    echo "✅ Calendar API started"
else
    echo "✅ Calendar API already running"
fi

if ! pgrep -f "cloudflared.*7880" > /dev/null; then
    cloudflared tunnel --url http://localhost:7880 &
    echo "✅ Voice Service started"
else
    echo "✅ Voice Service already running"
fi

echo ""
echo "Your backend URLs:"
echo "=================="
echo "Calendar: https://robot-schools-prices-clip.trycloudflare.com"
echo "Voice: https://depends-sympathy-federation-invention.trycloudflare.com"
echo ""
echo "⚠️  IMPORTANT: Keep this terminal open for the site to work!"
echo ""
echo "Press Ctrl+C to stop"

# Keep running
while true; do
    sleep 60
    echo -n "."
done