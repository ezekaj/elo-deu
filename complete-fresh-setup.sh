#!/bin/bash
# Complete fresh setup - learning from all previous mistakes

echo "=== COMPLETE FRESH SETUP FOR SOFIA ==="
echo "This will set up everything correctly from scratch"
echo ""

# 1. Clean EVERYTHING
echo "Step 1: Cleaning everything..."
docker stop $(docker ps -aq) 2>/dev/null
docker rm $(docker ps -aq) 2>/dev/null
docker network prune -f
docker volume prune -f
docker system prune -f

# 2. Ensure we're in the right directory
cd /root/elo-deu

# 3. Create a simple, working Dockerfile
echo ""
echo "Step 2: Creating working Dockerfile..."
cat > dental-calendar/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Install dependencies first (for caching)
COPY package*.json ./
RUN npm install

# Copy application files
COPY . .

# Create necessary directories
RUN mkdir -p /app/database /app/public

# Expose port
EXPOSE 3005

# Start command
CMD ["node", "server.js"]
EOF

# 4. Create docker-compose.yml that WORKS
echo ""
echo "Step 3: Creating working docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  app:
    build:
      context: ./dental-calendar
      dockerfile: Dockerfile
    container_name: dental-app
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - PORT=3005
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=secret
    volumes:
      - ./dental-calendar/database:/app/database
      - ./dental-calendar/public:/app/public
    depends_on:
      - livekit
    networks:
      - sofia-net
    restart: unless-stopped

  livekit:
    image: livekit/livekit-server:v1.5.2
    container_name: livekit
    ports:
      - "7880:7880"
    command: --dev --bind 0.0.0.0
    environment:
      - LIVEKIT_KEYS=devkey:secret
    networks:
      - sofia-net
    restart: unless-stopped

networks:
  sofia-net:
    driver: bridge
EOF

# 5. Create the Sofia client that works
echo ""
echo "Step 4: Creating Sofia client..."
cat > dental-calendar/public/sofia.js << 'EOF'
// Sofia Voice Client - Clean Implementation
console.log('Sofia Client Loading...');

(function() {
    let room = null;
    let isConnecting = false;
    
    function updateStatus(msg) {
        console.log('Sofia:', msg);
        const el = document.querySelector('.sofia-status');
        if (el) el.textContent = msg;
    }
    
    async function loadLiveKit() {
        if (window.LivekitClient) return true;
        
        return new Promise((resolve) => {
            const script = document.createElement('script');
            script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
            script.onload = () => resolve(true);
            script.onerror = () => resolve(false);
            document.head.appendChild(script);
        });
    }
    
    async function connect() {
        if (isConnecting || room) return;
        
        try {
            isConnecting = true;
            updateStatus('Lade LiveKit SDK...');
            
            // Load SDK
            const sdkLoaded = await loadLiveKit();
            if (!sdkLoaded) {
                throw new Error('SDK konnte nicht geladen werden');
            }
            
            updateStatus('Verbinde mit Server...');
            
            // Get token
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'User-' + Date.now()
                })
            });
            
            if (!response.ok) {
                throw new Error('Server error: ' + response.status);
            }
            
            const data = await response.json();
            console.log('Got token for room:', data.roomName);
            
            // Create room
            updateStatus('Erstelle Verbindung...');
            room = new LivekitClient.Room();
            
            room.on('connected', async () => {
                console.log('Connected!');
                updateStatus('Aktiviere Mikrofon...');
                try {
                    await room.localParticipant.setMicrophoneEnabled(true);
                    updateStatus('Sofia hört zu...');
                } catch (e) {
                    updateStatus('Mikrofon-Fehler');
                }
            });
            
            room.on('disconnected', () => {
                console.log('Disconnected');
                cleanup();
            });
            
            // Connect - use secure WebSocket if on HTTPS
            const url = window.location.protocol === 'https:' 
                ? 'wss://' + window.location.host + '/ws'
                : data.url;
                
            console.log('Connecting to:', url);
            await room.connect(url, data.token);
            
        } catch (error) {
            console.error('Connection error:', error);
            updateStatus('Fehler: ' + error.message);
            cleanup();
        }
    }
    
    function disconnect() {
        updateStatus('Trenne Verbindung...');
        cleanup();
    }
    
    function cleanup() {
        if (room) {
            room.disconnect();
            room = null;
        }
        isConnecting = false;
        updateStatus('Bereit');
    }
    
    // Wait for DOM
    document.addEventListener('DOMContentLoaded', () => {
        console.log('Initializing Sofia button...');
        const btn = document.querySelector('.sofia-agent-btn');
        if (btn) {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                if (room) disconnect();
                else connect();
            });
            updateStatus('Bereit');
        }
    });
    
    // Export for debugging
    window.Sofia = { connect, disconnect, getRoom: () => room };
})();
EOF

# 6. Update Nginx configuration
echo ""
echo "Step 5: Updating Nginx configuration..."
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

    # Main app
    location / {
        proxy_pass http://127.0.0.1:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket for LiveKit
    location /ws {
        proxy_pass http://127.0.0.1:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
EOF

# 7. Test and reload Nginx
nginx -t && systemctl reload nginx

# 8. Build and start everything
echo ""
echo "Step 6: Building and starting services..."
docker-compose build
docker-compose up -d

# 9. Wait for services
echo ""
echo "Step 7: Waiting for services to start..."
sleep 10

# 10. Check status
echo ""
echo "Step 8: Checking status..."
docker ps

# 11. Test services
echo ""
echo "Step 9: Testing services..."
echo -n "App: "
curl -s -o /dev/null -w "%{http_code}" http://localhost:3005
echo ""
echo -n "LiveKit: "
curl -s -o /dev/null -w "%{http_code}" http://localhost:7880
echo ""

# 12. Update production.html
echo ""
echo "Step 10: Updating production.html..."
docker exec dental-app sh -c "
sed -i '/sofia-voice/d' /app/public/production.html
sed -i '/sofia-multi/d' /app/public/production.html
sed -i '/sofia-working/d' /app/public/production.html
if ! grep -q 'sofia.js' /app/public/production.html; then
    sed -i '/<\\/body>/i \\    <script src=\"sofia.js\"></script>' /app/public/production.html
fi
"

# 13. Final check
echo ""
echo "Step 11: Final verification..."
sleep 5
if curl -s -o /dev/null -w "%{http_code}" https://elosofia.site | grep -q "200\|304"; then
    echo "✅ Website is accessible!"
else
    echo "❌ Website not accessible - checking logs..."
    docker logs dental-app --tail 20
fi

echo ""
echo "============================================"
echo "SETUP COMPLETE!"
echo ""
echo "Services running:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "To access Sofia:"
echo "1. Go to https://elosofia.site"
echo "2. Click the Sofia button"
echo "3. Allow microphone access"
echo ""
echo "To debug in browser console:"
echo "Sofia.connect()"
echo "============================================"