#!/bin/bash
# Sofia Dental AI - Issue Validation Script
# This script checks for all known issues and reports status

echo "======================================"
echo "Sofia Dental AI - System Validation"
echo "======================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ PASS${NC}"
    else
        echo -e "${RED}❌ FAIL${NC}"
    fi
}

# 1. Check LiveKit Configuration
echo "1. LiveKit Configuration Check"
echo "------------------------------"

echo -n "   - Config file exists: "
if [ -f "livekit.yaml" ]; then
    check_status 0
    
    echo -n "   - TURN config present: "
    grep -q "^turn:" livekit.yaml
    check_status $?
    
    echo -n "   - ICE transport policy: "
    grep -q "ice_transport_policy" livekit.yaml
    check_status $?
    
    echo -n "   - STUN servers configured: "
    grep -q "stun_servers" livekit.yaml
    check_status $?
    
    echo -n "   - TCP port configured: "
    grep -q "tcp_port: 7881" livekit.yaml
    check_status $?
else
    check_status 1
fi

echo

# 2. Check Docker Services
echo "2. Docker Services Status"
echo "------------------------"

echo -n "   - LiveKit container: "
docker ps | grep -q "livekit" && check_status 0 || check_status 1

echo -n "   - Sofia agent container: "
docker ps | grep -q "sofia-agent" && check_status 0 || check_status 1

echo -n "   - Calendar container: "
docker ps | grep -q "dental-calendar" && check_status 0 || check_status 1

echo -n "   - TURN server container: "
docker ps | grep -q "turn" && check_status 0 || check_status 1

echo

# 3. Check Network Connectivity
echo "3. Network Connectivity"
echo "----------------------"

echo -n "   - LiveKit HTTP port (7880): "
nc -zv localhost 7880 &>/dev/null
check_status $?

echo -n "   - LiveKit TCP port (7881): "
nc -zv localhost 7881 &>/dev/null
check_status $?

echo -n "   - Sofia agent port (8080): "
nc -zv localhost 8080 &>/dev/null
check_status $?

echo -n "   - Calendar API port (3005): "
nc -zv localhost 3005 &>/dev/null
check_status $?

echo -n "   - TURN TCP port (3478): "
nc -zv localhost 3478 &>/dev/null
check_status $?

echo

# 4. Check API Endpoints
echo "4. API Endpoints"
echo "---------------"

echo -n "   - LiveKit health check: "
curl -s -o /dev/null -w "%{http_code}" http://localhost:7880/health | grep -q "200" && check_status 0 || check_status 1

echo -n "   - Sofia agent health: "
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health | grep -q "200" && check_status 0 || check_status 1

echo -n "   - Calendar health: "
curl -s -o /dev/null -w "%{http_code}" http://localhost:3005/api/health | grep -q "200" && check_status 0 || check_status 1

echo -n "   - LiveKit token endpoint: "
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3005/api/livekit-token \
  -H "Content-Type: application/json" \
  -d '{"identity":"test","room":"test"}' | grep -q "200" && check_status 0 || check_status 1

echo

# 5. Check Docker Network
echo "5. Docker Network"
echo "----------------"

echo -n "   - Network exists: "
docker network ls | grep -q "sofia-network" && check_status 0 || check_status 1

if docker network ls | grep -q "sofia-network"; then
    echo -n "   - Services on network: "
    SERVICE_COUNT=$(docker network inspect elo-deu_sofia-network 2>/dev/null | grep -c '"Name"' || echo 0)
    if [ $SERVICE_COUNT -ge 3 ]; then
        check_status 0
        echo "     (Found $SERVICE_COUNT services)"
    else
        check_status 1
        echo "     (Found $SERVICE_COUNT services, expected at least 3)"
    fi
fi

echo

# 6. Check TCP-Only Configuration
echo "6. TCP-Only Mode"
echo "---------------"

echo -n "   - UDP port NOT listening: "
! nc -zu localhost 7882 &>/dev/null
check_status $?

echo -n "   - ICE policy is relay: "
grep -q "ice_transport_policy.*relay" livekit.yaml
check_status $?

echo -n "   - UDP ports disabled: "
grep -q "port_range_start: 0" livekit.yaml && grep -q "port_range_end: 0" livekit.yaml
check_status $?

echo

# 7. Summary
echo "======================================"
echo "Summary"
echo "======================================"

# Count failures
FAILURES=0
if ! grep -q "^turn:" livekit.yaml 2>/dev/null; then ((FAILURES++)); fi
if ! docker ps | grep -q "sofia-agent"; then ((FAILURES++)); fi
if ! curl -s http://localhost:8080/health &>/dev/null; then ((FAILURES++)); fi
if ! curl -s -X POST http://localhost:3005/api/livekit-token -H "Content-Type: application/json" -d '{"identity":"test","room":"test"}' &>/dev/null; then ((FAILURES++)); fi

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}✅ All systems operational!${NC}"
else
    echo -e "${RED}❌ Found $FAILURES critical issues${NC}"
    echo
    echo "To fix these issues, run:"
    echo -e "${YELLOW}./apply-sofia-fixes.sh${NC}"
fi

echo
echo "For detailed test results, run:"
echo "python -m pytest tests/test_complete_sofia_fixes.py -v"