#!/bin/bash
# Fix LiveKit token validation issue

echo "=== Fixing LiveKit Token Validation ==="

# 1. Check current LiveKit mode
echo "1. Checking LiveKit container mode:"
ssh root@167.235.67.1 "docker logs \$(docker ps --format '{{.Names}}' | grep livekit) 2>&1 | tail -20 | grep -E 'dev mode|API key|started'"

# 2. Update app to use dev mode tokens properly
echo ""
echo "2. Creating updated server configuration:"
cat > fix-server-config.js << 'EOF'
// Update the Sofia connect endpoint to use dev mode properly
const express = require('express');
const { AccessToken } = require('livekit-server-sdk');

// In dev mode, LiveKit expects these exact values
const LIVEKIT_API_KEY = 'devkey';
const LIVEKIT_API_SECRET = 'secret';
const LIVEKIT_URL = process.env.LIVEKIT_URL || 'ws://livekit:7880';

app.post('/api/sofia/connect', async (req, res) => {
    try {
        const { participantName, roomName } = req.body;
        
        console.log('Creating token for:', { participantName, roomName });
        console.log('Using LiveKit URL:', LIVEKIT_URL);
        
        // Create token with dev credentials
        const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
            identity: participantName,
        });
        
        token.addGrant({
            roomJoin: true,
            room: roomName,
            canPublish: true,
            canSubscribe: true,
            canPublishData: true
        });
        
        const jwt = token.toJwt();
        console.log('Token created successfully');
        
        res.json({
            token: jwt,
            url: LIVEKIT_URL,
            roomName: roomName
        });
    } catch (error) {
        console.error('Token creation error:', error);
        res.status(500).json({ error: error.message });
    }
});
EOF

echo ""
echo "3. Creating deployment script for VPS:"
cat > deploy-token-fix.sh << 'DEPLOY_SCRIPT'
#!/bin/bash
# Run this on the VPS

echo "Deploying token fix..."

# 1. Update environment variables in docker-compose
cd /root/elo-deu
cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  livekit:
    environment:
      - LIVEKIT_KEYS=devkey:secret
    command: --dev --bind 0.0.0.0
    
  app:
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
EOF

# 2. Restart services
echo "Restarting services..."
docker-compose -f docker-compose.final.yml -f docker-compose.override.yml down
docker-compose -f docker-compose.final.yml -f docker-compose.override.yml up -d

# 3. Wait for services
echo "Waiting for services to start..."
sleep 10

# 4. Check logs
echo ""
echo "LiveKit logs:"
docker logs $(docker ps --format "{{.Names}}" | grep livekit) --tail 10

echo ""
echo "App logs:"
docker logs $(docker ps --format "{{.Names}}" | grep -E "app|dental") --tail 10

echo ""
echo "Fix deployed! Test at https://elosofia.site/test-livekit-secure.html"
DEPLOY_SCRIPT

chmod +x deploy-token-fix.sh

echo ""
echo "=== Instructions ==="
echo ""
echo "1. Copy and run this on your VPS:"
echo ""
echo "cd /root/elo-deu"
echo "cat > deploy-token-fix.sh << 'EOF'"
cat deploy-token-fix.sh
echo "EOF"
echo "chmod +x deploy-token-fix.sh"
echo "./deploy-token-fix.sh"
echo ""
echo "This will fix the token validation error by ensuring both the app and LiveKit use the same dev credentials."