#!/bin/bash
# Fix MODULE_NOT_FOUND error

echo "=== Fixing MODULE_NOT_FOUND Error ==="

# 1. Stop containers
echo "1. Stopping containers..."
docker stop dental-app 2>/dev/null
docker rm dental-app 2>/dev/null

# 2. Check what's in the dental-calendar directory
echo ""
echo "2. Checking dental-calendar directory:"
ls -la dental-calendar/

# 3. Check if package.json exists
echo ""
echo "3. Checking package.json:"
if [ -f dental-calendar/package.json ]; then
    echo "✓ package.json exists"
    echo "Dependencies:"
    grep -A10 '"dependencies"' dental-calendar/package.json
else
    echo "❌ package.json not found!"
fi

# 4. Check if node_modules exists
echo ""
echo "4. Checking node_modules:"
if [ -d dental-calendar/node_modules ]; then
    echo "✓ node_modules exists"
    ls -la dental-calendar/node_modules | head -10
else
    echo "❌ node_modules not found - need to install dependencies"
fi

# 5. Install dependencies properly
echo ""
echo "5. Installing dependencies..."
cd dental-calendar
npm install
cd ..

# 6. Create a proper Dockerfile that ensures dependencies
echo ""
echo "6. Creating proper Dockerfile..."
cat > dental-calendar/Dockerfile.fixed << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files first
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy all application files
COPY . .

# Ensure database directory exists
RUN mkdir -p /app/database

# Expose port
EXPOSE 3005

# Start the application
CMD ["node", "server.js"]
EOF

# 7. Build the image
echo ""
echo "7. Building Docker image..."
docker build -t dental-app:fixed -f dental-calendar/Dockerfile.fixed dental-calendar/

# 8. Run with the fixed image
echo ""
echo "8. Running with fixed image..."
docker run -d \
  --name dental-app \
  --network sofia-network \
  -p 3005:3005 \
  -v $(pwd)/dental-calendar/database:/app/database \
  -v $(pwd)/dental-calendar/public:/app/public \
  -e NODE_ENV=production \
  -e LIVEKIT_URL=ws://livekit:7880 \
  -e LIVEKIT_API_KEY=devkey \
  -e LIVEKIT_API_SECRET=secret \
  dental-app:fixed

# 9. Check logs
echo ""
echo "9. Waiting for app to start..."
sleep 5

echo ""
echo "App logs:"
docker logs dental-app --tail 20

# 10. Test the app
echo ""
echo "10. Testing app..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3005 | grep -q "200\|302"; then
    echo "✅ App is running!"
else
    echo "❌ App still not responding"
    echo ""
    echo "Full logs:"
    docker logs dental-app
fi

# 11. Update docker-compose
echo ""
echo "11. Updating docker-compose to use fixed image..."
cat > docker-compose.fixed.yml << 'EOF'
version: '3'

services:
  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit
    ports:
      - "7880:7880"
    command: --dev
    networks:
      - sofia-network
    restart: unless-stopped

  app:
    image: dental-app:fixed
    container_name: dental-app
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile.fixed
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
    depends_on:
      - livekit
    volumes:
      - ./dental-calendar/database:/app/database
      - ./dental-calendar/public:/app/public
    networks:
      - sofia-network
    restart: unless-stopped

networks:
  sofia-network:
    driver: bridge
EOF

echo ""
echo "=== Module Fix Complete ==="
echo ""
echo "To use the fixed setup:"
echo "docker-compose -f docker-compose.fixed.yml up -d"