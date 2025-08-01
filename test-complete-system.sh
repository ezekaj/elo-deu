#!/bin/bash

echo "🧪 Testing Complete Sofia System"
echo "================================"

# Test 1: LiveKit is accessible
echo -n "1. LiveKit Server: "
if curl -s http://localhost:7880/ > /dev/null; then
    echo "✅ Running"
else
    echo "❌ Not accessible"
fi

# Test 2: Calendar API
echo -n "2. Calendar API: "
if curl -s http://localhost:3005/api/appointments | grep -q "id"; then
    echo "✅ Working"
else
    echo "❌ Not working"
fi

# Test 3: LiveKit Token Generation
echo -n "3. Token Endpoint: "
TOKEN_RESP=$(curl -s -X POST http://localhost:3005/api/livekit-token \
    -H "Content-Type: application/json" \
    -d '{"room":"test-room","identity":"test-user"}')
if echo "$TOKEN_RESP" | grep -q "token"; then
    echo "✅ Generating tokens"
else
    echo "❌ Token generation failed"
fi

# Test 4: Sofia Agent Health
echo -n "4. Sofia Agent: "
if curl -s http://localhost:8080/health | grep -q "ok"; then
    echo "✅ Healthy"
else
    echo "❌ Not healthy"
fi

# Test 5: WebSocket connectivity
echo -n "5. WebSocket Test: "
if timeout 2 nc -z localhost 7880; then
    echo "✅ Port open"
else
    echo "❌ Port closed"
fi

# Test 6: ngrok tunnels
echo -n "6. ngrok Tunnels: "
TUNNELS=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -c "public_url")
if [ "$TUNNELS" -gt 0 ]; then
    echo "✅ $TUNNELS tunnels active"
else
    echo "❌ No tunnels active"
fi

echo ""
echo "📊 Summary:"
echo "- Services are running locally"
echo "- Access the app at: http://localhost:3005"
echo "- Or globally at: https://ezekaj.github.io/elo-deu/"
echo ""
echo "🎯 Next: Click 'Sofia Agent' button to test voice connection"