#!/bin/bash
# Fresh deployment steps for elosofia.site
# Run these commands on your VPS

echo "=== STEP 1: Install Docker ==="
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

echo "=== STEP 2: Install Docker Compose ==="
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "=== STEP 3: Clone your repository ==="
cd /root
git clone https://github.com/ezekaj/elo-deu.git
cd elo-deu

echo "=== STEP 4: Create production docker-compose ==="
cat > docker-compose.production.yml << 'EOF'
version: '3.8'

services:
  # LiveKit for voice processing
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
    environment:
      - LIVEKIT_KEYS=devkey:secret
    command: --dev
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:7880/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Dental Calendar Application
  dental-calendar:
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - PORT=3005
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3005/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      - livekit
EOF

echo "=== STEP 5: Create simple Dockerfile for dental-calendar ==="
cat > dental-calendar/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production || npm install

# Copy app files
COPY . .

# Expose port
EXPOSE 3005

# Start the application
CMD ["node", "server.js"]
EOF

echo "=== STEP 6: Ensure server.js exists ==="
if [ ! -f dental-calendar/server.js ]; then
cat > dental-calendar/server.js << 'EOF'
const express = require('express');
const path = require('path');
const app = express();

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'dental-calendar' });
});

// API endpoints
app.get('/api/appointments', (req, res) => {
    res.json([]);
});

// Main route
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'production.html'));
});

const PORT = process.env.PORT || 3005;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Dental Calendar running on port ${PORT}`);
});
EOF
fi

echo "=== STEP 7: Ensure package.json exists ==="
if [ ! -f dental-calendar/package.json ]; then
cat > dental-calendar/package.json << 'EOF'
{
  "name": "dental-calendar",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF
fi

echo "=== STEP 8: Build and start containers ==="
docker-compose -f docker-compose.production.yml build
docker-compose -f docker-compose.production.yml up -d

echo "=== STEP 9: Check if everything is running ==="
sleep 5
docker ps
echo ""
echo "Testing endpoints:"
curl -I http://localhost:3005/health
curl -I http://localhost:7880/health

echo ""
echo "=== Docker deployment complete! ==="
echo "Services should be running on:"
echo "- Dental Calendar: http://localhost:3005"
echo "- LiveKit: http://localhost:7880"