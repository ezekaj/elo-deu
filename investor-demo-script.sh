#!/bin/bash

echo "🚀 Sofia Dental Assistant - Investor Demo Status"
echo "==============================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check services
echo "📊 Service Status:"
echo ""

# Check dental-calendar
if curl -s http://localhost:3005/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Dental Calendar API${NC} - Running on port 3005"
else
    echo -e "${RED}❌ Dental Calendar API${NC} - Not responding"
fi

# Check LiveKit
if curl -s http://localhost:7880/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ LiveKit Voice Server${NC} - Running on port 7880"
else
    echo -e "${RED}❌ LiveKit Voice Server${NC} - Not responding"
fi

# Check CRM
if curl -s http://localhost:5000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ CRM Dashboard${NC} - Running on port 5000"
else
    echo -e "${RED}❌ CRM Dashboard${NC} - Not responding"
fi

# Check Sofia Agent
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Sofia Voice Agent${NC} - Running on port 8080"
else
    echo -e "${YELLOW}⚠️  Sofia Voice Agent${NC} - Starting up..."
fi

# Check Cloudflare tunnel
if pgrep -f "cloudflared" > /dev/null; then
    echo -e "${GREEN}✅ Cloudflare Tunnel${NC} - Active"
else
    echo -e "${RED}❌ Cloudflare Tunnel${NC} - Not running"
fi

echo ""
echo "🌐 Access URLs:"
echo ""
echo "📱 Main Application:"
echo "   Local:  http://localhost:3005"
echo "   Global: https://elosofia.site"
echo ""
echo "📊 CRM Dashboard:"
echo "   Local:  http://localhost:5000"
echo "   Global: https://crm.elosofia.site"
echo ""

# Test global access
echo "🔍 Testing Global Access:"
if curl -s -o /dev/null -w "%{http_code}" https://elosofia.site | grep -E "200|301|302" > /dev/null; then
    echo -e "   ${GREEN}✅ elosofia.site is accessible${NC}"
else
    echo -e "   ${RED}❌ elosofia.site is not accessible${NC}"
fi

echo ""
echo "📋 Demo Instructions:"
echo "1. Open https://elosofia.site in your browser"
echo "2. Click the microphone icon 🎤 to start voice interaction"
echo "3. Say 'Hallo Sofia' to begin"
echo "4. Try booking an appointment: 'Ich möchte einen Termin buchen'"
echo ""
echo "🎯 Key Features to Demonstrate:"
echo "   • Voice-activated appointment booking in German"
echo "   • Real-time calendar integration"
echo "   • Natural conversation flow"
echo "   • Instant appointment confirmation"
echo "   • CRM dashboard for appointment management"
echo ""

# Show container health
echo "🐳 Docker Container Health:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep elo-deu

echo ""
echo "💡 Troubleshooting:"
echo "   • If services are unhealthy, run: docker-compose restart"
echo "   • Check logs: docker-compose logs -f [service-name]"
echo "   • Restart tunnel: cloudflared tunnel run elosofia"