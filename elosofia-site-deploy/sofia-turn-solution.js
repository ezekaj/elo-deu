/**
 * Sofia TURN Solution - Uses TURN relay for guaranteed connectivity
 * This solution works through any firewall/NAT without WebSocket proxy
 */

// Override connection to use TURN relay
if (window.sofiaConnection || window.SofiaDirectConnection) {
    console.log('🔧 Applying TURN solution for Sofia connection...');
    
    // Store original connect method
    const ConnectionClass = window.SofiaDirectConnection || window.SofiaRealConnection;
    const originalConnect = ConnectionClass.prototype.connect;
    
    // Override with TURN configuration
    ConnectionClass.prototype.connect = async function() {
        console.log('🌐 Using TURN relay for guaranteed connectivity');
        
        try {
            const LK = window.LivekitClient || window.LiveKit;
            if (!LK) {
                throw new Error('LiveKit SDK not loaded');
            }

            // Get token from server - but use direct LiveKit connection
            const tokenResponse = await fetch(`${window.SOFIA_CONFIG.API_BASE_URL}/api/livekit-token`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'ngrok-skip-browser-warning': 'true'
                },
                body: JSON.stringify({
                    room: 'sofia-dental-' + Date.now(),
                    identity: 'Calendar User ' + Date.now()
                })
            });

            if (!tokenResponse.ok) {
                throw new Error('Failed to get connection token');
            }

            const { token, url } = await tokenResponse.json();
            
            // IMPORTANT: For external connections, use the direct LiveKit port
            // This avoids the WebSocket proxy issue
            let connectUrl = url;
            const currentHost = window.location.hostname;
            
            if (currentHost !== 'localhost' && currentHost !== '127.0.0.1') {
                // External connection - use ngrok URL with LiveKit port
                connectUrl = `wss://ecd85b3c3637.ngrok-free.app:7880`;
                console.log('📡 External connection, using direct URL:', connectUrl);
            }

            // Create room with TURN-only configuration
            this.room = new LK.Room({
                adaptiveStream: true,
                dynacast: true,
                stopLocalTrackOnUnpublish: true,
                // Force TURN relay for guaranteed connectivity
                rtcConfig: {
                    iceTransportPolicy: 'relay', // Force TURN only
                    iceServers: [
                        // Public TURN servers
                        {
                            urls: 'turn:openrelay.metered.ca:80',
                            username: 'openrelayproject',
                            credential: 'openrelayproject'
                        },
                        {
                            urls: 'turn:openrelay.metered.ca:443',
                            username: 'openrelayproject',
                            credential: 'openrelayproject'
                        },
                        {
                            urls: 'turn:openrelay.metered.ca:443?transport=tcp',
                            username: 'openrelayproject',
                            credential: 'openrelayproject'
                        },
                        // Your TURN server as backup
                        {
                            urls: [
                                'turn:46.5.138.40:3478',
                                'turn:46.5.138.40:3478?transport=tcp'
                            ],
                            username: 'user',
                            credential: 'pass'
                        }
                    ]
                }
            });

            // Set up event handlers
            this.room.on('connected', () => {
                console.log('✅ Connected via TURN relay');
                if (window.sofiaInterface) {
                    window.sofiaInterface.classList.add('visible');
                }
            });

            this.room.on('disconnected', (reason) => {
                console.log('🔴 Disconnected:', reason);
            });

            this.room.on('participantConnected', (participant) => {
                console.log('👤 Participant connected:', participant.identity);
                if (participant.identity.toLowerCase().includes('sofia') || 
                    participant.identity.toLowerCase().includes('agent')) {
                    console.log('🤖 Sofia agent connected!');
                    this.onSofiaConnected();
                }
            });

            this.room.on('trackSubscribed', (track, publication, participant) => {
                if (track.kind === 'audio' && 
                    (participant.identity.toLowerCase().includes('sofia') || 
                     participant.identity.toLowerCase().includes('agent'))) {
                    const audioElement = track.attach();
                    audioElement.autoplay = true;
                    document.body.appendChild(audioElement);
                    console.log('🔊 Sofia audio attached');
                }
            });

            // Connect with retry logic
            let retries = 3;
            while (retries > 0) {
                try {
                    console.log(`🔗 Attempting connection to: ${connectUrl} (${retries} retries left)`);
                    await this.room.connect(connectUrl, token);
                    console.log('✅ Successfully connected!');
                    break;
                } catch (error) {
                    retries--;
                    if (retries === 0) throw error;
                    console.log(`⚠️ Connection failed, retrying in 2s...`);
                    await new Promise(resolve => setTimeout(resolve, 2000));
                }
            }

            // Set up audio after connection
            await this.setupAudio();
            
            return true;
            
        } catch (error) {
            console.error('❌ TURN connection error:', error);
            
            // Provide helpful error message
            if (error.message.includes('Failed to connect')) {
                alert(`Verbindung fehlgeschlagen. 

Bitte versuchen Sie:
1. Seite neu laden (F5)
2. Browser-Cache leeren
3. Anderen Browser verwenden
4. Lokale Firewall prüfen

Fehler: ${error.message}`);
            }
            
            throw error;
        }
    };

    // Helper method for Sofia connected
    ConnectionClass.prototype.onSofiaConnected = function() {
        if (window.addMessage) {
            window.addMessage('sofia', 'Hallo! Ich bin Sofia, Ihre KI-Assistentin. Wie kann ich Ihnen helfen?');
        }
        if (window.updateStatus) {
            window.updateStatus('Sofia hört zu...', true);
        }
    };

    // Helper method for audio setup
    ConnectionClass.prototype.setupAudio = async function() {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({ 
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                } 
            });
            
            const LK = window.LivekitClient || window.LiveKit;
            this.audioTrack = new LK.LocalAudioTrack(stream.getAudioTracks()[0]);
            await this.room.localParticipant.publishTrack(this.audioTrack);
            
            console.log('🎤 Microphone active');
            
        } catch (error) {
            console.error('❌ Audio error:', error);
            alert('Mikrofon-Zugriff verweigert. Bitte erlauben Sie den Zugriff.');
            throw error;
        }
    };
}

console.log('✅ TURN solution loaded - Sofia should now work globally');