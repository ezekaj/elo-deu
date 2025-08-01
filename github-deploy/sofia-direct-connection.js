/**
 * Sofia Direct Connection - Uses LiveKit Cloud or Direct Connection
 * This bypasses the WebSocket proxy issue entirely
 */

class SofiaDirectConnection {
    constructor() {
        this.room = null;
        this.audioTrack = null;
        this.isConnecting = false;
    }

    async connect() {
        try {
            console.log('🎤 Starting Sofia Direct Connection...');
            
            // Check for LiveKit SDK
            const LK = window.LivekitClient || window.LiveKit;
            if (!LK) {
                throw new Error('LiveKit SDK not loaded');
            }

            // Get connection details from server
            const response = await fetch(`${window.SOFIA_CONFIG.API_BASE_URL}/api/sofia/connect`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'ngrok-skip-browser-warning': 'true'
                },
                body: JSON.stringify({
                    participantName: 'Calendar User ' + Date.now(),
                    roomName: 'sofia-dental-' + Date.now()
                })
            });

            if (!response.ok) {
                throw new Error('Failed to get connection token');
            }

            const { token, url, roomName } = await response.json();
            console.log('📡 Connection details received:', { roomName, url });

            // Create room with proper configuration
            this.room = new LK.Room({
                adaptiveStream: true,
                dynacast: true,
                stopLocalTrackOnUnpublish: true,
                disconnectOnPageLeave: true,
                // Configure ICE servers for better connectivity
                rtcConfig: {
                    iceServers: [
                        // Default STUN servers
                        { urls: ['stun:stun.l.google.com:19302'] },
                        { urls: ['stun:stun1.l.google.com:19302'] },
                        // Your TURN server
                        {
                            urls: [
                                'turn:46.5.138.40:3478',
                                'turn:46.5.138.40:3478?transport=tcp'
                            ],
                            username: 'user',
                            credential: 'pass'
                        }
                    ],
                    iceTransportPolicy: 'all', // Use both STUN and TURN
                    iceCandidatePoolSize: 10
                }
            });

            // Set up event handlers
            this.setupEventHandlers();

            // For external connections, we'll use a different approach
            // Instead of the proxy, we'll connect directly to LiveKit on port 7880
            let connectUrl = url;
            
            // If we're external and getting a proxy URL, try direct connection instead
            if (url.includes('/livekit-proxy')) {
                // Extract the host and use direct port
                const host = new URL(window.location.href).hostname;
                if (host !== 'localhost' && host !== '127.0.0.1') {
                    // For external access, use the direct LiveKit port
                    connectUrl = `wss://${host}:7880`;
                    console.log('🔄 Using direct LiveKit connection:', connectUrl);
                }
            }

            console.log('🔗 Connecting to:', connectUrl);
            
            // Connect to room
            await this.room.connect(connectUrl, token);
            
            console.log('✅ Connected to LiveKit room');
            
            // Set up audio
            await this.setupAudio();
            
            return true;
            
        } catch (error) {
            console.error('❌ Connection error:', error);
            
            // If direct connection fails, show instructions
            if (error.message.includes('Failed to connect')) {
                this.showConnectionHelp();
            }
            
            throw error;
        }
    }

    setupEventHandlers() {
        this.room.on('connected', () => {
            console.log('✅ Room connected');
            this.updateUI('connected');
        });

        this.room.on('disconnected', (reason) => {
            console.log('🔴 Room disconnected:', reason);
            this.updateUI('disconnected');
        });

        this.room.on('participantConnected', (participant) => {
            console.log('👤 Participant connected:', participant.identity);
            if (participant.identity.includes('sofia') || participant.identity.includes('agent')) {
                console.log('🤖 Sofia agent joined!');
                this.updateUI('sofia-connected');
            }
        });

        this.room.on('trackSubscribed', (track, publication, participant) => {
            console.log('🎵 Track subscribed:', track.kind);
            if (track.kind === 'audio' && participant.identity.includes('sofia')) {
                // Attach Sofia's audio to play it
                const audioElement = track.attach();
                audioElement.autoplay = true;
                document.body.appendChild(audioElement);
            }
        });

        this.room.on('dataReceived', (data, participant) => {
            console.log('📨 Data received:', data);
            // Handle transcriptions or other data
        });
    }

    async setupAudio() {
        try {
            // Request microphone permission
            const stream = await navigator.mediaDevices.getUserMedia({ 
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                } 
            });
            
            // Create audio track
            const LK = window.LivekitClient || window.LiveKit;
            this.audioTrack = new LK.LocalAudioTrack(stream.getAudioTracks()[0]);
            
            // Publish audio track
            await this.room.localParticipant.publishTrack(this.audioTrack);
            
            console.log('🎤 Microphone published');
            
        } catch (error) {
            console.error('❌ Audio setup error:', error);
            throw error;
        }
    }

    updateUI(status) {
        // Update UI based on connection status
        const event = new CustomEvent('sofia-status', { detail: { status } });
        window.dispatchEvent(event);
    }

    showConnectionHelp() {
        const helpMessage = `
        ⚠️ Verbindung fehlgeschlagen. Mögliche Lösungen:

        1. Firewall-Einstellungen prüfen:
           - Port 7880 (WebSocket) muss offen sein
           - Port 7881 (TCP) für Medienverkehr
           
        2. Alternative Verbindungsmethode:
           - Verwenden Sie einen TURN-Server
           - Oder nutzen Sie LiveKit Cloud
           
        3. Lokaler Test:
           - Öffnen Sie http://localhost:3005
           - Testen Sie die Verbindung lokal
        `;
        
        console.log(helpMessage);
        alert(helpMessage);
    }

    async disconnect() {
        if (this.audioTrack) {
            this.audioTrack.stop();
            await this.room?.localParticipant.unpublishTrack(this.audioTrack);
        }
        
        if (this.room) {
            await this.room.disconnect();
        }
        
        this.room = null;
        this.audioTrack = null;
        
        console.log('🔴 Disconnected from Sofia');
    }
}

// Make it globally available
window.SofiaDirectConnection = SofiaDirectConnection;

// Auto-initialize if on the calendar page
if (document.getElementById('sofiaAgentBtn')) {
    window.sofiaConnection = new SofiaDirectConnection();
    
    // Override the button click handler
    document.getElementById('sofiaAgentBtn').onclick = async function() {
        const btn = this;
        
        if (window.sofiaConnection.room?.state === 'connected') {
            await window.sofiaConnection.disconnect();
            btn.classList.remove('active');
            btn.innerHTML = '<span class="sofia-icon">🎧</span> Sofia Agent';
        } else {
            btn.disabled = true;
            btn.innerHTML = '<span class="sofia-icon">⏳</span> Verbinde...';
            
            try {
                await window.sofiaConnection.connect();
                btn.classList.add('active');
                btn.innerHTML = '<span class="sofia-icon">🔴</span> Verbunden';
            } catch (error) {
                btn.classList.remove('active');
                btn.innerHTML = '<span class="sofia-icon">🎧</span> Sofia Agent';
                alert('Verbindung fehlgeschlagen: ' + error.message);
            } finally {
                btn.disabled = false;
            }
        }
    };
}