#!/bin/bash

# Deploy web files for elosofia.site

echo "🚀 Deploying Sofia Dental Web Interface..."

# Ensure we're in the right directory
cd /home/elo/elo-deu

# Check if docs directory exists
if [ ! -d "docs" ]; then
    echo "❌ Error: docs directory not found!"
    exit 1
fi

# Verify configuration
echo "📋 Checking configuration..."
if [ -f "docs/config.js" ]; then
    echo "✅ config.js found"
    grep -E "(API_BASE_URL|LIVEKIT_URL|WS_URL)" docs/config.js | head -5
else
    echo "❌ config.js not found!"
    exit 1
fi

# Check if services are running
echo ""
echo "🔍 Checking services..."

# Check dental-calendar
if curl -s http://localhost:3005/health > /dev/null 2>&1; then
    echo "✅ Dental Calendar API is running on port 3005"
else
    echo "⚠️  Dental Calendar API is not responding on port 3005"
fi

# Check LiveKit
if curl -s http://localhost:7880/health > /dev/null 2>&1; then
    echo "✅ LiveKit is running on port 7880"
else
    echo "⚠️  LiveKit is not responding on port 7880"
fi

# Check CRM
if curl -s http://localhost:5000 > /dev/null 2>&1; then
    echo "✅ CRM Dashboard is running on port 5000"
else
    echo "⚠️  CRM Dashboard is not responding on port 5000"
fi

# Check Cloudflare tunnel
echo ""
echo "🌐 Checking Cloudflare tunnel..."
if pgrep -f "cloudflared" > /dev/null; then
    echo "✅ Cloudflare tunnel is running"
    echo "📍 Your site should be accessible at:"
    echo "   - https://elosofia.site (Calendar)"
    echo "   - https://crm.elosofia.site (CRM Dashboard)"
    echo "   - wss://ws.elosofia.site (WebSocket/LiveKit)"
else
    echo "⚠️  Cloudflare tunnel is not running"
    echo "   Run: cloudflared tunnel run elosofia"
fi

echo ""
echo "📁 Web files location: /home/elo/elo-deu/docs/"
echo ""
echo "🌟 Deployment complete!"
echo ""
echo "To access your site:"
echo "1. Locally: http://localhost:3005"
echo "2. Globally: https://elosofia.site"
echo ""
echo "Make sure all Docker services are running:"
echo "  cd /home/elo/elo-deu && docker-compose up -d"