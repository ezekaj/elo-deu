/**
 * Sofia LiveKit Integration for Calendar - Complete Solution
 * Fixes all identified issues to make Sofia work through browser like console
 */

class SofiaLiveKitIntegration {
    constructor() {
        this.room = null;
        this.localParticipant = null;
        this.remoteParticipant = null;
        this.audioTrack = null;
        this.isConnected = false;
        this.isListening = false;
        this.connectionAttempts = 0;
        this.maxRetries = 3;
        
        // LiveKit configuration
        this.livekitUrl = 'ws://localhost:7880';
        this.token = null;
        
        // UI elements
        this.button = null;
        this.status = null;
        
        // Audio handling
        this.remoteAudioElements = new Map();
        this.localAudioTrack = null;
        
        // Agent tracking
        this.agentConnected = false;
        this.pendingMessages = [];
    }

    async initialize() {
        console.log('🎤 Initializing Sofia LiveKit Integration...');
        
        try {
            // Setup UI
            this.setupUI();
            
            // Fix SDK reference issue - check all possible names
            if (!window.LivekitClient && !window.livekitClient && !window.LiveKit) {
                console.error('LiveKit SDK not found. Available globals:', 
                    Object.keys(window).filter(k => k.toLowerCase().includes('live')));
                throw new Error('LiveKit Client not loaded. Please check if the SDK is properly included.');
            }
            
            // Normalize the SDK reference
            if (!window.LivekitClient) {
                if (window.livekitClient) {
                    window.LivekitClient = window.livekitClient;
                    console.log('✅ Using window.livekitClient');
                } else if (window.LiveKit) {
                    window.LivekitClient = window.LiveKit;
                    console.log('✅ Using window.LiveKit');
                }
            }
            
            console.log('✅ Sofia LiveKit Integration ready!');
            console.log('📦 LiveKit SDK loaded:', !!window.LivekitClient);
            
            // Log available LiveKit components
            if (window.LivekitClient) {
                console.log('Available LiveKit components:', Object.keys(window.LivekitClient));
            }
            
            return true;
            
        } catch (error) {
            console.error('❌ Failed to initialize Sofia LiveKit Integration:', error);
            this.showError('Sofia Integration konnte nicht initialisiert werden: ' + error.message);
            return false;
        }
    }

    setupUI() {
        this.button = document.getElementById('sofiaVoiceBtn');
        this.status = document.getElementById('voiceStatus');
        
        if (this.button) {
            this.button.onclick = () => this.toggleConnection();
            console.log('✅ Sofia button configured');
        } else {
            console.warn('⚠️ Sofia button not found in DOM');
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
            this.connectionAttempts++;
            
            // First ensure the room exists
            const roomName = await this.ensureRoomExists();
            console.log(`📍 Using room: ${roomName}`);
            
            // Get token for the room
            this.token = await this.getToken(roomName);
            
            // Create LiveKit room with proper configuration
            const RoomOptions = window.LivekitClient.RoomOptions || {};
            this.room = new window.LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true,
                ...RoomOptions
            });
            
            // Setup comprehensive event handlers
            this.setupRoomEvents();
            
            // Connect to room
            console.log('🔌 Connecting to LiveKit server...');
            await this.room.connect(this.livekitUrl, this.token);
            
            console.log('✅ Connected to room:', this.room.name);
            console.log('👤 Local participant:', this.room.localParticipant.identity);
            console.log('👥 Remote participants:', this.room.participants ? this.room.participants.size : 0);
            
            // Enable microphone with proper error handling
            try {
                console.log('🎤 Enabling microphone...');
                await this.room.localParticipant.setMicrophoneEnabled(true);
                console.log('✅ Microphone enabled');
            } catch (micError) {
                console.error('❌ Microphone error:', micError);
                this.showError('Mikrofon konnte nicht aktiviert werden. Bitte Berechtigungen prüfen.');
            }
            
            this.isConnected = true;
            this.updateUI('connected', '🟢 Mit LiveKit verbunden');
            
            // Wait for agent or send pending messages
            if (this.agentConnected) {
                this.processPendingMessages();
            } else {
                console.log('⏳ Waiting for Sofia agent to connect...');
                // Try to trigger agent connection
                this.sendDataMessage('agent_request', {
                    type: 'calendar-user',
                    request: 'dental-receptionist'
                });
            }
            
        } catch (error) {
            console.error('❌ Connection error:', error);
            this.handleConnectionError(error);
        }
    }

    async ensureRoomExists() {
        // Try to get existing room or create new one
        try {
            const response = await fetch('/api/check-sofia-room', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            });
            
            if (response.ok) {
                const data = await response.json();
                return data.room || 'sofia-room';
            }
        } catch (error) {
            console.warn('Could not check room status:', error);
        }
        
        // Default room name
        return 'sofia-room';
    }

    async getToken(roomName) {
        try {
            // Try to get token from server
            const response = await fetch('/api/livekit-token', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    identity: 'calendar-user-' + Date.now(),
                    room: roomName,
                    metadata: JSON.stringify({
                        type: 'calendar-interface',
                        agent_request: true
                    })
                })
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log('✅ Got token from server');
                if (data.url) {
                    this.livekitUrl = data.url;
                }
                return data.token;
            }
        } catch (error) {
            console.warn('Could not get token from server:', error);
        }
        
        // Fallback: generate test token
        return this.generateTestToken();
    }

    setupRoomEvents() {
        const RoomEvent = window.LivekitClient.RoomEvent;
        
        // Connection state monitoring
        this.room.on(RoomEvent.ConnectionStateChanged, (state) => {
            console.log('📡 Connection state:', state);
            if (state === 'connected') {
                this.connectionAttempts = 0;
            }
        });
        
        // Handle participant connected
        this.room.on(RoomEvent.ParticipantConnected, (participant) => {
            console.log('✅ Participant connected:', {
                identity: participant.identity,
                sid: participant.sid,
                metadata: participant.metadata
            });
            
            // Detect Sofia agent by various patterns
            const isSofia = participant.identity.toLowerCase().includes('sofia') ||
                           participant.identity.toLowerCase().includes('agent') ||
                           participant.metadata?.includes('agent') ||
                           participant.metadata?.includes('dental');
            
            if (isSofia) {
                this.remoteParticipant = participant;
                this.agentConnected = true;
                this.updateUI('connected', '🟢 Sofia Agent verbunden!');
                console.log('🤖 Sofia agent detected and connected!');
                
                // Process any pending messages
                this.processPendingMessages();
                
                // Send initial greeting
                setTimeout(() => {
                    this.sendDataMessage('user_ready', {
                        message: 'Benutzer ist bereit',
                        interface: 'calendar-web'
                    });
                }, 1000);
            }
        });
        
        // Handle track subscribed (audio from Sofia)
        this.room.on(RoomEvent.TrackSubscribed, (track, publication, participant) => {
            console.log('🎵 Track subscribed:', {
                kind: track.kind,
                participant: participant.identity,
                trackSid: track.sid,
                source: publication.source
            });
            
            if (track.kind === window.LivekitClient.Track.Kind.Audio || track.kind === 'audio') {
                console.log('🔊 Attaching audio track from', participant.identity);
                
                // Remove any existing audio elements for this participant
                const existingAudio = this.remoteAudioElements.get(participant.sid);
                if (existingAudio) {
                    existingAudio.remove();
                }
                
                // Attach and play the audio
                const audioElement = track.attach();
                audioElement.autoplay = true;
                audioElement.controls = false;
                document.body.appendChild(audioElement);
                audioElement.style.display = 'none';
                
                // Store reference
                this.remoteAudioElements.set(participant.sid, audioElement);
                
                // Ensure playback
                audioElement.play().then(() => {
                    console.log('✅ Audio playback started for', participant.identity);
                }).catch(err => {
                    console.error('❌ Audio playback failed:', err);
                    // Try to play on user interaction
                    this.button.addEventListener('click', () => {
                        audioElement.play();
                    }, { once: true });
                });
            }
        });
        
        // Handle track published (our microphone)
        this.room.on(RoomEvent.LocalTrackPublished, (publication) => {
            console.log('📤 Local track published:', {
                kind: publication.kind,
                trackSid: publication.trackSid,
                source: publication.source
            });
            
            if (publication.kind === 'audio') {
                this.localAudioTrack = publication.track;
                console.log('✅ Local audio track published successfully');
            }
        });
        
        // Handle track unpublished
        this.room.on(RoomEvent.LocalTrackUnpublished, (publication) => {
            console.log('📤 Local track unpublished:', publication.trackSid);
        });
        
        // Handle data received
        this.room.on(RoomEvent.DataReceived, (payload, participant) => {
            try {
                const data = JSON.parse(new TextDecoder().decode(payload));
                console.log('📨 Data received from', participant.identity, ':', data);
                this.handleDataMessage(data, participant);
            } catch (error) {
                console.error('Error parsing data:', error);
                // Try to handle as string
                const text = new TextDecoder().decode(payload);
                console.log('📨 Text data received:', text);
            }
        });
        
        // Handle participant disconnected
        this.room.on(RoomEvent.ParticipantDisconnected, (participant) => {
            console.log('👋 Participant disconnected:', participant.identity);
            
            // Clean up audio elements
            const audioElement = this.remoteAudioElements.get(participant.sid);
            if (audioElement) {
                audioElement.remove();
                this.remoteAudioElements.delete(participant.sid);
            }
            
            if (participant === this.remoteParticipant) {
                this.agentConnected = false;
                this.updateUI('connected', '⚠️ Sofia Agent getrennt');
            }
        });
        
        // Handle room disconnected
        this.room.on(RoomEvent.Disconnected, (reason) => {
            console.log('🔌 Disconnected from room:', reason);
            this.isConnected = false;
            this.agentConnected = false;
            this.updateUI('', '🤖 Sofia Agent bereit');
            
            // Clean up audio elements
            this.remoteAudioElements.forEach(audio => audio.remove());
            this.remoteAudioElements.clear();
        });
        
        // Handle errors
        this.room.on(RoomEvent.ConnectionQualityChanged, (quality, participant) => {
            if (quality === 'poor') {
                console.warn('⚠️ Poor connection quality for', participant.identity);
            }
        });
        
        // Log initial state
        console.log('📊 Room state after setup:', {
            name: this.room.name,
            localParticipant: this.room.localParticipant?.identity,
            remoteParticipants: this.room.participants ? Array.from(this.room.participants.values()).map(p => p.identity) : []
        });
    }

    handleDataMessage(data, participant) {
        console.log('🔍 Processing data message:', data);
        
        // Handle different message types
        switch (data.type) {
            case 'sofia_response':
                this.showSofiaMessage(data.message);
                if (data.action) {
                    this.handleSofiaAction(data.action, data);
                }
                break;
                
            case 'agent_ready':
                console.log('✅ Agent is ready');
                this.agentConnected = true;
                this.updateUI('connected', '🟢 Sofia ist bereit!');
                this.processPendingMessages();
                break;
                
            case 'thinking':
                this.updateUI('listening', '🤔 Sofia denkt nach...');
                break;
                
            case 'speaking':
                this.updateUI('connected', '🗣️ Sofia spricht...');
                break;
                
            default:
                console.log('Unknown message type:', data.type);
        }
    }

    handleSofiaAction(action, data) {
        console.log('🎯 Handling Sofia action:', action);
        
        switch (action) {
            case 'open_appointment_form':
                this.openAppointmentForm();
                break;
                
            case 'show_available_times':
                this.showAvailableTimes(data.times || []);
                break;
                
            case 'confirm_appointment':
                this.confirmAppointment(data.details);
                break;
                
            case 'show_calendar':
                this.showCalendar(data.date);
                break;
                
            default:
                console.log('Unknown action:', action);
        }
    }

    sendDataMessage(type, data) {
        const message = { type, timestamp: Date.now(), ...data };
        
        if (this.room && this.room.localParticipant && this.isConnected) {
            const messageStr = JSON.stringify(message);
            const encoder = new TextEncoder();
            const encoded = encoder.encode(messageStr);
            
            console.log('📤 Sending data message:', message);
            
            this.room.localParticipant.publishData(encoded, { reliable: true })
                .then(() => console.log('✅ Message sent successfully'))
                .catch(err => {
                    console.error('❌ Failed to send message:', err);
                    this.pendingMessages.push(message);
                });
        } else {
            console.log('📋 Queueing message (not connected):', message);
            this.pendingMessages.push(message);
        }
    }

    processPendingMessages() {
        if (this.pendingMessages.length > 0) {
            console.log(`📤 Processing ${this.pendingMessages.length} pending messages`);
            const messages = [...this.pendingMessages];
            this.pendingMessages = [];
            
            messages.forEach(msg => {
                this.sendDataMessage(msg.type, msg);
            });
        }
    }

    async disconnect() {
        try {
            console.log('🔌 Disconnecting...');
            
            // Send goodbye message
            if (this.agentConnected) {
                this.sendDataMessage('user_disconnecting', {
                    message: 'Auf Wiedersehen'
                });
            }
            
            // Disable tracks
            if (this.room && this.room.localParticipant) {
                await this.room.localParticipant.setMicrophoneEnabled(false);
            }
            
            // Disconnect from room
            if (this.room) {
                await this.room.disconnect();
                this.room = null;
            }
            
            // Clean up audio elements
            this.remoteAudioElements.forEach(audio => audio.remove());
            this.remoteAudioElements.clear();
            
            this.isConnected = false;
            this.agentConnected = false;
            this.updateUI('', '🤖 Sofia Agent bereit');
            
            console.log('✅ Disconnected successfully');
            
        } catch (error) {
            console.error('❌ Disconnect error:', error);
        }
    }

    handleConnectionError(error) {
        console.error('🔴 Connection failed:', error);
        
        if (this.connectionAttempts < this.maxRetries) {
            const retryDelay = Math.min(1000 * Math.pow(2, this.connectionAttempts), 10000);
            this.showError(`Verbindung fehlgeschlagen. Neuer Versuch in ${retryDelay/1000}s...`);
            
            setTimeout(() => {
                console.log(`🔄 Retry attempt ${this.connectionAttempts + 1}/${this.maxRetries}`);
                this.connect();
            }, retryDelay);
        } else {
            this.handleError('Verbindung fehlgeschlagen: ' + error.message);
            this.connectionAttempts = 0;
        }
    }

    // UI Helper Methods
    openAppointmentForm() {
        console.log('📅 Opening appointment form');
        if (typeof openNewAppointmentModal === 'function') {
            openNewAppointmentModal();
        } else {
            console.warn('Appointment modal function not found');
            this.showSofiaMessage('Bitte öffnen Sie das Terminformular manuell.');
        }
    }

    showAvailableTimes(times) {
        const message = times.length > 0 
            ? `Verfügbare Zeiten: ${times.join(', ')}`
            : 'Keine verfügbaren Zeiten gefunden.';
        this.showSofiaMessage(message);
    }

    confirmAppointment(details) {
        const message = `Termin bestätigt: ${details.date} um ${details.time} Uhr`;
        this.showSofiaMessage(message);
    }

    showCalendar(date) {
        console.log('📅 Showing calendar for date:', date);
        // Trigger calendar view if available
        if (typeof showCalendarDate === 'function') {
            showCalendarDate(date);
        }
    }

    showSofiaMessage(message) {
        console.log('💬 Sofia says:', message);
        
        const responseDiv = document.createElement('div');
        responseDiv.className = 'voice-response sofia-message';
        responseDiv.innerHTML = `
            <div class="sofia-avatar">🤖</div>
            <div class="message">
                <strong>Sofia:</strong><br>
                ${message}
            </div>
        `;
        
        // Add animation
        responseDiv.style.opacity = '0';
        responseDiv.style.transform = 'translateY(20px)';
        document.body.appendChild(responseDiv);
        
        // Animate in
        setTimeout(() => {
            responseDiv.style.transition = 'all 0.3s ease-out';
            responseDiv.style.opacity = '1';
            responseDiv.style.transform = 'translateY(0)';
        }, 10);
        
        // Remove after delay
        setTimeout(() => {
            responseDiv.style.opacity = '0';
            responseDiv.style.transform = 'translateY(-20px)';
            setTimeout(() => responseDiv.remove(), 300);
        }, 8000);
    }

    updateUI(className, statusText) {
        if (this.button) {
            this.button.className = `sofia-voice-btn ${className}`;
            
            switch(className) {
                case 'connecting':
                    this.button.innerHTML = '🔄 Verbinde...';
                    this.button.disabled = true;
                    break;
                case 'connected':
                    this.button.innerHTML = '🟢 Sofia aktiv';
                    this.button.disabled = false;
                    break;
                case 'listening':
                    this.button.innerHTML = '🔴 Sofia hört zu...';
                    this.button.disabled = false;
                    break;
                default:
                    this.button.innerHTML = '🤖 Sofia Agent';
                    this.button.disabled = false;
            }
        }
        
        if (this.status) {
            this.status.className = `voice-status ${className}`;
            this.status.textContent = statusText;
        }
    }

    handleError(message) {
        console.error('❌ Sofia Error:', message);
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
        
        errorDiv.style.opacity = '0';
        document.body.appendChild(errorDiv);
        
        setTimeout(() => {
            errorDiv.style.transition = 'all 0.3s ease-out';
            errorDiv.style.opacity = '1';
        }, 10);
        
        setTimeout(() => {
            errorDiv.style.opacity = '0';
            setTimeout(() => errorDiv.remove(), 300);
        }, 5000);
    }

    // Generate test token for development
    async generateTestToken() {
        console.log('⚠️ Using development test token');
        // This token allows connection to 'sofia-room' with devkey/secret
        return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE5OTk5OTk5OTksImlzcyI6ImRldmtleSIsIm5hbWUiOiJjYWxlbmRhci11c2VyIiwibmJmIjoxNjAwMDAwMDAwLCJzdWIiOiJjYWxlbmRhci11c2VyIiwidmlkZW8iOnsicm9vbSI6InNvZmlhLXJvb20iLCJyb29tSm9pbiI6dHJ1ZSwiY2FuUHVibGlzaCI6dHJ1ZSwiY2FuU3Vic2NyaWJlIjp0cnVlLCJjYW5QdWJsaXNoRGF0YSI6dHJ1ZX19.YLbGmPbPp5K3SyLm9NRkz0M4sHHKdCCMQxNUpxPrWgY';
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 Sofia LiveKit Integration wird geladen...');
    console.log('📅 Page loaded at:', new Date().toISOString());
    
    // Debug: Check what's available in window
    console.log('🔍 Checking for LiveKit SDK...');
    const livekitVariants = ['LivekitClient', 'livekitClient', 'LiveKit', 'livekit'];
    livekitVariants.forEach(variant => {
        if (window[variant]) {
            console.log(`✅ Found window.${variant}:`, typeof window[variant]);
        }
    });
    
    // Create global instance
    window.sofiaLiveKit = new SofiaLiveKitIntegration();
    
    // Override the toggle function if it exists
    window.toggleSofiaVoice = async () => {
        console.log('🎤 Toggle Sofia Voice called');
        if (!window.sofiaLiveKit.isConnected && !window.sofiaLiveKit.initialized) {
            await window.sofiaLiveKit.initialize();
        }
        window.sofiaLiveKit.toggleConnection();
    };
    
    // Auto-initialize
    const initialized = await window.sofiaLiveKit.initialize();
    
    if (initialized) {
        console.log('✅ Sofia LiveKit Integration erfolgreich initialisiert!');
        console.log('💡 Click the Sofia button to connect');
    } else {
        console.error('❌ Sofia LiveKit Integration konnte nicht initialisiert werden');
    }
});

// Add CSS for messages
const style = document.createElement('style');
style.textContent = `
.voice-response {
    position: fixed;
    bottom: 100px;
    right: 20px;
    background: white;
    border-radius: 10px;
    padding: 15px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    display: flex;
    align-items: center;
    gap: 10px;
    max-width: 350px;
    z-index: 10000;
}

.voice-response.error {
    border: 2px solid #ff6b6b;
}

.sofia-avatar {
    width: 40px;
    height: 40px;
    background: #4CAF50;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;
}

.voice-response .message {
    flex: 1;
}

.sofia-voice-btn {
    transition: all 0.3s ease;
}

.sofia-voice-btn.connecting {
    background: #FFC107;
    color: white;
}

.sofia-voice-btn.connected {
    background: #4CAF50;
    color: white;
}

.sofia-voice-btn.listening {
    background: #f44336;
    color: white;
    animation: pulse 1.5s infinite;
}

@keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.05); }
    100% { transform: scale(1); }
}
`;
document.head.appendChild(style);