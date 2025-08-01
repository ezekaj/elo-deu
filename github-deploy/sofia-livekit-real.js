/**
 * Sofia LiveKit Real Agent Integration
 * Verbindet den Kalender mit dem echten Sofia Agent (agent.py)
 */

class SofiaLiveKitReal {
    constructor() {
        this.room = null;
        this.isConnected = false;
        this.isListening = false;
        this.localAudioTrack = null;
        this.remoteAudioTrack = null;
        this.roomName = `dental_room_${Date.now()}`;
        this.livekitUrl = 'ws://localhost:7880';
        this.token = null;
        this.participantToken = null;
    }

    async initialize() {
        console.log('🎤 Initializing Sofia LiveKit Real Agent...');
        
        try {
            // Load LiveKit SDK
            await this.loadLiveKitSDK();
            
            // Generate access token
            await this.generateToken();
            
            // Setup UI
            this.setupUI();
            
            console.log('✅ Sofia LiveKit Real Agent ready!');
            return true;
            
        } catch (error) {
            console.error('❌ Failed to initialize Sofia LiveKit Real:', error);
            this.showError('Sofia Agent nicht verfügbar: ' + error.message);
            return false;
        }
    }

    async loadLiveKitSDK() {
        return new Promise((resolve, reject) => {
            if (typeof LiveKit !== 'undefined') {
                console.log('✅ LiveKit SDK already loaded');
                resolve();
                return;
            }

            // Wait for SDK to load (it's included in HTML)
            let attempts = 0;
            const checkSDK = () => {
                attempts++;
                if (typeof LiveKit !== 'undefined') {
                    console.log('✅ LiveKit SDK loaded after', attempts, 'attempts');
                    resolve();
                } else if (attempts < 50) { // Wait up to 5 seconds
                    setTimeout(checkSDK, 100);
                } else {
                    reject(new Error('LiveKit SDK failed to load after 5 seconds'));
                }
            };

            checkSDK();
        });
    }

    async generateToken() {
        try {
            // Request token from backend
            const response = await fetch('/api/voice/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                    roomName: this.roomName,
                    participantName: 'Patient'
                })
            });
            
            if (response.ok) {
                const data = await response.json();
                this.token = data.token;
                this.roomName = data.room_name || this.roomName;
                console.log('✅ Token received from backend');
            } else {
                // Fallback: Generate simple token for development
                this.generateDevToken();
            }
        } catch (error) {
            console.warn('⚠️ Backend token failed, using dev token:', error);
            this.generateDevToken();
        }
    }

    generateDevToken() {
        // Simple development token
        const payload = {
            iss: 'devkey',
            sub: 'patient_user',
            iat: Math.floor(Date.now() / 1000),
            exp: Math.floor(Date.now() / 1000) + 3600,
            room: this.roomName,
            grants: {
                room: this.roomName,
                roomJoin: true,
                canPublish: true,
                canSubscribe: true
            }
        };
        
        this.token = btoa(JSON.stringify(payload));
        console.log('✅ Development token generated');
    }

    setupUI() {
        const btn = document.getElementById('sofiaVoiceBtn');
        const status = document.getElementById('voiceStatus');
        
        if (btn) {
            btn.onclick = () => this.toggleAgent();
            btn.innerHTML = '🎤 Sofia (Echter Agent)';
        }
        
        if (status) {
            status.textContent = '🎤 Sofia Agent bereit';
        }
    }

    async toggleAgent() {
        if (!this.isConnected) {
            await this.connectToSofia();
        } else {
            await this.disconnectFromSofia();
        }
    }

    async connectToSofia() {
        try {
            console.log('🔗 Connecting to Sofia Agent...');
            
            this.room = new LiveKit.Room({
                adaptiveStream: true,
                dynacast: true,
                publishDefaults: {
                    audioPreset: LiveKit.AudioPresets.music,
                },
            });

            // Setup event listeners
            this.setupRoomEvents();

            // Connect to room
            await this.room.connect(this.livekitUrl, this.token);
            
            console.log('✅ Connected to Sofia Agent room');
            
        } catch (error) {
            console.error('❌ Failed to connect to Sofia Agent:', error);
            this.showError('Verbindung zu Sofia Agent fehlgeschlagen: ' + error.message);
        }
    }

    setupRoomEvents() {
        this.room.on('connected', async () => {
            console.log('✅ Connected to Sofia Agent room');
            this.isConnected = true;
            this.updateUI('connected', '🎤 Mit Sofia Agent verbunden');
            
            // Enable microphone
            await this.enableMicrophone();
            
            // Show welcome message
            this.showResponse('Verbunden mit Sofia Agent! Sprechen Sie jetzt...');
        });

        this.room.on('disconnected', () => {
            console.log('❌ Disconnected from Sofia Agent');
            this.isConnected = false;
            this.isListening = false;
            this.updateUI('', '🎤 Sofia Agent bereit');
        });

        this.room.on('trackSubscribed', (track, publication, participant) => {
            if (track.kind === 'audio') {
                console.log('🔊 Receiving audio from Sofia Agent');
                this.remoteAudioTrack = track;
                
                // Attach audio track to play Sofia's voice
                const audioElement = track.attach();
                audioElement.volume = 1.0;
                document.body.appendChild(audioElement);
                
                this.showResponse('Sofia Agent spricht...');
            }
        });

        this.room.on('trackUnsubscribed', (track, publication, participant) => {
            if (track.kind === 'audio') {
                track.detach();
            }
        });

        this.room.on('participantConnected', (participant) => {
            console.log('👋 Sofia Agent joined the room:', participant.identity);
            this.showResponse('Sofia Agent ist beigetreten!');
        });

        this.room.on('participantDisconnected', (participant) => {
            console.log('👋 Sofia Agent left the room:', participant.identity);
            this.showResponse('Sofia Agent hat den Raum verlassen');
        });

        // Listen for data messages from Sofia
        this.room.on('dataReceived', (payload, participant) => {
            try {
                const message = JSON.parse(new TextDecoder().decode(payload));
                console.log('📨 Message from Sofia:', message);
                
                if (message.type === 'response') {
                    this.showResponse(message.text);
                } else if (message.type === 'action') {
                    this.executeAction(message.action);
                }
            } catch (error) {
                console.error('Error parsing Sofia message:', error);
            }
        });
    }

    async enableMicrophone() {
        try {
            console.log('🎤 Enabling microphone for Sofia Agent...');
            
            this.localAudioTrack = await LiveKit.createLocalAudioTrack({
                echoCancellation: true,
                noiseSuppression: true,
                autoGainControl: true,
                sampleRate: 48000,
                channelCount: 1,
            });

            await this.room.localParticipant.publishTrack(this.localAudioTrack);
            
            this.isListening = true;
            this.updateUI('listening', '🎤 Sofia Agent hört zu...');
            
            console.log('✅ Microphone enabled for Sofia Agent');
            
        } catch (error) {
            console.error('❌ Failed to enable microphone:', error);
            this.showError('Mikrofon-Zugriff verweigert');
        }
    }

    async disconnectFromSofia() {
        try {
            console.log('🔌 Disconnecting from Sofia Agent...');
            
            if (this.localAudioTrack) {
                this.localAudioTrack.stop();
                this.localAudioTrack = null;
            }

            if (this.room) {
                await this.room.disconnect();
                this.room = null;
            }

            this.isConnected = false;
            this.isListening = false;
            
            this.updateUI('', '🎤 Sofia Agent bereit');
            
            console.log('✅ Disconnected from Sofia Agent');
            
        } catch (error) {
            console.error('❌ Error disconnecting from Sofia Agent:', error);
        }
    }

    executeAction(action) {
        switch (action) {
            case 'open_appointment_form':
                setTimeout(() => {
                    if (typeof openNewAppointmentModal === 'function') {
                        openNewAppointmentModal();
                    }
                }, 1000);
                break;
                
            case 'refresh_calendar':
                setTimeout(() => {
                    if (typeof refreshCalendar === 'function') {
                        refreshCalendar();
                    }
                }, 1000);
                break;
                
            default:
                console.log('Unknown action:', action);
        }
    }

    updateUI(className, statusText) {
        const btn = document.getElementById('sofiaVoiceBtn');
        const status = document.getElementById('voiceStatus');
        
        if (btn) {
            btn.className = `sofia-voice-btn ${className}`;
            
            if (className === 'listening') {
                btn.innerHTML = '🔴 Sofia hört zu...';
            } else if (className === 'connected') {
                btn.innerHTML = '🎤 Sofia verbunden';
            } else {
                btn.innerHTML = '🎤 Sofia (Echter Agent)';
            }
        }
        
        if (status) {
            status.className = `voice-status ${className}`;
            status.textContent = statusText;
        }
    }

    showResponse(message) {
        // Remove existing response
        const existing = document.querySelector('.voice-response');
        if (existing) {
            existing.remove();
        }
        
        // Create new response
        const responseDiv = document.createElement('div');
        responseDiv.className = 'voice-response';
        responseDiv.innerHTML = `
            <div class="sofia-avatar">🤖</div>
            <div class="message">
                <strong>Sofia Agent:</strong><br>
                ${message}
            </div>
        `;
        
        document.body.appendChild(responseDiv);
        
        // Auto-remove after 10 seconds
        setTimeout(() => {
            responseDiv.remove();
        }, 10000);
    }

    showError(message) {
        const errorDiv = document.createElement('div');
        errorDiv.className = 'voice-response';
        errorDiv.style.borderColor = '#ff6b6b';
        errorDiv.innerHTML = `
            <div class="sofia-avatar" style="background: #ff6b6b;">❌</div>
            <div class="message">
                <strong>Fehler:</strong><br>
                ${message}
            </div>
        `;
        
        document.body.appendChild(errorDiv);
        
        setTimeout(() => {
            errorDiv.remove();
        }, 5000);
    }
}

// Initialize Sofia LiveKit Real Agent when page loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 Initializing Sofia LiveKit Real Agent...');
    
    window.sofiaLiveKitReal = new SofiaLiveKitReal();
    const initialized = await window.sofiaLiveKitReal.initialize();
    
    if (initialized) {
        console.log('✅ Sofia LiveKit Real Agent ready!');
        
        // Override the toggle function
        window.toggleSofiaVoice = () => {
            window.sofiaLiveKitReal.toggleAgent();
        };
    }
});
