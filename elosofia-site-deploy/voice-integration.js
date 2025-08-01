/**
 * Sofia Voice Integration for Dental Calendar
 * Integrates LiveKit voice functionality with the calendar system
 */

class SofiaVoiceIntegration {
    constructor() {
        this.room = null;
        this.isConnected = false;
        this.isListening = false;
        this.roomName = null;
        this.livekitUrl = null;
        this.audioTrack = null;
        this.remoteAudioTrack = null;
    }

    async initialize() {
        console.log('🎤 Initializing Sofia Voice Integration...');
        
        try {
            // Get LiveKit connection info
            const response = await fetch('/api/voice/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ clientType: 'calendar' })
            });
            
            const config = await response.json();
            this.livekitUrl = config.livekit_url;
            this.roomName = config.room_name;
            
            console.log('✅ Voice configuration received:', config);
            
            // Initialize UI
            this.setupVoiceUI();
            
        } catch (error) {
            console.error('❌ Failed to initialize voice integration:', error);
            this.showVoiceError('Voice-Funktionalität nicht verfügbar');
        }
    }

    setupVoiceUI() {
        // Add voice button to calendar interface
        const voiceButton = document.createElement('button');
        voiceButton.id = 'voice-button';
        voiceButton.className = 'voice-button';
        voiceButton.innerHTML = '🎤 Mit Sofia sprechen';
        voiceButton.onclick = () => this.toggleVoice();
        
        // Add to calendar header
        const calendarHeader = document.querySelector('.fc-toolbar-chunk') || document.body;
        calendarHeader.appendChild(voiceButton);
        
        // Add voice status indicator
        const statusDiv = document.createElement('div');
        statusDiv.id = 'voice-status';
        statusDiv.className = 'voice-status';
        statusDiv.innerHTML = '🔇 Voice bereit';
        calendarHeader.appendChild(statusDiv);
        
        // Add CSS styles
        this.addVoiceStyles();
    }

    addVoiceStyles() {
        const style = document.createElement('style');
        style.textContent = `
            .voice-button {
                background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 25px;
                cursor: pointer;
                font-size: 14px;
                margin: 0 10px;
                transition: all 0.3s ease;
            }
            
            .voice-button:hover {
                transform: translateY(-2px);
                box-shadow: 0 5px 15px rgba(17, 153, 142, 0.3);
            }
            
            .voice-button.listening {
                background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
                animation: pulse 1.5s infinite;
            }
            
            .voice-status {
                display: inline-block;
                padding: 5px 15px;
                background: #f8f9fa;
                border-radius: 15px;
                font-size: 12px;
                margin: 0 10px;
                border: 1px solid #e9ecef;
            }
            
            .voice-status.connected {
                background: #d4edda;
                border-color: #c3e6cb;
                color: #155724;
            }
            
            .voice-status.listening {
                background: #fff3cd;
                border-color: #ffeaa7;
                color: #856404;
            }
            
            @keyframes pulse {
                0% { transform: scale(1); }
                50% { transform: scale(1.05); }
                100% { transform: scale(1); }
            }
            
            .voice-response {
                position: fixed;
                top: 20px;
                right: 20px;
                background: white;
                border: 2px solid #11998e;
                border-radius: 10px;
                padding: 15px;
                max-width: 300px;
                box-shadow: 0 5px 15px rgba(0,0,0,0.1);
                z-index: 1000;
                animation: slideIn 0.3s ease;
            }
            
            @keyframes slideIn {
                from { transform: translateX(100%); opacity: 0; }
                to { transform: translateX(0); opacity: 1; }
            }
        `;
        document.head.appendChild(style);
    }

    async toggleVoice() {
        if (!this.isConnected) {
            await this.connectVoice();
        } else {
            await this.disconnectVoice();
        }
    }

    async connectVoice() {
        try {
            console.log('🔗 Connecting to voice room...');
            
            // Import LiveKit SDK (assuming it's loaded)
            if (typeof LiveKit === 'undefined') {
                throw new Error('LiveKit SDK not loaded');
            }
            
            this.room = new LiveKit.Room();
            
            // Set up event listeners
            this.room.on('connected', () => {
                console.log('✅ Connected to voice room');
                this.isConnected = true;
                this.updateVoiceStatus('connected', '🔊 Verbunden mit Sofia');
                this.updateVoiceButton('🔇 Trennen', 'connected');
            });
            
            this.room.on('disconnected', () => {
                console.log('❌ Disconnected from voice room');
                this.isConnected = false;
                this.updateVoiceStatus('', '🔇 Voice bereit');
                this.updateVoiceButton('🎤 Mit Sofia sprechen', '');
            });
            
            this.room.on('trackSubscribed', (track, publication, participant) => {
                if (track.kind === 'audio') {
                    console.log('🔊 Receiving audio from Sofia');
                    this.remoteAudioTrack = track;
                    track.attach();
                }
            });
            
            // Connect to room
            await this.room.connect(this.livekitUrl, this.roomName);
            
            // Enable microphone
            await this.enableMicrophone();
            
        } catch (error) {
            console.error('❌ Failed to connect voice:', error);
            this.showVoiceError('Verbindung fehlgeschlagen: ' + error.message);
        }
    }

    async enableMicrophone() {
        try {
            console.log('🎤 Enabling microphone...');
            
            this.audioTrack = await LiveKit.createLocalAudioTrack();
            await this.room.localParticipant.publishTrack(this.audioTrack);
            
            this.isListening = true;
            this.updateVoiceStatus('listening', '🎤 Sofia hört zu...');
            
            console.log('✅ Microphone enabled');
            
        } catch (error) {
            console.error('❌ Failed to enable microphone:', error);
            this.showVoiceError('Mikrofon-Zugriff verweigert');
        }
    }

    async disconnectVoice() {
        try {
            if (this.audioTrack) {
                this.audioTrack.stop();
                this.audioTrack = null;
            }
            
            if (this.room) {
                await this.room.disconnect();
                this.room = null;
            }
            
            this.isConnected = false;
            this.isListening = false;
            
            console.log('✅ Voice disconnected');
            
        } catch (error) {
            console.error('❌ Error disconnecting voice:', error);
        }
    }

    updateVoiceStatus(className, text) {
        const status = document.getElementById('voice-status');
        if (status) {
            status.className = `voice-status ${className}`;
            status.textContent = text;
        }
    }

    updateVoiceButton(text, className) {
        const button = document.getElementById('voice-button');
        if (button) {
            button.textContent = text;
            button.className = `voice-button ${className}`;
        }
    }

    showVoiceError(message) {
        const errorDiv = document.createElement('div');
        errorDiv.className = 'voice-response';
        errorDiv.innerHTML = `
            <strong>❌ Voice Error</strong><br>
            ${message}
        `;
        
        document.body.appendChild(errorDiv);
        
        setTimeout(() => {
            errorDiv.remove();
        }, 5000);
    }

    showVoiceResponse(response) {
        const responseDiv = document.createElement('div');
        responseDiv.className = 'voice-response';
        responseDiv.innerHTML = `
            <strong>🤖 Sofia sagt:</strong><br>
            ${response.message}
        `;
        
        document.body.appendChild(responseDiv);
        
        // Auto-remove after 10 seconds
        setTimeout(() => {
            responseDiv.remove();
        }, 10000);
        
        // If appointment was confirmed, refresh calendar
        if (response.type === 'appointment_confirmed' && response.appointment) {
            setTimeout(() => {
                location.reload(); // Simple refresh - could be improved with dynamic update
            }, 2000);
        }
    }
}

// Initialize voice integration when page loads
document.addEventListener('DOMContentLoaded', () => {
    // Check if voice is enabled
    if (window.SOFIA_VOICE_ENABLED) {
        const voiceIntegration = new SofiaVoiceIntegration();
        voiceIntegration.initialize();
        
        // Make it globally available
        window.sofiaVoice = voiceIntegration;
        
        // Listen for voice responses from server
        if (window.socket) {
            window.socket.on('voice_response', (response) => {
                voiceIntegration.showVoiceResponse(response);
            });
        }
    }
});
