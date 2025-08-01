/**
 * Sofia LiveKit Integration - FIXED VERSION
 * Addresses the "Cannot read properties of undefined (reading 'values')" error
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
        
        // LiveKit SDK reference
        this.LiveKit = null;
    }

    async initialize() {
        console.log('🎤 Initializing Sofia LiveKit Integration (Fixed Version)...');
        
        try {
            // Setup UI
            this.setupUI();
            
            // Fix SDK reference issue with multiple fallbacks
            this.LiveKit = this.findLiveKitSDK();
            
            if (!this.LiveKit) {
                throw new Error('LiveKit Client not loaded. Available globals: ' + 
                    Object.keys(window).filter(k => k.toLowerCase().includes('live')).join(', '));
            }
            
            console.log('✅ LiveKit SDK found and configured');
            console.log('📦 Available components:', Object.keys(this.LiveKit).slice(0, 10));
            
            return true;
            
        } catch (error) {
            console.error('❌ Failed to initialize Sofia LiveKit Integration:', error);
            this.showError('Sofia Integration konnte nicht initialisiert werden: ' + error.message);
            return false;
        }
    }

    findLiveKitSDK() {
        // Try multiple possible SDK locations for newer versions
        const candidates = [
            window.LivekitClient,
            window.livekitClient,
            window.LiveKit,
            window.livekit,
            window.LiveKitClient // Added for newer versions
        ];
        
        for (const candidate of candidates) {
            if (candidate && candidate.Room && candidate.RoomEvent) {
                console.log('✅ Found LiveKit SDK:', candidate.constructor?.name || 'LiveKit');
                return candidate;
            }
        }
        
        // Check if it's nested (common in UMD builds)
        if (window.LivekitClient?.LivekitClient) {
            return window.LivekitClient.LivekitClient;
        }
        
        // Check for ES6 module format
        const globalKeys = Object.keys(window).filter(k => k.toLowerCase().includes('livekit'));
        console.log('🔍 Available LiveKit globals:', globalKeys);
        
        // Try each global that contains 'livekit'
        for (const key of globalKeys) {
            const candidate = window[key];
            if (candidate && typeof candidate === 'object' && candidate.Room && candidate.RoomEvent) {
                console.log('✅ Found LiveKit SDK via search:', key);
                return candidate;
            }
        }
        
        return null;
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
            
            console.log('🚀 Starting connection process...');
            
            // Get token for the room
            this.token = await this.getToken('sofia-room');
            console.log('✅ Token obtained');
            
            // Create LiveKit room with safe configuration
            this.room = new this.LiveKit.Room({
                adaptiveStream: true,
                dynacast: true
            });
            
            console.log('✅ Room object created');
            
            // Setup comprehensive event handlers BEFORE connecting
            this.setupRoomEvents();
            console.log('✅ Event handlers configured');
            
            // Connect to room
            console.log('🔌 Connecting to LiveKit server...');
            await this.room.connect(this.livekitUrl, this.token);
            
            console.log('✅ Room connection initiated - waiting for Connected event...');
            
        } catch (error) {
            console.error('❌ Connection error:', error);
            this.handleConnectionError(error);
        }
    }

    getRemoteParticipantCount() {
        try {
            if (!this.room) return 0;
            
            // Handle different LiveKit versions
            if (this.room.participants) {
                // Map object with size property
                if (typeof this.room.participants.size === 'number') {
                    return this.room.participants.size;
                }
                // Map object with values() method
                if (typeof this.room.participants.values === 'function') {
                    return Array.from(this.room.participants.values()).length;
                }
                // Plain object
                if (typeof this.room.participants === 'object') {
                    return Object.keys(this.room.participants).length;
                }
            }
            
            // Alternative: use remoteParticipants property (newer versions)
            if (this.room.remoteParticipants) {
                if (typeof this.room.remoteParticipants.size === 'number') {
                    return this.room.remoteParticipants.size;
                }
                if (typeof this.room.remoteParticipants.values === 'function') {
                    return Array.from(this.room.remoteParticipants.values()).length;
                }
            }
            
            return 0;
        } catch (error) {
            console.warn('⚠️ Could not get participant count:', error.message);
            return 0;
        }
    }

    getRemoteParticipants() {
        try {
            if (!this.room) return [];
            
            // Handle different LiveKit versions
            if (this.room.participants) {
                // Map object with values() method
                if (typeof this.room.participants.values === 'function') {
                    return Array.from(this.room.participants.values());
                }
                // Plain object
                if (typeof this.room.participants === 'object') {
                    return Object.values(this.room.participants);
                }
            }
            
            // Alternative: use remoteParticipants property (newer versions)
            if (this.room.remoteParticipants) {
                if (typeof this.room.remoteParticipants.values === 'function') {
                    return Array.from(this.room.remoteParticipants.values());
                }
                if (typeof this.room.remoteParticipants === 'object') {
                    return Object.values(this.room.remoteParticipants);
                }
            }
            
            return [];
        } catch (error) {
            console.warn('⚠️ Could not get participants:', error.message);
            return [];
        }
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
            } else {
                throw new Error(`Token request failed: ${response.status}`);
            }
        } catch (error) {
            console.error('Token request failed:', error);
            throw error;
        }
    }

    setupRoomEvents() {
        if (!this.room || !this.LiveKit) {
            console.error('Cannot setup events: room or LiveKit not available');
            return;
        }

        const RoomEvent = this.LiveKit.RoomEvent;
        
        // Connection state monitoring - CRITICAL: All participant access must be here
        this.room.on(RoomEvent.Connected, async () => {
            console.log('✅ Room Connected event fired - now safe to access participants');
            this.connectionAttempts = 0;
            
            // NOW it's safe to access room properties
            console.log('🏠 Connected to room:', this.room.name);
            console.log('👤 Local participant:', this.room.localParticipant?.identity);
            
            // Safely check remote participants
            const remoteCount = this.getRemoteParticipantCount();
            console.log('👥 Remote participants:', remoteCount);
            
            // Enable microphone with proper error handling
            try {
                console.log('🎤 Enabling microphone...');
                await this.room.localParticipant.setMicrophoneEnabled(true);
                console.log('✅ Microphone enabled');
            } catch (micError) {
                console.error('❌ Microphone error:', micError);
                this.showError('Mikrofon konnte nicht aktiviert werden. Bitte Berechtigungen prüfen.');
            }
            
            // Mark as connected and update UI
            this.isConnected = true;
            this.updateUI('connected', '🟢 Mit Sofia verbunden - bereit für Sprache');
            
            // Send initial message to Sofia agent
            this.sendDataMessage('user_ready', {
                message: 'Calendar user connected and ready',
                interface: 'web-browser',
                timestamp: new Date().toISOString()
            });
            
            console.log('✅ Full connection setup completed successfully');
        });
        
        this.room.on(RoomEvent.ConnectionStateChanged, (state) => {
            console.log('📡 Connection state:', state);
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
                           (participant.metadata && participant.metadata.includes('agent')) ||
                           (participant.metadata && participant.metadata.includes('dental'));
            
            if (isSofia) {
                this.remoteParticipant = participant;
                this.agentConnected = true;
                this.updateUI('connected', '🟢 Sofia Agent verbunden!');
                console.log('🤖 Sofia agent detected and connected!');
                
                // Process any pending messages
                this.processPendingMessages();
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
            
            if (track.kind === this.LiveKit.Track.Kind.Audio || track.kind === 'audio') {
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
                    const playOnClick = () => {
                        audioElement.play();
                        this.button?.removeEventListener('click', playOnClick);
                    };
                    this.button?.addEventListener('click', playOnClick, { once: true });
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
        });
        
        // Handle data received
        this.room.on(RoomEvent.DataReceived, (payload, participant) => {
            try {
                const data = JSON.parse(new TextDecoder().decode(payload));
                console.log('📨 Data received from', participant.identity, ':', data);
                this.handleDataMessage(data, participant);
            } catch (error) {
                console.error('Error parsing data:', error);
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
        
        console.log('✅ All event handlers configured');
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
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 Sofia LiveKit Integration (Fixed) wird geladen...');
    
    // Wait for other scripts to load
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Create global instance
    window.sofiaLiveKit = new SofiaLiveKitIntegration();
    
    // Override the toggle function
    window.toggleSofiaVoice = async () => {
        console.log('🎤 Toggle Sofia Voice called (Fixed Version)');
        if (!window.sofiaLiveKit.initialized) {
            const success = await window.sofiaLiveKit.initialize();
            if (!success) {
                console.error('Failed to initialize Sofia integration');
                return;
            }
        }
        window.sofiaLiveKit.toggleConnection();
    };
    
    // Auto-initialize
    const initialized = await window.sofiaLiveKit.initialize();
    
    if (initialized) {
        console.log('✅ Sofia LiveKit Integration (Fixed) erfolgreich initialisiert!');
        console.log('💡 Click the Sofia button to connect');
    } else {
        console.error('❌ Sofia LiveKit Integration konnte nicht initialisiert werden');
    }
});

// Add CSS styles
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

// Initialize Sofia Console Integration
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🎤 Initializing Sofia LiveKit Integration (Fixed Version)...');
    
    try {
        window.sofiaConsole = new SofiaLiveKitIntegration();
        const success = await window.sofiaConsole.initialize();
        
        if (success) {
            console.log('✅ Sofia Console Integration ready');
        } else {
            console.error('❌ Sofia Console Integration failed to initialize');
        }
    } catch (error) {
        console.error('❌ Sofia Console Integration initialization error:', error);
    }
});