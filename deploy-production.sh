#!/bin/bash
# Production deployment script - just works!

echo "🚀 Sofia Production Deployment"
echo "============================="

# Stop and remove old containers
docker-compose down

# Set VPS IP
export VPS_IP=$1
if [ -z "$VPS_IP" ]; then
    VPS_IP=$(curl -s https://ipinfo.io/ip)
    echo "Detected IP: $VPS_IP"
fi

# Use production compose file
docker-compose -f docker-compose.production.yml up -d --build

# Show status
echo ""
echo "✅ Deployment complete!"
echo ""
echo "Access points:"
echo "  📅 Calendar: http://$VPS_IP:3005/production.html"
echo "  🏥 Health: http://$VPS_IP:8080/health"
echo "  📊 CRM: http://$VPS_IP:5000"
echo ""
echo "Sofia voice will work immediately - no configuration needed!"