#!/bin/bash
# WebRTC Troubleshooting Script for Sofia Voice Features

set -euo pipefail

echo "🔍 Sofia WebRTC Troubleshooting"
echo "==============================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check Services
echo "1. Checking Services Status..."
echo "------------------------------"

# Check LiveKit
if docker ps | grep -q livekit; then
    check_pass "LiveKit container is running"
    
    # Check LiveKit health
    if curl -s http://localhost:7880/health | grep -q "OK"; then
        check_pass "LiveKit health check passed"
    else
        check_fail "LiveKit health check failed"
    fi
else
    check_fail "LiveKit container is not running"
fi

# Check TURN server
if docker ps | grep -q coturn; then
    check_pass "TURN server container is running"
else
    check_fail "TURN server container is not running"
fi

echo

# 2. Check Ports
echo "2. Checking Port Availability..."
echo "--------------------------------"

# Check TCP ports
for port in 80 443 7880 7881 3478; do
    if ss -tlnp | grep -q ":$port "; then
        check_pass "TCP port $port is listening"
    else
        check_fail "TCP port $port is NOT listening"
    fi
done

# Check UDP ports
if ss -ulnp | grep -q ":3478 "; then
    check_pass "TURN UDP port 3478 is listening"
else
    check_fail "TURN UDP port 3478 is NOT listening"
fi

# Check WebRTC UDP range
open_udp_ports=$(ss -ulnp | grep -E ':(5[0-9]{4}|60000)' | wc -l)
if [ $open_udp_ports -gt 0 ]; then
    check_pass "WebRTC UDP ports (50000-60000) are available: $open_udp_ports ports"
else
    check_warn "No WebRTC UDP ports detected (this is normal if no active sessions)"
fi

echo

# 3. Check Firewall
echo "3. Checking Firewall Rules..."
echo "-----------------------------"

if command -v ufw &> /dev/null; then
    # Check if firewall is active
    if ufw status | grep -q "Status: active"; then
        check_pass "Firewall is active"
        
        # Check specific rules
        if ufw status | grep -q "50000:60000/udp"; then
            check_pass "WebRTC UDP port range is allowed"
        else
            check_fail "WebRTC UDP port range is NOT allowed"
            echo "  Fix: sudo ufw allow 50000:60000/udp"
        fi
        
        if ufw status | grep -q "3478"; then
            check_pass "TURN server ports are allowed"
        else
            check_fail "TURN server ports are NOT allowed"
            echo "  Fix: sudo ufw allow 3478/tcp && sudo ufw allow 3478/udp"
        fi
    else
        check_warn "Firewall is not active"
    fi
else
    check_warn "UFW not installed"
fi

echo

# 4. Check Network Configuration
echo "4. Checking Network Configuration..."
echo "-----------------------------------"

# Get public IP
PUBLIC_IP=$(curl -s https://ipinfo.io/ip)
check_pass "Public IP detected: $PUBLIC_IP"

# Check if IP is configured in services
if docker exec livekit printenv | grep -q "NODE_IP=$PUBLIC_IP"; then
    check_pass "LiveKit is configured with correct public IP"
else
    check_warn "LiveKit might not be configured with public IP"
fi

# Check DNS resolution
if host api.elosofia.site | grep -q "$PUBLIC_IP"; then
    check_pass "DNS resolution for api.elosofia.site is correct"
else
    check_fail "DNS resolution for api.elosofia.site is incorrect"
    echo "  Current: $(host api.elosofia.site | grep 'has address' | awk '{print $4}')"
    echo "  Expected: $PUBLIC_IP"
fi

echo

# 5. Test TURN Server
echo "5. Testing TURN Server..."
echo "-------------------------"

# Check TURN credentials
if [ -f /opt/sofia-deployment/.env ]; then
    source /opt/sofia-deployment/.env
    if [ ! -z "$TURN_USERNAME" ] && [ ! -z "$TURN_PASSWORD" ]; then
        check_pass "TURN credentials are configured"
        
        # Test TURN allocation
        echo "  Testing TURN allocation..."
        docker exec coturn turnadmin -k -u $TURN_USERNAME -r elosofia.site &> /dev/null && \
            check_pass "TURN server accepts credentials" || \
            check_fail "TURN server credential test failed"
    else
        check_fail "TURN credentials not found"
    fi
else
    check_warn "Environment file not found"
fi

echo

# 6. Check SSL Certificates
echo "6. Checking SSL Certificates..."
echo "-------------------------------"

if [ -f /etc/letsencrypt/live/elosofia.site/cert.pem ]; then
    check_pass "SSL certificate exists"
    
    # Check expiry
    expiry=$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/elosofia.site/cert.pem | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry" +%s)
    now_epoch=$(date +%s)
    days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
    
    if [ $days_left -gt 30 ]; then
        check_pass "SSL certificate valid for $days_left days"
    elif [ $days_left -gt 0 ]; then
        check_warn "SSL certificate expires in $days_left days"
    else
        check_fail "SSL certificate has expired!"
    fi
else
    check_fail "SSL certificate not found"
fi

echo

# 7. Test WebSocket Connection
echo "7. Testing WebSocket Connection..."
echo "---------------------------------"

# Test LiveKit WebSocket
response=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: test" \
    https://api.elosofia.site/livekit)

if [ "$response" = "101" ] || [ "$response" = "426" ]; then
    check_pass "WebSocket endpoint is reachable"
else
    check_fail "WebSocket endpoint returned HTTP $response"
fi

echo

# 8. Check Logs for Errors
echo "8. Checking Recent Logs..."
echo "--------------------------"

# Check LiveKit logs
echo "Recent LiveKit errors:"
docker logs livekit --tail 20 2>&1 | grep -i error || echo "  No recent errors"

echo
echo "Recent TURN server errors:"
docker logs coturn --tail 20 2>&1 | grep -i error || echo "  No recent errors"

echo

# 9. Generate Test Report
echo "9. Test Summary"
echo "---------------"

# Create test connection URL
cat << EOF

To test WebRTC connectivity from a browser:

1. Open: https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
2. Add STUN server: stun:api.elosofia.site:3478
3. Add TURN server: 
   - URL: turn:api.elosofia.site:3478
   - Username: $TURN_USERNAME
   - Password: $TURN_PASSWORD
4. Click "Gather candidates"
5. You should see:
   - srflx candidates (STUN working)
   - relay candidates (TURN working)

If you see both types, WebRTC should work properly.

EOF

# Final recommendations
echo "📋 Recommendations:"
echo "-------------------"

if docker logs livekit --tail 100 2>&1 | grep -q "failed to connect"; then
    echo "- LiveKit showing connection errors. Check network configuration."
fi

if ! ss -ulnp | grep -q ":3478 "; then
    echo "- TURN server not listening. Restart with: docker compose restart coturn"
fi

if [ $days_left -lt 30 ] 2>/dev/null; then
    echo "- Renew SSL certificate soon: certbot renew"
fi

echo
echo "🔧 Quick Fixes:"
echo "- Restart all services: cd /opt/sofia-deployment && docker compose restart"
echo "- View real-time logs: docker compose logs -f livekit"
echo "- Test from browser: https://elosofia.site"