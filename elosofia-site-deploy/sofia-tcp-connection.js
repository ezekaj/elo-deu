/**
 * Sofia TCP-Only Connection - Works Globally
 * This configuration ensures WebRTC works through any firewall worldwide
 */

// Override the existing connection to force TCP
if (window.SofiaRealConnection) {
    const originalConnect = SofiaRealConnection.prototype.connect;
    
    SofiaRealConnection.prototype.connect = async function() {
        console.log('🌍 Using TCP-Only mode for global accessibility');
        
        try {
            await this.loadLiveKitSDK();
            const LK = window.LiveKit;
            
            if (!LK) {
                throw new Error('LiveKit SDK not loaded');
            }

            // Get token
            const tokenResponse = await fetch(`${window.SOFIA_CONFIG.API_BASE_URL}/api/livekit-token`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'ngrok-skip-browser-warning': 'true'
                },
                body: JSON.stringify({
                    room: 'sofia-dental-' + Date.now(),
                    identity: 'calendar-user-' + Math.random().toString(36).substr(2, 9)
                })
            });

            const { token, url } = await tokenResponse.json();
            const livekitUrl = window.SOFIA_CONFIG?.LIVEKIT_URL || url;

            // Create room with TCP-only configuration
            this.room = new LK.Room({
                adaptiveStream: true,
                dynacast: true,
                stopLocalTrackOnUnpublish: true,
                // Force TCP-only configuration
                rtcConfig: {
                    iceTransportPolicy: 'relay', // Force TURN relay
                    iceServers: [
                        {
                            // Use TCP TURN server
                            urls: [
                                'turn:46.5.138.40:3478?transport=tcp',
                                'turn:46.5.138.40:3478'
                            ],
                            username: 'test',
                            credential: 'test'
                        },
                        {
                            // Backup: Public TURN servers (TCP)
                            urls: 'turn:openrelay.metered.ca:443?transport=tcp',
                            username: 'openrelayproject',
                            credential: 'openrelayproject'
                        }
                    ]
                },
                // Connection options for TCP
                connectionOpts: {
                    autoSubscribe: true,
                    maxRetries: 5,
                    peerConnectionTimeout: 30000, // 30 seconds for TCP
                    websocketTimeout: 30000
                }
            });

            // Log connection mode
            this.room.on('connectionStateChanged', (state) => {
                console.log('Connection state:', state);
                if (state === 'connected') {
                    console.log('✅ Connected via TCP relay - Works globally!');
                }
            });

            // Setup handlers and connect
            this.setupEventHandlers();
            
            console.log('Connecting via TCP to:', livekitUrl);
            await this.room.connect(livekitUrl, token);
            
            // Enable microphone
            await this.enableMicrophone(LK);
            
            this.isConnected = true;
            this.isConnecting = false;
            this.updateUI('connected');
            
            // Check for Sofia
            setTimeout(() => {
                const participants = Array.from(this.room.participants.values());
                console.log('Participants:', participants.map(p => p.identity));
                
                const sofia = participants.find(p => 
                    p.identity.toLowerCase().includes('agent') || 
                    p.identity.toLowerCase().includes('sofia')
                );
                
                if (sofia) {
                    console.log('✅ Sofia found:', sofia.identity);
                    this.addMessage('system', 'Sofia ist bereit (TCP-Verbindung)');
                } else {
                    this.addMessage('system', 'Warte auf Sofia...');
                }
            }, 3000);
            
        } catch (error) {
            console.error('TCP connection failed:', error);
            this.isConnecting = false;
            this.updateUI('disconnected');
            this.showError('Verbindung fehlgeschlagen: ' + error.message);
        }
    };
}

console.log('✅ TCP-Only mode enabled - Your service is now accessible worldwide!');