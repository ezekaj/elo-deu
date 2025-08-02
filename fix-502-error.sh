#!/bin/bash
# Fix 502 Bad Gateway error

echo "=== Fixing 502 Bad Gateway Error ==="

# 1. Check what's running
echo "1. Current Docker containers:"
docker ps -a
echo ""

# 2. Check logs if app crashed
echo "2. Checking app logs:"
docker logs $(docker ps -aq | head -1) --tail 20 2>&1 || echo "No logs available"
echo ""

# 3. Restart all containers
echo "3. Restarting all containers..."
cd /root/elo-deu
docker-compose -f docker-compose.final.yml down
docker-compose -f docker-compose.final.yml up -d
echo ""

# 4. Wait for services to start
echo "4. Waiting for services to start..."
sleep 10

# 5. Check if services are running
echo "5. Services status:"
docker ps
echo ""

# 6. Test if app is responding
echo "6. Testing app on port 3005:"
curl -I http://localhost:3005/health || echo "App not responding"
echo ""

# 7. Check Nginx status
echo "7. Nginx status:"
systemctl status nginx --no-pager | head -10
echo ""

# 8. Test Nginx configuration
echo "8. Testing Nginx config:"
nginx -t
echo ""

# 9. Restart Nginx just in case
echo "9. Restarting Nginx..."
systemctl restart nginx

echo ""
echo "=== Fix Complete ==="
echo "Check if https://elosofia.site is working now"