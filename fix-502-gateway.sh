#!/bin/bash
# Fix 502 Bad Gateway error

echo "=== Fixing 502 Bad Gateway ==="

# 1. Check what's running
echo "1. Current containers:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. Check app logs
echo ""
echo "2. App container logs:"
docker logs dental-app --tail 30 2>&1 || echo "No app container found"

# 3. Check if port 3005 is accessible
echo ""
echo "3. Testing port 3005:"
curl -v http://localhost:3005 2>&1 | grep -E "Connected|refused|Failed"

# 4. Restart the app with explicit command
echo ""
echo "4. Restarting app container..."
docker stop dental-app 2>/dev/null
docker rm dental-app 2>/dev/null

# Start app with explicit command
docker run -d \
  --name dental-app \
  -p 3005:3005 \
  -v $(pwd)/dental-calendar:/app \
  -v $(pwd)/dental-calendar/database:/app/database \
  -w /app \
  --link livekit:livekit \
  -e NODE_ENV=production \
  -e LIVEKIT_URL=ws://livekit:7880 \
  -e LIVEKIT_API_KEY=devkey \
  -e LIVEKIT_API_SECRET=secret \
  node:18-alpine \
  sh -c "npm install && npm start"

# 5. Wait and check logs
echo ""
echo "5. Waiting for app to start..."
sleep 10

echo ""
echo "App logs:"
docker logs dental-app --tail 20

# 6. Test again
echo ""
echo "6. Testing app on port 3005:"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3005 | grep -q "200\|302\|304"; then
    echo "✅ App is responding!"
else
    echo "❌ App still not responding"
    echo ""
    echo "Checking what's listening on port 3005:"
    netstat -tlnp | grep 3005 || lsof -i :3005 || echo "Nothing on port 3005"
fi

# 7. Check Nginx
echo ""
echo "7. Checking Nginx configuration:"
nginx -t

# 8. Alternative: Run app directly
echo ""
echo "8. If still not working, try running the app directly:"
echo ""
echo "cd /root/elo-deu/dental-calendar"
echo "npm install"
echo "npm start"
echo ""
echo "This will show you any errors preventing the app from starting."

# 9. Show current status
echo ""
echo "9. Current status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"