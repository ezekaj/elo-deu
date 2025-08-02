#!/bin/bash
# Fix LiveKit authentication directly

echo "=== Fixing LiveKit Authentication ==="

# 1. Create docker-compose override file
echo "1. Creating docker-compose override..."
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

echo "✓ Created docker-compose.override.yml"

# 2. Update the dental-calendar server to use correct credentials
echo ""
echo "2. Updating server configuration..."
cat > dental-calendar/sofia-token-fix.js << 'EOF'
// This file contains the fix for Sofia token generation
// Copy this logic to your server.js file

const LIVEKIT_API_KEY = 'devkey';
const LIVEKIT_API_SECRET = 'secret';

// In your /api/sofia/connect endpoint, ensure you use:
// const token = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
//     identity: participantName,
// });
EOF

echo "✓ Created token fix reference"

# 3. Create a patch for the server
echo ""
echo "3. Creating server patch..."
cat > patch-server.sh << 'EOF'
#!/bin/bash
# Patch the server to use correct dev credentials

echo "Patching server.js..."

# Find and update the LiveKit credentials in server.js
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)

# Create a patched version
docker exec $APP_CONTAINER sh -c "
sed -i \"s/const LIVEKIT_API_KEY = .*/const LIVEKIT_API_KEY = 'devkey';/g\" server.js
sed -i \"s/const LIVEKIT_API_SECRET = .*/const LIVEKIT_API_SECRET = 'secret';/g\" server.js
sed -i \"s/apiKey: .*/apiKey: 'devkey',/g\" server.js
sed -i \"s/apiSecret: .*/apiSecret: 'secret',/g\" server.js
"

echo "✓ Server patched"
EOF

chmod +x patch-server.sh

# 4. Create restart script
echo ""
echo "4. Creating restart script..."
cat > restart-with-fix.sh << 'EOF'
#!/bin/bash
# Restart services with the fix

echo "Stopping services..."
docker-compose -f docker-compose.final.yml down

echo "Starting with override..."
docker-compose -f docker-compose.final.yml -f docker-compose.override.yml up -d

echo "Waiting for services..."
sleep 10

echo "Patching server..."
./patch-server.sh

echo "Restarting app container..."
docker restart $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)

echo ""
echo "=== Services Restarted ==="
echo ""
echo "LiveKit status:"
docker logs $(docker ps --format "{{.Names}}" | grep livekit) --tail 5 2>&1 | grep -E "started|listening|ready"

echo ""
echo "App status:"
docker ps | grep -E "app|dental"

echo ""
echo "Test at: https://elosofia.site/test-livekit-secure.html"
EOF

chmod +x restart-with-fix.sh

echo ""
echo "=== Fix Created ==="
echo ""
echo "Files created:"
echo "✓ docker-compose.override.yml - Ensures consistent dev credentials"
echo "✓ patch-server.sh - Updates server to use devkey:secret"
echo "✓ restart-with-fix.sh - Restarts everything with the fix"
echo ""
echo "To apply the fix, run:"
echo "./restart-with-fix.sh"