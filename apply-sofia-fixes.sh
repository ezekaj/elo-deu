#!/bin/bash
# Quick fix script for Sofia Dental AI

set -e

echo "🔧 Applying Sofia Dental AI fixes..."

# Backup current configs
echo "📦 Backing up current configuration..."
cp livekit.yaml livekit.yaml.$(date +%Y%m%d_%H%M%S).backup || true
cp docker-compose.yml docker-compose.yml.$(date +%Y%m%d_%H%M%S).backup || true

# Stop current services
echo "🛑 Stopping current services..."
docker-compose down || true

# Apply the fixed docker-compose
echo "📝 Applying fixed docker-compose configuration..."
cp docker-compose-fixed.yml docker-compose.yml

# Start services with the new configuration
echo "🔄 Starting services with TCP-only configuration..."
docker-compose up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 20

# Check health of all services
echo "🏥 Checking service health..."
echo ""
echo "LiveKit Health:"
curl -s http://localhost:7880/health | jq . || echo "❌ LiveKit health check failed"
echo ""
echo "Sofia Agent Health:"
curl -s http://localhost:8080/health | jq . || echo "❌ Agent health check failed"
echo ""
echo "Calendar Health:"
curl -s http://localhost:3005/health | jq . || echo "❌ Calendar health check failed"
echo ""

# Check docker containers
echo "📋 Container Status:"
docker-compose ps

echo ""
echo "✅ Sofia Dental AI fixes applied!"
echo ""
echo "🎯 Next steps:"
echo "1. Test the frontend connection at http://localhost:3005"
echo "2. Check logs with: docker-compose logs -f"
echo "3. If issues persist, check the TURN server: docker-compose logs turn-server"
echo ""
echo "🔍 Debug commands:"
echo "- View all logs: docker-compose logs -f"
echo "- Test network: docker exec elo-deu-sofia-agent-1 ping -c 1 livekit"
echo "- Test token generation: curl -X POST http://localhost:3005/api/livekit-token -H 'Content-Type: application/json' -d '{\"identity\":\"test\",\"room\":\"test\"}'"