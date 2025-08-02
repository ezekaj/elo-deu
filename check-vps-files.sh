#\!/bin/bash
# Run this on your VPS to check files

echo "Checking for test files in container..."
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)
echo "Container: $APP_CONTAINER"
echo ""
echo "Files in /app/public/:"
docker exec $APP_CONTAINER ls -la /app/public/ | grep -E "test-livekit|config.js"
