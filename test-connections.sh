#!/bin/bash

echo "🔍 Testing All Connections for elosofia.site"
echo "==========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test a service
test_service() {
    local name=$1
    local url=$2
    local extra_headers=$3
    
    echo -n "Testing $name... "
    
    if curl -s -f -m 5 $extra_headers "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        return 1
    fi
}

echo ""
echo "1. Local Services:"
echo "------------------"
test_service "Dental Calendar" "http://localhost:3005"
test_service "LiveKit Server" "http://localhost:7880/health"
test_service "CRM Dashboard" "http://localhost:5000"
test_service "Sofia Agent" "http://localhost:8080"

echo ""
echo "2. Ngrok Tunnels:"
echo "-----------------"
test_service "Calendar Tunnel" "https://772ec752906e.ngrok-free.app" "-H 'ngrok-skip-browser-warning: true'"
test_service "LiveKit Tunnel" "https://9608f5535742.ngrok-free.app/health" "-H 'ngrok-skip-browser-warning: true'"
test_service "CRM Tunnel" "https://3358fa3712d6.ngrok-free.app" "-H 'ngrok-skip-browser-warning: true'"

echo ""
echo "3. GitHub Pages:"
echo "----------------"
test_service "Main Site" "https://elosofia.site"
test_service "Config JS" "https://elosofia.site/config.js"
test_service "Calendar JS" "https://elosofia.site/calendar.js"
test_service "Status Page" "https://elosofia.site/status.html"

echo ""
echo "4. API Endpoints:"
echo "-----------------"
test_service "Appointments API" "https://772ec752906e.ngrok-free.app/api/appointments" "-H 'ngrok-skip-browser-warning: true'"
test_service "Sofia Status API" "https://772ec752906e.ngrok-free.app/api/sofia/status" "-H 'ngrok-skip-browser-warning: true'"

echo ""
echo "5. Docker Containers:"
echo "--------------------"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(dental|sofia|livekit|crm)" || echo "No relevant containers found"

echo ""
echo "==========================================="
echo "Test completed!"