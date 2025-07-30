/**
 * Sofia LiveKit Integration for Calendar
 * Connects the calendar to the actual Sofia LiveKit agent running from agent.py
 */

class SofiaLiveKitIntegration {
    constructor() {
        this.room = null;
        this.localParticipant = null;
        this.remoteParticipant = null;
        this.audioTrack = null;
        this.isConnected = false;
        this.isListening = false;
        
        // LiveKit configuration
        this.livekitUrl = 'ws://localhost:7880'; // Default LiveKit URL
        this.token = null;
        
        // UI elements
        this.button = null;
        this.status = null;
    }

    async initialize() {
        console.log('🎤 Initializing Sofia LiveKit Integration...');
        
        try {
            // Setup UI
            this.setupUI();
            
            // Check if LiveKit is available
            if (!window.LivekitClient) {
                throw new Error('LiveKit Client not loaded');
            }
            
            console.log('✅ Sofia LiveKit Integration ready!');
            return true;
            
        } catch (error) {
            console.error('❌ Failed to initialize Sofia LiveKit Integration:', error);
            this.showError('Sofia LiveKit Integration konnte nicht initialisiert werden: ' + error.message);
            return false;
        }
    }

    setupUI() {
        this.button = document.getElementById('sofiaVoiceBtn');
        this.status = document.getElementById('voiceStatus');
        
        if (this.button) {
            this.button.onclick = () => this.toggleConnection();
        }
    }

    async toggleConnection() {
        if (!this.isConnected) {
            await this.connect();
        } else {
            await this.disconnect();
        }
    }

    async connect() {
        try {
            this.updateUI('connecting', '🔄 Verbinde mit Sofia...');
            
            // Get a token from the calendar server (not Sofia web service)
            const tokenResponse = await fetch('/api/livekit-token', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    identity: 'calendar-user-' + Date.now(),
                    room: 'sofia-room'
                })
            });
            
            if (!tokenResponse.ok) {
                // If token endpoint fails, try direct connection
                console.warn('Token endpoint not available, trying direct connection...');
                this.token = await this.generateTestToken();
            } else {
                const data = await tokenResponse.json();
                this.token = data.token;
            }
            
            // Create LiveKit room
            this.room = new LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true,
                videoCaptureDefaults: {
                    resolution: LivekitClient.VideoPresets.h720.resolution,
                },
            });
            
            // Setup event handlers
            this.setupRoomEvents();
            
            // Connect to room
            await this.room.connect(this.livekitUrl, this.token);
            
            // Enable microphone
            await this.room.localParticipant.setMicrophoneEnabled(true);
            
            this.isConnected = true;
            this.updateUI('connected', '🟢 Verbunden mit Sofia');
            
            // Greet the user
            this.sendMessage('start_conversation', { 
                message: 'Hallo, ich möchte einen Termin vereinbaren' 
            });
            
        } catch (error) {
            console.error('Connection error:', error);
            this.handleError('Verbindung fehlgeschlagen: ' + error.message);
        }
    }

    async disconnect() {
        try {
            if (this.room) {
                await this.room.disconnect();
                this.room = null;
            }
            
            this.isConnected = false;
            this.updateUI('', '🤖 Sofia Agent bereit');
            
        } catch (error) {
            console.error('Disconnect error:', error);
        }
    }

    setupRoomEvents() {
        // Handle participant connected
        this.room.on(LivekitClient.RoomEvent.ParticipantConnected, (participant) => {
            console.log('Participant connected:', participant.identity);
            if (participant.identity.includes('sofia')) {
                this.remoteParticipant = participant;
                this.updateUI('connected', '🟢 Sofia ist da!');
            }
        });
        
        // Handle track subscribed (audio from Sofia)
        this.room.on(LivekitClient.RoomEvent.TrackSubscribed, (track, publication, participant) => {
            if (track.kind === 'audio' && participant.identity.includes('sofia')) {
                const audioElement = track.attach();
                audioElement.play();
                document.body.appendChild(audioElement);
                audioElement.style.display = 'none';
            }
        });
        
        // Handle data received
        this.room.on(LivekitClient.RoomEvent.DataReceived, (payload, participant) => {
            try {
                const data = JSON.parse(new TextDecoder().decode(payload));
                this.handleDataMessage(data, participant);
            } catch (error) {
                console.error('Error parsing data:', error);
            }
        });
        
        // Handle disconnect
        this.room.on(LivekitClient.RoomEvent.Disconnected, () => {
            console.log('Disconnected from room');
            this.isConnected = false;
            this.updateUI('', '🤖 Sofia Agent bereit');
        });
    }

    handleDataMessage(data, participant) {
        console.log('Data received:', data);
        
        if (data.type === 'sofia_response') {
            this.showSofiaMessage(data.message);
            
            // Handle specific actions
            if (data.action === 'open_appointment_form') {
                this.openAppointmentForm();
            } else if (data.action === 'show_available_times') {
                this.showAvailableTimes(data.times);
            }
        }
    }

    sendMessage(type, data) {
        if (this.room && this.room.localParticipant) {
            const message = JSON.stringify({ type, ...data });
            const encoder = new TextEncoder();
            this.room.localParticipant.publishData(encoder.encode(message), true);
        }
    }

    openAppointmentForm() {
        // Call the calendar's function to open appointment modal
        if (typeof openNewAppointmentModal === 'function') {
            openNewAppointmentModal();
        }
    }

    showAvailableTimes(times) {
        const message = `Verfügbare Zeiten: ${times.join(', ')}`;
        this.showSofiaMessage(message);
    }

    showSofiaMessage(message) {
        const responseDiv = document.createElement('div');
        responseDiv.className = 'voice-response';
        responseDiv.innerHTML = `
            <div class="sofia-avatar">🤖</div>
            <div class="message">
                <strong>Sofia:</strong><br>
                ${message}
            </div>
        `;
        
        document.body.appendChild(responseDiv);
        
        setTimeout(() => {
            responseDiv.remove();
        }, 8000);
    }

    updateUI(className, statusText) {
        if (this.button) {
            this.button.className = `sofia-voice-btn ${className}`;
            
            switch(className) {
                case 'connecting':
                    this.button.innerHTML = '🔄 Verbinde...';
                    break;
                case 'connected':
                    this.button.innerHTML = '🟢 Sofia aktiv';
                    break;
                case 'listening':
                    this.button.innerHTML = '🔴 Sofia hört zu...';
                    break;
                default:
                    this.button.innerHTML = '🤖 Sofia Agent';
            }
        }
        
        if (this.status) {
            this.status.className = `voice-status ${className}`;
            this.status.textContent = statusText;
        }
    }

    handleError(message) {
        console.error('Sofia Error:', message);
        this.showError(message);
        this.updateUI('', '🤖 Sofia Agent bereit');
    }

    showError(message) {
        const errorDiv = document.createElement('div');
        errorDiv.className = 'voice-response error';
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

    // Generate test token for development
    async generateTestToken() {
        // This is for development only
        // In production, always get tokens from your server
        return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE5OTk5OTk5OTksImlzcyI6ImRldmtleSIsIm5hbWUiOiJjYWxlbmRhci11c2VyIiwibmJmIjoxNjAwMDAwMDAwLCJzdWIiOiJjYWxlbmRhci11c2VyIiwidmlkZW8iOnsicm9vbSI6InNvZmlhLXJvb20iLCJyb29tSm9pbiI6dHJ1ZX19.8VdTb1p0ijp5KqYi5JQvjVaJa2qU2r3g6qZrH3mYM0E';
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 Sofia LiveKit Integration wird geladen...');
    
    // Create global instance
    window.sofiaLiveKit = new SofiaLiveKitIntegration();
    
    // Override the toggle function
    window.toggleSofiaVoice = async () => {
        if (!window.sofiaLiveKit) {
            await window.sofiaLiveKit.initialize();
        }
        window.sofiaLiveKit.toggleConnection();
    };
    
    // Initialize
    const initialized = await window.sofiaLiveKit.initialize();
    
    if (initialized) {
        console.log('✅ Sofia LiveKit Integration erfolgreich geladen!');
    }
});