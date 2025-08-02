#!/bin/bash
# Fix container restart loop

echo "=== Fixing Container Restart Loop ==="

# 1. Stop the problematic container
echo "1. Stopping restart loop..."
docker stop dental-app
docker rm dental-app

# 2. Check the Dockerfile
echo ""
echo "2. Checking Dockerfile.simple:"
cat dental-calendar/Dockerfile.simple 2>/dev/null || echo "Dockerfile.simple not found!"

# 3. Check if package.json exists
echo ""
echo "3. Checking package.json:"
ls -la dental-calendar/package.json

# 4. Check the start script
echo ""
echo "4. Checking start script in package.json:"
grep -A2 -B2 '"start"' dental-calendar/package.json

# 5. Run the app interactively to see the error
echo ""
echo "5. Running app interactively to see the error..."
echo "Press Ctrl+C when you see the error"
echo ""

docker run -it --rm \
  --name dental-app-debug \
  -p 3005:3005 \
  -v $(pwd)/dental-calendar:/app \
  -w /app \
  node:18-alpine \
  sh -c "ls -la && npm install && npm start"

# 6. If that failed, try a simpler approach
echo ""
echo "6. Creating a simple working setup..."
cat > dental-calendar/Dockerfile.working << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application files
COPY . .

# Ensure database directory exists
RUN mkdir -p /app/database

# Expose port
EXPOSE 3005

# Start command
CMD ["node", "server.js"]
EOF

echo "✓ Created Dockerfile.working"

# 7. Build and run with the working Dockerfile
echo ""
echo "7. Building with working Dockerfile..."
docker build -t dental-app-working -f dental-calendar/Dockerfile.working dental-calendar/

echo ""
echo "8. Running with working image..."
docker run -d \
  --name dental-app \
  -p 3005:3005 \
  -v $(pwd)/dental-calendar/database:/app/database \
  --link livekit:livekit \
  -e NODE_ENV=production \
  -e LIVEKIT_URL=ws://livekit:7880 \
  dental-app-working

# 8. Check if it's running
echo ""
echo "9. Checking status..."
sleep 5
docker ps | grep dental-app
echo ""
echo "Logs:"
docker logs dental-app --tail 20

echo ""
echo "=== Restart Loop Fix Complete ==="