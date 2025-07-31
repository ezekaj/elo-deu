#!/bin/bash

echo "🔍 Testing Sofia Endpoints..."
echo ""

# Test local endpoints
echo "1. Local API Test:"
curl -s -o /dev/null -w "   Calendar API: %{http_code}\n" http://localhost:3005/api/appointments
curl -s -o /dev/null -w "   Health Check: %{http_code}\n" http://localhost:3005/health

# Test global endpoints
echo ""
echo "2. Global API Test (via Cloudflare):"
curl -s -o /dev/null -w "   Main Site: %{http_code}\n" https://elosofia.site/
curl -s -o /dev/null -w "   Calendar API: %{http_code}\n" https://elosofia.site/api/appointments

# Test if we're getting JSON
echo ""
echo "3. API Response Test:"
response=$(curl -s http://localhost:3005/api/appointments)
if [[ $response == \[* ]] || [[ $response == \{* ]]; then
    echo "   ✅ Local API returns JSON"
else
    echo "   ❌ Local API not returning JSON"
fi

# Show actual response from global
echo ""
echo "4. Global Response Preview:"
curl -s https://elosofia.site/api/appointments | head -c 200