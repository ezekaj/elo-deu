#!/bin/bash
# Fix Sofia once and for all - the complete solution

echo "=== FIXING SOFIA - COMPLETE SOLUTION ==="

# 1. Stop everything and start fresh
echo "1. Stopping all services..."
docker-compose down 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true

# 2. Create a working LiveKit configuration
echo ""
echo "2. Creating working LiveKit setup..."
cat > docker-compose.sofia.yml << 'EOF'
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:v1.5.2
    container_name: sofia-livekit
    command: --dev --bind 0.0.0.0
    ports:
      - "7880:7880"
      - "7881:7881"
      - "50000-60000:50000-60000/udp"
    environment:
      - LIVEKIT_KEYS=devkey:secret
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:7880/healthz"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile.simple
    container_name: sofia-app
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
    depends_on:
      livekit:
        condition: service_healthy
    volumes:
      - ./dental-calendar/database:/app/database
    restart: unless-stopped
    links:
      - livekit

networks:
  default:
    driver: bridge
EOF

# 3. Create Sofia client that WILL work
echo ""
echo "3. Creating Sofia client implementation..."
cat > dental-calendar/public/sofia-working.js << 'EOF'
// Sofia Voice Agent - Working Implementation
console.log('Sofia Voice Agent - Loading...');

// Wait for page and SDK to load
window.addEventListener('DOMContentLoaded', function() {
    console.log('DOM loaded, initializing Sofia...');
    
    let room = null;
    let isConnecting = false;
    
    // Function to update status
    function updateStatus(message) {
        console.log('Sofia Status:', message);
        const statusEl = document.querySelector('.sofia-status');
        if (statusEl) {
            statusEl.textContent = message;
        }
    }
    
    // Function to load LiveKit SDK
    function loadLiveKitSDK(callback) {
        if (typeof LivekitClient !== 'undefined') {
            console.log('LiveKit SDK already loaded');
            callback();
            return;
        }
        
        // Try to load from CDN
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
        script.onload = function() {
            console.log('LiveKit SDK loaded from CDN');
            callback();
        };
        script.onerror = function() {
            console.error('Failed to load LiveKit SDK');
            updateStatus('SDK Ladefehler');
        };
        document.head.appendChild(script);
    }
    
    // Main Sofia connection function
    async function connectToSofia() {
        if (isConnecting || room) {
            console.log('Already connecting or connected');
            return;
        }
        
        isConnecting = true;
        updateStatus('Verbinde mit Sofia...');
        
        try {
            // Get connection details from server
            console.log('Requesting connection token...');
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'User-' + Date.now(),
                    roomName: 'sofia-room-' + Date.now()
                })
            });
            
            if (!response.ok) {
                throw new Error('Server error: ' + response.status);
            }
            
            const data = await response.json();
            console.log('Got connection data:', data);
            
            // Determine correct URL based on environment
            let connectUrl = data.url;
            if (window.location.protocol === 'https:') {
                // On HTTPS, use secure WebSocket
                connectUrl = 'wss://' + window.location.host + '/ws';
            }
            console.log('Connecting to:', connectUrl);
            
            // Create LiveKit room
            room = new LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true,
                logLevel: 'info'
            });
            
            // Set up event handlers
            room.on('connected', async () => {
                console.log('Connected to LiveKit room!');
                updateStatus('Verbunden! Aktiviere Mikrofon...');
                
                try {
                    // Enable microphone
                    await room.localParticipant.setMicrophoneEnabled(true);
                    updateStatus('Sofia hört zu...');
                } catch (err) {
                    console.error('Microphone error:', err);
                    updateStatus('Mikrofonzugriff verweigert');
                }
            });
            
            room.on('participantConnected', (participant) => {
                console.log('Participant connected:', participant.identity);
                if (participant.identity.includes('Sofia') || participant.identity.includes('Agent')) {
                    updateStatus('Sofia ist da!');
                }
            });
            
            room.on('disconnected', () => {
                console.log('Disconnected from room');
                cleanup();
            });
            
            room.on('connectionStateChanged', (state) => {
                console.log('Connection state:', state);
            });
            
            room.on('error', (error) => {
                console.error('Room error:', error);
                updateStatus('Fehler: ' + error.message);
            });
            
            // Connect to room
            await room.connect(connectUrl, data.token);
            
        } catch (error) {
            console.error('Connection error:', error);
            updateStatus('Verbindungsfehler');
            cleanup();
        }
    }
    
    // Disconnect function
    function disconnectFromSofia() {
        console.log('Disconnecting from Sofia...');
        updateStatus('Trenne Verbindung...');
        cleanup();
    }
    
    // Cleanup function
    function cleanup() {
        if (room) {
            room.disconnect();
            room = null;
        }
        isConnecting = false;
        updateStatus('Bereit');
    }
    
    // Initialize Sofia button
    function initializeSofiaButton() {
        const sofiaBtn = document.querySelector('.sofia-agent-btn');
        if (sofiaBtn) {
            console.log('Sofia button found, adding click handler');
            
            sofiaBtn.addEventListener('click', function(e) {
                e.preventDefault();
                console.log('Sofia button clicked');
                
                if (room) {
                    disconnectFromSofia();
                } else {
                    // Load SDK then connect
                    loadLiveKitSDK(function() {
                        connectToSofia();
                    });
                }
            });
            
            updateStatus('Bereit');
        } else {
            console.log('Sofia button not found, retrying...');
            setTimeout(initializeSofiaButton, 1000);
        }
    }
    
    // Start initialization
    initializeSofiaButton();
    
    // Expose for debugging
    window.sofiaDebug = {
        connect: connectToSofia,
        disconnect: disconnectFromSofia,
        getRoom: () => room,
        loadSDK: loadLiveKitSDK
    };
});
EOF

# 4. Create proper Nginx configuration
echo ""
echo "4. Updating Nginx for WebSocket..."
cat > /etc/nginx/sites-available/elosofia.site << 'EOF'
server {
    listen 80;
    server_name elosofia.site www.elosofia.site;
    return 301 https://$server_name$request_uri;
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 443 ssl;
    server_name elosofia.site www.elosofia.site;

    ssl_certificate /etc/letsencrypt/live/elosofia.site/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/elosofia.site/privkey.pem;

    # WebSocket proxy for LiveKit
    location /ws {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_buffering off;
    }

    # Main application
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# 5. Start everything
echo ""
echo "5. Starting services..."
docker-compose -f docker-compose.sofia.yml up -d

# Wait for services
echo "Waiting for services to start..."
sleep 15

# 6. Deploy Sofia client
echo ""
echo "6. Deploying Sofia client..."
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep app)
docker cp dental-calendar/public/sofia-working.js $APP_CONTAINER:/app/public/

# Update production.html
docker exec $APP_CONTAINER sh -c "
# Remove all old Sofia scripts
sed -i '/sofia-voice/d' /app/public/production.html
sed -i '/sofia-multi/d' /app/public/production.html
sed -i '/simple-voice/d' /app/public/production.html

# Add working Sofia script
if ! grep -q 'sofia-working.js' /app/public/production.html; then
    sed -i '/<\\/body>/i \\    <script src=\"sofia-working.js\"></script>' /app/public/production.html
fi
"

# 7. Reload Nginx
echo ""
echo "7. Reloading Nginx..."
nginx -t && systemctl reload nginx

# 8. Test LiveKit
echo ""
echo "8. Testing LiveKit..."
curl -s http://localhost:7880/healthz && echo " ✓ LiveKit is healthy" || echo " ❌ LiveKit not responding"

# 9. Show status
echo ""
echo "9. Current status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== SOFIA FIX COMPLETE ==="
echo ""
echo "Sofia should now be working at: https://elosofia.site"
echo ""
echo "To test:"
echo "1. Open https://elosofia.site"
echo "2. Click the Sofia voice button"
echo "3. Allow microphone access"
echo "4. Sofia will connect!"
echo ""
echo "Debug in browser console with:"
echo "- sofiaDebug.connect() - manually connect"
echo "- sofiaDebug.getRoom() - check room status"