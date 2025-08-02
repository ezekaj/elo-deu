#!/bin/bash
# Sofia Agent Spawner - Run agent.py for each user

echo "=== Setting up Sofia Agent Spawner ==="

# 1. First, find where agent.py is located
echo "1. Looking for agent.py..."
find /root/elo-deu -name "agent.py" -type f 2>/dev/null | head -5

# 2. Create a Node.js endpoint that spawns agent.py
echo ""
echo "2. Creating agent spawner endpoint..."
cat > dental-calendar/sofia-agent-spawner.js << 'EOF'
// Sofia Agent Spawner - Add this to your server.js

const { spawn } = require('child_process');
const { AccessToken } = require('livekit-server-sdk');

// Keep track of active agent processes
const activeAgents = new Map();

// Sofia connect endpoint - spawns a new agent for each user
app.post('/api/sofia/connect', async (req, res) => {
  try {
    const { participantName } = req.body;
    const roomName = `sofia-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    
    console.log('Creating Sofia session:', { participantName, roomName });
    
    // Create token for user
    const userToken = new AccessToken('devkey', 'secret', {
      identity: participantName,
    });
    
    userToken.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true
    });
    
    // Return connection info immediately
    res.json({
      token: userToken.toJwt(),
      url: 'ws://livekit:7880',
      roomName: roomName
    });
    
    // Spawn agent.py asynchronously
    setTimeout(() => {
      console.log(`Spawning agent for room: ${roomName}`);
      
      // Adjust the path to where your agent.py is located
      const agentProcess = spawn('python', [
        '/root/elo-deu/agent.py',
        'connect',
        '--room', roomName,
        '--url', 'ws://livekit:7880',
        '--api-key', 'devkey',
        '--api-secret', 'secret'
      ], {
        cwd: '/root/elo-deu',
        env: { ...process.env, PYTHONUNBUFFERED: '1' }
      });
      
      agentProcess.stdout.on('data', (data) => {
        console.log(`Agent ${roomName}: ${data}`);
      });
      
      agentProcess.stderr.on('data', (data) => {
        console.error(`Agent ${roomName} error: ${data}`);
      });
      
      agentProcess.on('close', (code) => {
        console.log(`Agent ${roomName} exited with code ${code}`);
        activeAgents.delete(roomName);
      });
      
      // Store process reference
      activeAgents.set(roomName, agentProcess);
      
      // Auto-cleanup after 30 minutes
      setTimeout(() => {
        if (activeAgents.has(roomName)) {
          console.log(`Cleaning up agent ${roomName}`);
          agentProcess.kill();
          activeAgents.delete(roomName);
        }
      }, 30 * 60 * 1000);
      
    }, 1000); // Give user time to connect first
    
  } catch (error) {
    console.error('Sofia connection error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Cleanup endpoint
app.post('/api/sofia/disconnect', (req, res) => {
  const { roomName } = req.body;
  const agent = activeAgents.get(roomName);
  
  if (agent) {
    agent.kill();
    activeAgents.delete(roomName);
    console.log(`Disconnected agent for room: ${roomName}`);
  }
  
  res.json({ status: 'ok' });
});

// Cleanup on server shutdown
process.on('SIGTERM', () => {
  console.log('Cleaning up all agents...');
  activeAgents.forEach((agent, roomName) => {
    agent.kill();
  });
});
EOF

echo "✓ Created agent spawner code"

# 3. Create a test script to verify agent.py works
echo ""
echo "3. Creating agent test script..."
cat > test-agent-direct.sh << 'EOF'
#!/bin/bash
# Test agent.py directly

echo "Testing agent.py..."

# Find agent.py
AGENT_PATH=$(find /root/elo-deu -name "agent.py" -type f | head -1)

if [ -z "$AGENT_PATH" ]; then
    echo "❌ agent.py not found!"
    echo "Please ensure agent.py is in the project"
    exit 1
fi

echo "Found agent.py at: $AGENT_PATH"
echo ""

# Check if it has required dependencies
echo "Checking Python dependencies..."
cd $(dirname $AGENT_PATH)
python -c "import livekit" 2>/dev/null || echo "⚠️  livekit module not found"
python -c "import asyncio" 2>/dev/null || echo "⚠️  asyncio module not found"

echo ""
echo "Testing agent.py help..."
python $AGENT_PATH --help || echo "Failed to run agent.py"

echo ""
echo "To test manually, run:"
echo "python $AGENT_PATH connect --room test-room --url ws://localhost:7880"
EOF

chmod +x test-agent-direct.sh

# 4. Create updated client code
echo ""
echo "4. Creating updated Sofia client..."
cat > dental-calendar/public/sofia-multi-user.js << 'EOF'
// Sofia Multi-User Voice Client
(function() {
    console.log('Sofia Multi-User - Initializing...');
    
    let room = null;
    let currentRoomName = null;
    
    async function startSofiaVoice() {
        if (room) {
            console.log('Already connected');
            return;
        }
        
        updateStatus('Verbinde mit Sofia...');
        
        try {
            // Get connection token - this will spawn an agent
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'User-' + Date.now()
                })
            });
            
            const data = await response.json();
            currentRoomName = data.roomName;
            console.log('Got room:', currentRoomName);
            
            // Map URL for client
            let connectUrl = data.url;
            if (window.location.protocol === 'https:') {
                connectUrl = 'wss://elosofia.site/ws';
            }
            
            // Create and connect to room
            room = new LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true
            });
            
            room.on('connected', async () => {
                console.log('Connected to room:', room.name);
                updateStatus('Verbunden! Aktiviere Mikrofon...');
                
                // Enable microphone
                await room.localParticipant.setMicrophoneEnabled(true);
                updateStatus('Sofia hört zu...');
            });
            
            room.on('participantConnected', (participant) => {
                console.log('Participant joined:', participant.identity);
                if (participant.identity.includes('Agent')) {
                    updateStatus('Sofia ist bereit!');
                }
            });
            
            room.on('disconnected', () => {
                updateStatus('Verbindung getrennt');
                cleanup();
            });
            
            await room.connect(connectUrl, data.token);
            
        } catch (error) {
            console.error('Error:', error);
            updateStatus('Fehler: ' + error.message);
            cleanup();
        }
    }
    
    async function stopSofiaVoice() {
        updateStatus('Trenne Verbindung...');
        
        // Notify server to kill agent
        if (currentRoomName) {
            fetch('/api/sofia/disconnect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ roomName: currentRoomName })
            });
        }
        
        cleanup();
    }
    
    function cleanup() {
        if (room) {
            room.disconnect();
            room = null;
        }
        currentRoomName = null;
        updateStatus('Bereit');
    }
    
    function updateStatus(msg) {
        console.log('Status:', msg);
        const statusEl = document.querySelector('.sofia-status');
        if (statusEl) statusEl.textContent = msg;
    }
    
    // Initialize button
    window.addEventListener('DOMContentLoaded', () => {
        const btn = document.querySelector('.sofia-agent-btn');
        if (btn) {
            btn.addEventListener('click', () => {
                if (room) {
                    stopSofiaVoice();
                } else {
                    startSofiaVoice();
                }
            });
        }
    });
})();
EOF

echo "✓ Created multi-user client"

# 5. Create deployment script
echo ""
echo "5. Creating deployment script..."
cat > deploy-sofia-spawner.sh << 'EOF'
#!/bin/bash
# Deploy Sofia agent spawner

echo "Deploying Sofia agent spawner..."

# 1. Install Python dependencies if needed
echo "Installing Python dependencies..."
pip install livekit livekit-agents python-dotenv 2>/dev/null || true

# 2. Copy client file to container
APP_CONTAINER=$(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)
docker cp dental-calendar/public/sofia-multi-user.js $APP_CONTAINER:/app/public/

# 3. Update production.html
docker exec $APP_CONTAINER sh -c "
if ! grep -q 'sofia-multi-user.js' /app/public/production.html; then
    sed -i '/<\\/body>/i \\    <script src=\"sofia-multi-user.js\"></script>' /app/public/production.html
fi
"

# 4. Note about server update
echo ""
echo "⚠️  IMPORTANT: You need to manually update your server.js with the code from:"
echo "   dental-calendar/sofia-agent-spawner.js"
echo ""
echo "This will enable spawning a new agent.py process for each user."

# 5. Test agent
./test-agent-direct.sh

echo ""
echo "✓ Deployment complete!"
EOF

chmod +x deploy-sofia-spawner.sh

echo ""
echo "=== Sofia Agent Spawner Ready ==="
echo ""
echo "This solution:"
echo "- Spawns a new agent.py process for each user"
echo "- Each user gets their own private room with Sofia"
echo "- Agents are automatically cleaned up after 30 minutes"
echo "- Supports multiple concurrent users"
echo ""
echo "To deploy: ./deploy-sofia-spawner.sh"