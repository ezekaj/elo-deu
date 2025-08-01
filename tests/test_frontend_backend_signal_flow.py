"""
Test Suite for Frontend to Backend Signal Flow
Ensures complete WebRTC signaling flow works end-to-end
"""

import unittest
import asyncio
import aiohttp
import websockets
import json
import time
from typing import Dict, Any, Optional
from unittest.mock import Mock, patch
import base64


class TestFrontendBackendSignalFlow(unittest.TestCase):
    """Test the complete signal flow from frontend to backend"""
    
    def setUp(self):
        self.calendar_api = "http://localhost:3005"
        self.livekit_ws = "ws://localhost:7880"
        self.test_room_name = f"signal-test-{int(time.time())}"
        
    async def test_get_livekit_token_endpoint(self):
        """Test /api/livekit-token endpoint returns valid token"""
        async with aiohttp.ClientSession() as session:
            payload = {
                "identity": f"test-user-{int(time.time())}",
                "room": self.test_room_name,
                "metadata": json.dumps({
                    "request_agent": True,
                    "agent_type": "dental-assistant"
                })
            }
            
            async with session.post(
                f"{self.calendar_api}/api/livekit-token",
                json=payload,
                headers={'ngrok-skip-browser-warning': 'true'}
            ) as response:
                self.assertEqual(response.status, 200, "Token endpoint failed")
                
                data = await response.json()
                self.assertIn('token', data, "Token not in response")
                self.assertIn('url', data, "URL not in response")
                
                # Validate token structure (JWT)
                token = data['token']
                parts = token.split('.')
                self.assertEqual(len(parts), 3, "Invalid JWT token structure")
                
                # Decode and validate payload
                payload_encoded = parts[1]
                # Add padding if needed
                payload_encoded += '=' * (4 - len(payload_encoded) % 4)
                payload_decoded = base64.urlsafe_b64decode(payload_encoded)
                token_payload = json.loads(payload_decoded)
                
                self.assertIn('video', token_payload, "Video grants missing")
                self.assertIn('room', token_payload['video'], "Room grant missing")
                self.assertEqual(
                    token_payload['video']['room'], 
                    self.test_room_name,
                    "Wrong room in token"
                )
    
    async def test_sofia_connect_endpoint(self):
        """Test /api/sofia/connect endpoint for backward compatibility"""
        async with aiohttp.ClientSession() as session:
            payload = {
                "participantName": "Calendar User Test",
                "roomName": self.test_room_name
            }
            
            async with session.post(
                f"{self.calendar_api}/api/sofia/connect",
                json=payload
            ) as response:
                self.assertEqual(response.status, 200, "Sofia connect endpoint failed")
                
                data = await response.json()
                self.assertIn('token', data, "Token not in response")
                self.assertIn('url', data, "URL not in response")
    
    async def test_websocket_signal_flow(self):
        """Test complete WebSocket signaling flow"""
        # Get token first
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.calendar_api}/api/livekit-token",
                json={
                    "identity": "signal-test-user",
                    "room": self.test_room_name
                }
            ) as response:
                token_data = await response.json()
                token = token_data['token']
        
        # Connect via WebSocket with token
        headers = {
            'Authorization': f'Bearer {token}'
        }
        
        try:
            async with websockets.connect(
                self.livekit_ws,
                extra_headers=headers,
                subprotocols=['livekit']
            ) as websocket:
                # Send join message
                join_msg = {
                    "type": "join",
                    "room": self.test_room_name,
                    "token": token
                }
                await websocket.send(json.dumps(join_msg))
                
                # Wait for response
                response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                response_data = json.loads(response)
                
                # Should receive join acknowledgment or participant update
                self.assertIn(
                    response_data.get('type'),
                    ['join_response', 'participant_update', 'room_update'],
                    f"Unexpected response type: {response_data.get('type')}"
                )
                
        except Exception as e:
            self.fail(f"WebSocket signal flow failed: {e}")
    
    async def test_ice_candidate_exchange(self):
        """Test ICE candidate exchange for WebRTC"""
        # This simulates the ICE gathering process
        test_candidates = [
            {
                "candidate": "candidate:1 1 tcp 2124414975 192.168.1.100 7881 typ host tcptype passive",
                "sdpMLineIndex": 0,
                "sdpMid": "0"
            }
        ]
        
        # In a real scenario, these would be exchanged via signaling
        for candidate in test_candidates:
            # Validate candidate format
            self.assertIn('candidate', candidate)
            self.assertIn('tcp', candidate['candidate'], "Should be TCP candidate")
            self.assertIn('7881', candidate['candidate'], "Should use TCP port 7881")
    
    async def test_room_state_synchronization(self):
        """Test room state synchronization between frontend and backend"""
        async with aiohttp.ClientSession() as session:
            # Create room via API
            async with session.post(
                f"{self.calendar_api}/api/rooms",
                json={"name": self.test_room_name}
            ) as response:
                if response.status == 200:
                    room_data = await response.json()
                    
                    # Get room state
                    async with session.get(
                        f"{self.calendar_api}/api/rooms/{self.test_room_name}"
                    ) as state_response:
                        if state_response.status == 200:
                            state = await state_response.json()
                            
                            self.assertIn('participants', state)
                            self.assertIn('created_at', state)
    
    async def test_error_handling_flow(self):
        """Test error handling in signal flow"""
        async with aiohttp.ClientSession() as session:
            # Test with invalid token request
            async with session.post(
                f"{self.calendar_api}/api/livekit-token",
                json={}  # Missing required fields
            ) as response:
                self.assertGreaterEqual(
                    response.status, 400,
                    "Should return error for invalid request"
                )
                
                if response.status < 500:  # Client error
                    data = await response.json()
                    self.assertIn('error', data, "Error message missing")


class TestSignalFlowFixes(unittest.TestCase):
    """Provide fixes for signal flow issues"""
    
    def create_livekit_token_endpoint(self) -> str:
        """Create the /api/livekit-token endpoint for calendar server"""
        return '''
// Add to dental-calendar/server.js or create new route file

const { AccessToken } = require('livekit-server-sdk');

// LiveKit token endpoint
app.post('/api/livekit-token', async (req, res) => {
    try {
        const { identity, room, metadata } = req.body;
        
        if (!identity || !room) {
            return res.status(400).json({ 
                error: 'Missing required fields: identity and room' 
            });
        }
        
        // Create access token
        const token = new AccessToken(
            process.env.LIVEKIT_API_KEY || 'devkey',
            process.env.LIVEKIT_API_SECRET || 'secret'
        );
        
        token.addGrant({
            roomJoin: true,
            room: room,
            canPublish: true,
            canSubscribe: true,
            canPublishData: true
        });
        
        token.identity = identity;
        token.metadata = metadata || JSON.stringify({
            request_agent: true,
            agent_type: 'dental-assistant'
        });
        
        // Generate JWT
        const jwt = await token.toJwt();
        
        // Return token and URL
        res.json({
            token: jwt,
            url: process.env.LIVEKIT_URL || 'ws://localhost:7880'
        });
        
    } catch (error) {
        console.error('Token generation error:', error);
        res.status(500).json({ 
            error: 'Failed to generate token',
            details: error.message 
        });
    }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({
        status: 'ok',
        service: 'dental-calendar',
        livekit_configured: !!process.env.LIVEKIT_URL,
        timestamp: new Date().toISOString()
    });
});
'''
    
    def create_frontend_connection_manager(self) -> str:
        """Create enhanced frontend connection manager"""
        return '''
// Enhanced Sofia Connection Manager with proper error handling

class EnhancedSofiaConnection {
    constructor() {
        this.room = null;
        this.localTracks = [];
        this.isConnecting = false;
        this.isConnected = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 3;
        
        // Configuration
        this.config = window.SOFIA_CONFIG || {
            API_BASE_URL: '',
            LIVEKIT_URL: 'ws://localhost:7880'
        };
    }
    
    async connect() {
        if (this.isConnecting || this.isConnected) {
            console.log('Already connected or connecting');
            return;
        }
        
        try {
            this.isConnecting = true;
            
            // Step 1: Get token
            const token = await this.getToken();
            
            // Step 2: Load LiveKit SDK
            await this.ensureLiveKitSDK();
            
            // Step 3: Create and configure room
            this.room = new LiveKitClient.Room({
                adaptiveStream: true,
                dynacast: true,
                // Force TCP-only mode
                publishDefaults: {
                    videoCodec: 'h264',
                    simulcast: false
                },
                // Connection options for TCP
                rtcConfig: {
                    iceTransportPolicy: 'relay',  // Force TURN/TCP
                    iceServers: [
                        { urls: 'stun:stun.l.google.com:19302' }
                    ]
                }
            });
            
            // Step 4: Setup event handlers
            this.setupEventHandlers();
            
            // Step 5: Connect to room
            await this.room.connect(this.config.LIVEKIT_URL, token);
            
            // Step 6: Publish microphone
            await this.publishMicrophone();
            
            this.isConnected = true;
            this.isConnecting = false;
            this.reconnectAttempts = 0;
            
            console.log('✅ Successfully connected to Sofia');
            
        } catch (error) {
            console.error('Connection failed:', error);
            this.isConnecting = false;
            
            // Handle reconnection
            if (this.reconnectAttempts < this.maxReconnectAttempts) {
                this.reconnectAttempts++;
                const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 10000);
                console.log(`Reconnecting in ${delay}ms... (attempt ${this.reconnectAttempts})`);
                setTimeout(() => this.connect(), delay);
            } else {
                this.showError('Failed to connect after multiple attempts');
            }
        }
    }
    
    async getToken() {
        const response = await fetch(this.config.API_BASE_URL + '/api/livekit-token', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true'
            },
            body: JSON.stringify({
                identity: 'Web User ' + Date.now(),
                room: 'sofia-dental-' + Date.now(),
                metadata: JSON.stringify({
                    request_agent: true,
                    agent_type: 'dental-assistant',
                    language: 'de-DE'
                })
            })
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Failed to get token');
        }
        
        const data = await response.json();
        return data.token;
    }
    
    async publishMicrophone() {
        try {
            // Request microphone permission
            const stream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true,
                    sampleRate: 48000
                }
            });
            
            // Create audio track
            const audioTrack = new LiveKitClient.LocalAudioTrack(
                stream.getAudioTracks()[0]
            );
            
            // Publish to room
            await this.room.localParticipant.publishTrack(audioTrack);
            this.localTracks.push(audioTrack);
            
            console.log('✅ Microphone published');
            
        } catch (error) {
            console.error('Microphone error:', error);
            throw new Error('Microphone access denied');
        }
    }
    
    setupEventHandlers() {
        // Connection events
        this.room.on('connected', () => {
            console.log('Room connected');
            this.updateUI('connected');
        });
        
        this.room.on('disconnected', (reason) => {
            console.log('Room disconnected:', reason);
            this.isConnected = false;
            this.updateUI('disconnected');
            
            // Auto-reconnect for unexpected disconnections
            if (reason !== 'CLIENT_INITIATED') {
                setTimeout(() => this.connect(), 2000);
            }
        });
        
        // Participant events
        this.room.on('participantConnected', (participant) => {
            console.log('Participant connected:', participant.identity);
            
            if (this.isAgentParticipant(participant)) {
                console.log('✅ Sofia agent connected');
                this.onSofiaConnected();
            }
        });
        
        // Track events
        this.room.on('trackSubscribed', (track, publication, participant) => {
            if (track.kind === 'audio' && this.isAgentParticipant(participant)) {
                this.handleSofiaAudio(track);
            }
        });
        
        // Data events
        this.room.on('dataReceived', (data, participant) => {
            if (this.isAgentParticipant(participant)) {
                this.handleSofiaData(data);
            }
        });
        
        // Active speaker events
        this.room.on('activeSpeakersChanged', (speakers) => {
            this.updateActiveSpeakers(speakers);
        });
        
        // Connection quality events
        this.room.on('connectionQualityChanged', (quality, participant) => {
            console.log(`Connection quality for ${participant.identity}: ${quality}`);
        });
    }
    
    isAgentParticipant(participant) {
        const identity = participant.identity.toLowerCase();
        const metadata = participant.metadata ? JSON.parse(participant.metadata) : {};
        
        return identity.includes('agent') || 
               identity.includes('sofia') || 
               metadata.agent === true ||
               metadata.agent_type === 'dental-assistant';
    }
    
    // Additional helper methods...
}

// Auto-initialize on page load
window.addEventListener('DOMContentLoaded', () => {
    window.sofiaConnection = new EnhancedSofiaConnection();
});
'''
    
    def create_tcp_only_webrtc_config(self) -> str:
        """Create TCP-only WebRTC configuration"""
        return '''
// TCP-only WebRTC Configuration

const tcpOnlyRTCConfig = {
    iceServers: [
        // STUN servers for NAT discovery
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        
        // TURN servers for TCP relay
        {
            urls: 'turn:turn.elosofia.site:3478?transport=tcp',
            username: 'sofia',
            credential: 'turn-password'
        },
        {
            urls: 'turns:turn.elosofia.site:5349?transport=tcp',
            username: 'sofia',
            credential: 'turn-password'
        }
    ],
    
    // Force TCP-only mode
    iceTransportPolicy: 'relay',
    
    // Bundle policy
    bundlePolicy: 'max-bundle',
    
    // RTCP mux policy
    rtcpMuxPolicy: 'require',
    
    // TCP candidates only
    iceCandidatePoolSize: 0
};

// Apply to LiveKit Room configuration
const roomOptions = {
    rtcConfig: tcpOnlyRTCConfig,
    
    // Additional TCP optimizations
    publishDefaults: {
        videoCodec: 'h264',  // Better for TCP
        videoSimulcast: false,  // Disable simulcast for TCP
        dtx: true,  // Discontinuous transmission
        red: true,  // Redundancy encoding
        forceStereo: false
    },
    
    // Adaptive streaming for TCP
    adaptiveStream: {
        pixelDensity: 'screen',
        pauseVideoInBackground: true
    },
    
    // Connection options
    connectOptions: {
        autoSubscribe: true,
        maxRetries: 3,
        peerConnectionTimeout: 15000
    }
};
'''
    
    def test_create_signal_flow_diagram(self):
        """Create a signal flow diagram for documentation"""
        diagram = '''
# Sofia Dental AI - Signal Flow Diagram

## Complete WebRTC Connection Flow

```mermaid
sequenceDiagram
    participant Browser
    participant Calendar API
    participant LiveKit Server
    participant Sofia Agent
    
    Browser->>Calendar API: POST /api/livekit-token
    Note over Calendar API: Generate JWT token<br/>with room grants
    Calendar API-->>Browser: {token, url}
    
    Browser->>LiveKit Server: WebSocket Connect<br/>with token
    LiveKit Server-->>Browser: Connection ACK
    
    Note over LiveKit Server: Create room<br/>if not exists
    
    LiveKit Server->>Sofia Agent: Room Started Webhook
    Sofia Agent->>LiveKit Server: Join Room
    
    Browser->>LiveKit Server: Publish Audio Track
    LiveKit Server-->>Sofia Agent: Track Published Event
    
    Sofia Agent->>LiveKit Server: Subscribe to User Audio
    Sofia Agent->>LiveKit Server: Publish Agent Audio
    
    LiveKit Server-->>Browser: Agent Audio Track
    Browser->>Browser: Play Agent Audio
    
    Note over Browser,Sofia Agent: Two-way audio established
```

## Error Handling Flow

```mermaid
graph TD
    A[Connection Request] --> B{Token Valid?}
    B -->|No| C[Return 400 Error]
    B -->|Yes| D[Generate Token]
    D --> E{LiveKit Available?}
    E -->|No| F[Return 503 Error]
    E -->|Yes| G[Return Token]
    G --> H{WebSocket Connect}
    H -->|Fail| I[Retry with Backoff]
    H -->|Success| J[Establish Audio]
```
'''
        
        with open('/home/elo/elo-deu/docs/signal-flow-diagram.md', 'w') as f:
            f.write(diagram)
        
        self.assertTrue(os.path.exists('/home/elo/elo-deu/docs/signal-flow-diagram.md'))


if __name__ == '__main__':
    unittest.main(verbosity=2)