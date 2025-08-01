#!/bin/bash

echo "🚀 Verifying elosofia.site Deployment"
echo "====================================="
echo ""

# Check frontend
echo "📱 Frontend Status:"
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://elosofia.site)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ Frontend is live at https://elosofia.site"
else
    echo "❌ Frontend returned status: $FRONTEND_STATUS"
fi

echo ""
echo "🔧 Backend Services:"

# Check calendar API
CALENDAR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://bulgaria-editorials-several-rack.trycloudflare.com/api/appointments)
echo "Calendar API: https://bulgaria-editorials-several-rack.trycloudflare.com"
if [ "$CALENDAR_STATUS" = "200" ]; then
    echo "✅ Calendar API is responding"
else
    echo "⚠️  Calendar API returned status: $CALENDAR_STATUS"
fi

# Check voice service
VOICE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://laboratories-israel-focusing-airport.trycloudflare.com)
echo ""
echo "Voice Service: https://laboratories-israel-focusing-airport.trycloudflare.com"
if [ "$VOICE_STATUS" = "404" ] || [ "$VOICE_STATUS" = "200" ]; then
    echo "✅ Voice Service tunnel is accessible"
else
    echo "⚠️  Voice Service returned status: $VOICE_STATUS"
fi

echo ""
echo "🎉 Deployment Summary:"
echo "- Frontend: https://elosofia.site (GitHub Pages)"
echo "- Calendar: https://bulgaria-editorials-several-rack.trycloudflare.com (Cloudflare Tunnel)"
echo "- Voice: https://laboratories-israel-focusing-airport.trycloudflare.com (Cloudflare Tunnel)"
echo ""
echo "Keep the tunnels running with: ./keep-running.sh"