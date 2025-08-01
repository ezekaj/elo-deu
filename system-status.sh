#!/bin/bash

echo "🔍 Sofia Dental AI - Complete System Status"
echo "=========================================="
echo ""

# Backend Services
echo "📦 Docker Services:"
docker-compose ps | grep -E "(livekit|sofia-agent|turn-server)" | while read line; do
    if echo "$line" | grep -q "Up"; then
        echo "✅ $line"
    else
        echo "❌ $line"
    fi
done

echo ""
echo "🌐 Cloudflare Tunnels:"
echo "Calendar API: https://substantially-attempted-thai-pn.trycloudflare.com"
echo "Voice Service: https://vt-frog-dem-limitations.trycloudflare.com"

# Test API endpoints
echo ""
echo "🧪 Testing Services:"

# Test Calendar API
CALENDAR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://substantially-attempted-thai-pn.trycloudflare.com/api/appointments)
if [ "$CALENDAR_STATUS" = "200" ]; then
    echo "✅ Calendar API is responding (Status: $CALENDAR_STATUS)"
else
    echo "⚠️  Calendar API returned status: $CALENDAR_STATUS"
fi

# Test Voice Service
VOICE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://vt-frog-dem-limitations.trycloudflare.com)
if [ "$VOICE_STATUS" = "404" ] || [ "$VOICE_STATUS" = "200" ]; then
    echo "✅ Voice Service tunnel is accessible (Status: $VOICE_STATUS)"
else
    echo "⚠️  Voice Service returned status: $VOICE_STATUS"
fi

# Test LiveKit health
LIVEKIT_HEALTH=$(curl -s http://localhost:7880/health 2>/dev/null || echo "unreachable")
if [ "$LIVEKIT_HEALTH" = "unreachable" ]; then
    echo "⚠️  LiveKit health check failed"
else
    echo "✅ LiveKit is healthy"
fi

echo ""
echo "🌍 Frontend Status:"
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://elosofia.site)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ elosofia.site is live (Status: $FRONTEND_STATUS)"
else
    echo "❌ elosofia.site returned status: $FRONTEND_STATUS"
fi

echo ""
echo "📊 Summary:"
echo "- Frontend: https://elosofia.site"
echo "- Calendar Backend: https://substantially-attempted-thai-pn.trycloudflare.com"
echo "- Voice Backend: https://vt-frog-dem-limitations.trycloudflare.com"
echo ""
echo "💡 To test voice assistant:"
echo "1. Open https://elosofia.site"
echo "2. Click 'Mit Sofia sprechen'"
echo "3. Allow microphone access"
echo "4. Say 'Hallo Sofia'"