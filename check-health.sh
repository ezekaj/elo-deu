#!/bin/bash
# Health check script for Sofia Dental AI

echo "🏥 Sofia Dental AI - Health Check Report"
echo "========================================"
echo ""

# Function to check service health
check_service() {
    local name=$1
    local url=$2
    
    echo -n "Checking $name... "
    
    if curl -s -f "$url" > /dev/null 2>&1; then
        echo "✅ OK"
        curl -s "$url" | jq . 2>/dev/null || curl -s "$url"
    else
        echo "❌ FAILED"
    fi
    echo ""
}

# Check all services
check_service "LiveKit Server" "http://localhost:7880/health"
check_service "Sofia Agent" "http://localhost:8080/health"
check_service "Dental Calendar" "http://localhost:3005/health"

# Check Docker containers
echo "📋 Docker Container Status:"
echo "--------------------------"
docker-compose ps

echo ""
echo "🔍 Network Connectivity Test:"
echo "----------------------------"

# Test network between containers
echo -n "Sofia → LiveKit: "
docker exec elo-deu-sofia-agent-1 ping -c 1 -W 2 livekit >/dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

echo -n "Sofia → Calendar: "
docker exec elo-deu-sofia-agent-1 ping -c 1 -W 2 dental-calendar >/dev/null 2>&1 && echo "✅ OK" || echo "❌ FAILED"

# Check TURN server
echo ""
echo "🔄 TURN Server Status:"
echo "--------------------"
echo -n "TURN TCP Port 3478: "
nc -zv localhost 3478 2>&1 | grep -q succeeded && echo "✅ OPEN" || echo "❌ CLOSED"

# Test token generation
echo ""
echo "🎟️ Token Generation Test:"
echo "------------------------"
RESPONSE=$(curl -s -X POST http://localhost:3005/api/livekit-token \
  -H 'Content-Type: application/json' \
  -d '{"identity":"health-check","room":"test-room"}' 2>/dev/null)

if echo "$RESPONSE" | jq -e '.token' >/dev/null 2>&1; then
    echo "✅ Token generation working"
else
    echo "❌ Token generation failed"
    echo "Response: $RESPONSE"
fi

echo ""
echo "📊 Summary:"
echo "----------"
echo "Run 'docker-compose logs -f' to view real-time logs"
echo "Run './apply-sofia-fixes.sh' to apply all fixes"