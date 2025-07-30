/**
 * Sofia LiveKit Voice Integration
 * Professional voice quality with LiveKit
 */

class SofiaLiveKitVoice {
    constructor() {
        this.room = null;
        this.isConnected = false;
        this.isListening = false;
        this.localAudioTrack = null;
        this.remoteAudioTrack = null;
        this.roomName = `sofia_room_${Date.now()}`;
        this.livekitUrl = 'ws://localhost:7880';
        this.token = null;
    }

    async initialize() {
        console.log('🎤 Initializing Sofia LiveKit Voice...');
        
        try {
            // Generate access token
            await this.generateToken();
            
            // Setup UI
            this.setupVoiceUI();
            
            console.log('✅ Sofia LiveKit Voice ready!');
            
        } catch (error) {
            console.error('❌ Failed to initialize Sofia LiveKit:', error);
            this.showError('LiveKit Voice-System nicht verfügbar');
        }
    }

    async generateToken() {
        // For development, we'll use a simple token
        // In production, this should come from your backend
        const payload = {
            iss: 'devkey',
            sub: 'sofia_user',
            iat: Math.floor(Date.now() / 1000),
            exp: Math.floor(Date.now() / 1000) + 3600, // 1 hour
            room: this.roomName,
            grants: {
                room: this.roomName,
                roomJoin: true,
                canPublish: true,
                canSubscribe: true
            }
        };
        
        // Simple token for development (in production use proper JWT signing)
        this.token = btoa(JSON.stringify(payload));
    }

    setupVoiceUI() {
        const btn = document.getElementById('sofiaVoiceBtn');
        const status = document.getElementById('voiceStatus');
        
        if (btn) {
            btn.onclick = () => this.toggleVoice();
            btn.innerHTML = '🎤 Sofia (LiveKit)';
        }
        
        if (status) {
            status.textContent = '🔊 LiveKit bereit';
        }
    }

    async toggleVoice() {
        if (!this.isConnected) {
            await this.connectToRoom();
        } else {
            await this.disconnectFromRoom();
        }
    }

    async connectToRoom() {
        try {
            console.log('🔗 Connecting to LiveKit room...');
            
            // Import LiveKit SDK
            if (typeof window.LiveKit === 'undefined' && typeof window.LiveKitClient === 'undefined') {
                console.log('LiveKit not found, loading SDK...');
                await this.loadLiveKitSDK();
            }
            
            // Check which global is available
            const LK = window.LiveKit || window.LiveKitClient || window.livekit;
            if (!LK) {
                throw new Error('LiveKit SDK not available after loading');
            }
            
            this.room = new LK.Room({
                adaptiveStream: true,
                dynacast: true
            });

            // Set up event listeners
            this.setupRoomEvents();

            // Connect to room
            await this.room.connect(this.livekitUrl, this.token);
            
            console.log('✅ Connected to LiveKit room');
            
        } catch (error) {
            console.error('❌ Failed to connect to LiveKit:', error);
            this.showError('Verbindung zu LiveKit fehlgeschlagen: ' + error.message);
        }
    }

    async loadLiveKitSDK() {
        return new Promise((resolve, reject) => {
            // Check if already loaded
            if (typeof window.LiveKit !== 'undefined' || typeof window.LiveKitClient !== 'undefined') {
                resolve();
                return;
            }
            
            const script = document.createElement('script');
            script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
            script.onload = () => {
                // Wait a bit for the script to fully initialize
                setTimeout(() => {
                    console.log('LiveKit SDK loaded');
                    // Check what was loaded
                    if (window.LiveKit) console.log('Found window.LiveKit');
                    if (window.LiveKitClient) console.log('Found window.LiveKitClient');
                    if (window.livekit) console.log('Found window.livekit');
                    resolve();
                }, 100);
            };
            script.onerror = (error) => {
                console.error('Failed to load LiveKit SDK:', error);
                reject(error);
            };
            document.head.appendChild(script);
        });
    }

    setupRoomEvents() {
        this.room.on('connected', () => {
            console.log('✅ Connected to room');
            this.isConnected = true;
            this.updateUI('connected', '🔊 Mit Sofia verbunden');
            this.enableMicrophone();
            this.speakSofia('Hallo! Ich bin Sofia mit LiveKit. Wie kann ich Ihnen helfen?');
        });

        this.room.on('disconnected', () => {
            console.log('❌ Disconnected from room');
            this.isConnected = false;
            this.updateUI('', '🔊 LiveKit bereit');
        });

        this.room.on('trackSubscribed', (track, publication, participant) => {
            if (track.kind === 'audio') {
                console.log('🔊 Receiving audio from Sofia');
                this.remoteAudioTrack = track;
                const audioElement = track.attach();
                document.body.appendChild(audioElement);
            }
        });

        this.room.on('trackUnsubscribed', (track, publication, participant) => {
            if (track.kind === 'audio') {
                track.detach();
            }
        });

        this.room.on('participantConnected', (participant) => {
            console.log('👋 Sofia joined the room');
        });
    }

    async enableMicrophone() {
        try {
            console.log('🎤 Enabling microphone...');
            
            const LK = window.LiveKit || window.LiveKitClient || window.livekit;
            this.localAudioTrack = await LK.createLocalAudioTrack({
                echoCancellation: true,
                noiseSuppression: true,
                autoGainControl: true,
            });

            await this.room.localParticipant.publishTrack(this.localAudioTrack);
            
            this.isListening = true;
            this.updateUI('listening', '🎤 Sofia hört zu...');
            
            console.log('✅ Microphone enabled');
            
        } catch (error) {
            console.error('❌ Failed to enable microphone:', error);
            this.showError('Mikrofon-Zugriff verweigert');
        }
    }

    async disconnectFromRoom() {
        try {
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
            
            this.updateUI('', '🔊 LiveKit bereit');
            
            console.log('✅ Disconnected from LiveKit');
            
        } catch (error) {
            console.error('❌ Error disconnecting:', error);
        }
    }

    updateUI(className, statusText) {
        const btn = document.getElementById('sofiaVoiceBtn');
        const status = document.getElementById('voiceStatus');
        
        if (btn) {
            btn.className = `sofia-voice-btn ${className}`;
            if (this.isConnected) {
                btn.innerHTML = this.isListening ? '🔴 Sofia hört zu...' : '🔊 Sofia verbunden';
            } else {
                btn.innerHTML = '🎤 Sofia (LiveKit)';
            }
        }
        
        if (status) {
            status.className = `voice-status ${className}`;
            status.textContent = statusText;
        }
    }

    speakSofia(text) {
        // In a real implementation, this would send the text to Sofia AI
        // and Sofia would respond through the LiveKit audio track
        console.log('🤖 Sofia would say:', text);
        
        // For demo, show visual response
        this.showSofiaResponse(text);
        
        // Simulate Sofia processing and responding
        setTimeout(() => {
            this.processVoiceCommand(text);
        }, 2000);
    }

    processVoiceCommand(command) {
        // This would be handled by the Sofia AI agent
        // For demo purposes, we'll simulate responses
        
        const responses = [
            "Gerne helfe ich Ihnen bei der Terminbuchung!",
            "Ich prüfe die verfügbaren Zeiten für Sie.",
            "Ihre Termine werden angezeigt.",
            "Unsere Öffnungszeiten sind Montag bis Freitag 8 bis 18 Uhr."
        ];
        
        const response = responses[Math.floor(Math.random() * responses.length)];
        this.showSofiaResponse(response);
    }

    showSofiaResponse(message) {
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
                <strong>Sofia (LiveKit):</strong><br>
                ${message}
            </div>
        `;
        
        document.body.appendChild(responseDiv);
        
        // Auto-remove after 8 seconds
        setTimeout(() => {
            responseDiv.remove();
        }, 8000);
    }

    showError(message) {
        const errorDiv = document.createElement('div');
        errorDiv.className = 'voice-response';
        errorDiv.style.borderColor = '#ff6b6b';
        errorDiv.innerHTML = `
            <div class="sofia-avatar" style="background: #ff6b6b;">❌</div>
            <div class="message">
                <strong>LiveKit Error:</strong><br>
                ${message}
            </div>
        `;
        
        document.body.appendChild(errorDiv);
        
        setTimeout(() => {
            errorDiv.remove();
        }, 5000);
    }
}

// Initialize Sofia LiveKit Voice when page loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 Initializing Sofia LiveKit Voice...');
    
    window.sofiaLiveKit = new SofiaLiveKitVoice();
    await window.sofiaLiveKit.initialize();
});
