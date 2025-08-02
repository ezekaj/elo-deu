#!/bin/bash
# Diagnose LiveKit issues

echo "=== Diagnosing LiveKit Issues ==="

# 1. Check Docker containers
echo "1. Docker containers status:"
docker ps -a | grep -E "livekit|app|dental"
echo ""

# 2. Check LiveKit logs in detail
echo "2. LiveKit container logs:"
LIVEKIT_CONTAINER=$(docker ps -a --format "{{.Names}}" | grep livekit | head -1)
if [ -n "$LIVEKIT_CONTAINER" ]; then
    echo "Container: $LIVEKIT_CONTAINER"
    docker logs $LIVEKIT_CONTAINER --tail 50 2>&1
else
    echo "❌ No LiveKit container found!"
fi
echo ""

# 3. Check docker-compose files
echo "3. Active docker-compose configuration:"
ls -la docker-compose*.yml
echo ""

# 4. Restart LiveKit with explicit dev mode
echo "4. Restarting LiveKit in dev mode..."
cat > docker-compose.livekit-fix.yml << 'EOF'
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    container_name: livekit_server
    ports:
      - "7880:7880"
      - "7881:7881"
      - "7882:7882"
    environment:
      - LIVEKIT_KEYS=devkey:secret
    command: >
      --dev
      --bind 0.0.0.0
      --port 7880
      --rtc.port_range_start=50000
      --rtc.port_range_end=60000
    restart: unless-stopped
    networks:
      - app-network

  app:
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile.simple
    container_name: dental_app
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
    restart: unless-stopped
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
EOF

echo "✓ Created docker-compose.livekit-fix.yml"

# 5. Create restart script
echo ""
echo "5. Creating restart script..."
cat > restart-livekit.sh << 'EOF'
#!/bin/bash
# Restart with fixed configuration

echo "Stopping all containers..."
docker-compose -f docker-compose.final.yml down
docker-compose -f docker-compose.livekit-fix.yml down

echo "Starting with fixed configuration..."
docker-compose -f docker-compose.livekit-fix.yml up -d

echo "Waiting for services..."
sleep 10

echo ""
echo "Container status:"
docker ps | grep -E "livekit|dental"

echo ""
echo "LiveKit logs:"
docker logs livekit_server --tail 20

echo ""
echo "Testing LiveKit health:"
curl -s http://localhost:7880/healthz || echo "Health check failed"

echo ""
echo "Network test from app to LiveKit:"
docker exec dental_app ping -c 2 livekit || echo "Cannot ping LiveKit container"
docker exec dental_app wget -O- http://livekit:7880 2>&1 | head -5 || echo "Cannot reach LiveKit"
EOF

chmod +x restart-livekit.sh

# 6. Create a minimal test
echo ""
echo "6. Creating minimal connection test..."
cat > dental-calendar/public/minimal-test.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Minimal LiveKit Test</title>
</head>
<body>
    <h1>Minimal LiveKit Test</h1>
    <button onclick="checkPorts()">Check All Ports</button>
    <div id="log"></div>
    
    <script>
    function log(msg) {
        document.getElementById('log').innerHTML += msg + '<br>';
        console.log(msg);
    }
    
    async function checkPorts() {
        log('Checking LiveKit accessibility...');
        
        // Test different endpoints
        const tests = [
            { url: 'http://167.235.67.1:7880', desc: 'Direct HTTP to VPS:7880' },
            { url: 'https://elosofia.site/api/sofia/test', desc: 'API endpoint test' },
            { url: 'ws://167.235.67.1:7880', desc: 'Direct WebSocket' },
            { url: 'wss://elosofia.site/ws', desc: 'Proxied WebSocket' }
        ];
        
        for (const test of tests) {
            log('');
            log('Testing: ' + test.desc);
            
            if (test.url.startsWith('http')) {
                try {
                    const response = await fetch(test.url, { 
                        mode: 'no-cors',
                        cache: 'no-cache'
                    });
                    log('✓ Fetch completed (no-cors mode)');
                } catch (e) {
                    log('✗ Fetch failed: ' + e.message);
                }
            } else if (test.url.startsWith('ws')) {
                try {
                    const ws = new WebSocket(test.url);
                    ws.onopen = () => {
                        log('✓ WebSocket connected!');
                        ws.close();
                    };
                    ws.onerror = () => log('✗ WebSocket error');
                    ws.onclose = (e) => log('WebSocket closed: ' + e.code);
                } catch (e) {
                    log('✗ WebSocket failed: ' + e.message);
                }
            }
        }
        
        // Also check current origin
        log('');
        log('Current page origin: ' + window.location.origin);
        log('Protocol: ' + window.location.protocol);
    }
    </script>
</body>
</html>
EOF

echo "✓ Created minimal-test.html"

echo ""
echo "=== Diagnosis Complete ==="
echo ""
echo "To fix LiveKit:"
echo "1. Run: ./restart-livekit.sh"
echo "2. Test at: https://elosofia.site/minimal-test.html"
echo ""
echo "The restart script will:"
echo "- Use a fixed Docker configuration"
echo "- Ensure LiveKit starts in dev mode"
echo "- Set up proper networking between containers"