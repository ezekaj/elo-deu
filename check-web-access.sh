#!/bin/bash

echo "🌐 Testing Web Access for Sofia Dental Assistant"
echo "================================================"

# Test local access
echo ""
echo "1. Testing Local Access:"
echo "   - Calendar (localhost:3005)..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3005 | grep -E "200|301|302" > /dev/null; then
    echo "     ✅ Success"
else
    echo "     ❌ Failed"
fi

# Test global access via Cloudflare
echo ""
echo "2. Testing Global Access via elosofia.site:"
echo "   - Main site (https://elosofia.site)..."
if curl -s -o /dev/null -w "%{http_code}" https://elosofia.site | grep -E "200|301|302" > /dev/null; then
    echo "     ✅ Success"
else
    echo "     ❌ Failed (check Cloudflare tunnel)"
fi

echo "   - CRM Dashboard (https://crm.elosofia.site)..."
if curl -s -o /dev/null -w "%{http_code}" https://crm.elosofia.site | grep -E "200|301|302|503" > /dev/null; then
    echo "     ✅ Reachable (may need CRM service running)"
else
    echo "     ❌ Failed (check Cloudflare tunnel)"
fi

# Show access URLs
echo ""
echo "📍 Access URLs:"
echo "   Local:  http://localhost:3005"
echo "   Global: https://elosofia.site"
echo ""
echo "📱 Sofia Voice Assistant:"
echo "   Click the microphone icon on the calendar page to start voice interaction"
echo ""
echo "🔧 If global access fails:"
echo "   1. Check Cloudflare tunnel: ps aux | grep cloudflared"
echo "   2. Restart tunnel: cloudflared tunnel run elosofia"
echo "   3. Check DNS: nslookup elosofia.site"