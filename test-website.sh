#!/bin/bash

echo "Testing Sofia Dental Calendar Website..."
echo "========================================"

# Check local access
echo -n "1. Local access (http://localhost:3005): "
LOCAL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3005)
if [ "$LOCAL_STATUS" = "200" ]; then
    echo "✅ Working ($LOCAL_STATUS)"
else
    echo "❌ Failed ($LOCAL_STATUS)"
fi

# Check ngrok tunnel
echo -n "2. Ngrok tunnel status: "
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' || echo "")
if [ -n "$NGROK_URL" ]; then
    echo "✅ Active at $NGROK_URL"
else
    echo "❌ Not running"
    exit 1
fi

# Check external access
echo -n "3. External access ($NGROK_URL): "
EXTERNAL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "ngrok-skip-browser-warning: true" "$NGROK_URL")
if [ "$EXTERNAL_STATUS" = "200" ]; then
    echo "✅ Working ($EXTERNAL_STATUS)"
else
    echo "❌ Failed ($EXTERNAL_STATUS)"
fi

# Check API endpoint
echo -n "4. API endpoint (/api/appointments): "
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "ngrok-skip-browser-warning: true" "$NGROK_URL/api/appointments")
if [ "$API_STATUS" = "200" ]; then
    echo "✅ Working ($API_STATUS)"
else
    echo "❌ Failed ($API_STATUS)"
fi

echo ""
echo "Website URL: $NGROK_URL"
echo ""
echo "Note: The Sofia voice feature requires LiveKit to be accessible."
echo "Currently, only calendar functions are available through ngrok."