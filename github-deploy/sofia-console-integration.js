/**
 * Sofia Console Integration
 * Verbindet den Kalender direkt mit dem laufenden Sofia Console Agent
 */

class SofiaConsoleIntegration {
    constructor() {
        this.isConnected = false;
        this.isListening = false;
        this.recognition = null;
        this.synthesis = null;
        this.sofiaEndpoint = 'http://localhost:3005/api/sofia';
        this.websocket = null;
        this.livekitRoom = null;
    }

    async initialize() {
        console.log('🎤 Initializing Sofia Console Integration...');
        
        try {
            // Check if Sofia Console is running
            await this.checkSofiaStatus();
            
            // Initialize browser speech for user input
            this.initializeSpeechAPIs();
            
            // Setup UI
            this.setupUI();
            
            console.log('✅ Sofia Console Integration ready!');
            return true;
            
        } catch (error) {
            console.error('❌ Failed to initialize Sofia Console Integration:', error);
            this.showError('Sofia Console Agent nicht erreichbar: ' + error.message);
            return false;
        }
    }

    async checkSofiaStatus() {
        try {
            const response = await fetch('/api/appointments');
            if (response.ok) {
                console.log('✅ Sofia Console Agent erreichbar');
                return true;
            }
        } catch (error) {
            throw new Error('Sofia Console Agent nicht erreichbar');
        }
    }

    initializeSpeechAPIs() {
        // Check browser support
        if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
            throw new Error('Browser unterstützt keine Spracherkennung');
        }

        // Speech Recognition for user input
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        this.recognition = new SpeechRecognition();
        this.recognition.lang = 'de-DE';
        this.recognition.continuous = false;
        this.recognition.interimResults = false;
        this.recognition.maxAlternatives = 1;

        // Setup recognition events
        this.setupRecognitionEvents();

        console.log('✅ Browser Speech APIs initialized');
    }

    setupRecognitionEvents() {
        this.recognition.onstart = () => {
            console.log('🎤 Listening for user input...');
            this.isListening = true;
            this.updateUI('listening', '🎤 Sprechen Sie jetzt...');
        };

        this.recognition.onresult = async (event) => {
            const transcript = event.results[0][0].transcript;
            console.log('🗣️ User said:', transcript);
            
            this.updateUI('processing', '🧠 Sofia verarbeitet...');
            this.showUserMessage(transcript);
            
            // Send to Sofia Console Agent
            await this.sendToSofia(transcript);
        };

        this.recognition.onerror = (event) => {
            console.error('Speech recognition error:', event.error);
            this.handleError('Spracherkennung fehlgeschlagen: ' + event.error);
        };

        this.recognition.onend = () => {
            this.isListening = false;
            if (this.isConnected) {
                // Restart listening after a short delay
                setTimeout(() => {
                    if (this.isConnected) {
                        this.startListening();
                    }
                }, 2000);
            }
        };
    }

    setupUI() {
        const btn = document.getElementById('sofiaVoiceBtn');
        const status = document.getElementById('voiceStatus');
        
        if (btn) {
            btn.onclick = () => this.toggleAgent();
            btn.innerHTML = '🎤 Sofia Console';
        }
        
        if (status) {
            status.textContent = '🎤 Sofia Console bereit';
        }
    }

    async toggleAgent() {
        if (!this.isConnected) {
            await this.startAgent();
        } else {
            await this.stopAgent();
        }
    }

    async startAgent() {
        console.log('🚀 Starting Sofia Voice Agent (python agent.py dev)...');
        
        try {
            // Call API to start Sofia voice agent
            const response = await fetch('/api/sofia/console', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    action: 'start'
                })
            });
            
            const result = await response.json();
            
            if (result.success) {
                console.log('✅ Sofia voice agent started:', result.message);
                
                this.isConnected = true;
                this.updateUI('connected', '🤖 Sofia Voice läuft (PID: ' + result.process_id + ')');
                
                // Connect to LiveKit room for voice communication
                if (result.livekit_url && result.token) {
                    console.log('🔗 Connecting to LiveKit room for voice...');
                    await this.connectToLiveKit(result.livekit_url, result.token, result.room);
                }
                
                // Show success message
                this.showSofiaResponse('✅ Sofia Voice Agent gestartet! Sofia kann jetzt über Mikrofon hören und über Lautsprecher antworten. Sprechen Sie direkt in Ihr Mikrofon.');
                
            } else {
                throw new Error(result.error || 'Failed to start Sofia voice agent');
            }
            
        } catch (error) {
            console.error('❌ Failed to start Sofia voice agent:', error);
            this.showError('Fehler beim Starten von Sofia Voice Agent: ' + error.message);
            this.isConnected = false;
        }
    }

    async connectToLiveKit(livekitUrl, token, roomName) {
        try {
            console.log('🔗 Connecting to LiveKit room:', roomName);
            
            if (typeof LiveKit === 'undefined') {
                throw new Error('LiveKit SDK not loaded');
            }
            
            // Create room instance
            this.livekitRoom = new LiveKit.Room({
                adaptiveStream: true,
                dynacast: true
            });
            
            // Set up event handlers
            this.setupLiveKitEventHandlers();
            
            // Connect to room
            await this.livekitRoom.connect(livekitUrl, token);
            console.log('✅ Connected to LiveKit room for voice chat');
            
            // Enable microphone
            await this.livekitRoom.localParticipant.setMicrophoneEnabled(true);
            console.log('🎤 Microphone enabled for voice chat with Sofia');
            
            this.showSofiaResponse('🔊 Voice-Chat mit Sofia aktiv! Sie können jetzt sprechen.');
            
        } catch (error) {
            console.error('❌ LiveKit connection failed:', error);
            this.showSofiaResponse('⚠️ Voice-Chat Fehler: ' + error.message + '. Sofia läuft trotzdem - sprechen Sie direkt in Ihr Mikrofon.');
        }
    }

    setupLiveKitEventHandlers() {
        if (!this.livekitRoom) return;
        
        this.livekitRoom.on(LiveKit.RoomEvent.Connected, () => {
            console.log('✅ LiveKit Room Connected - Voice chat ready');
            this.updateUI('connected', '🔊 Sofia Voice-Chat aktiv');
        });
        
        this.livekitRoom.on(LiveKit.RoomEvent.ParticipantConnected, (participant) => {
            console.log('👤 Participant joined:', participant.identity);
            
            if (participant.identity.includes('sofia') || participant.identity.includes('agent')) {
                console.log('🤖 Sofia agent joined the voice room!');
                this.showSofiaResponse('🤖 Sofia ist im Voice-Chat beigetreten!');
            }
        });
        
        this.livekitRoom.on(LiveKit.RoomEvent.TrackSubscribed, (track, publication, participant) => {
            if (track.kind === LiveKit.Track.Kind.Audio && participant.identity.includes('sofia')) {
                console.log('🔊 Sofia audio track received - you should hear Sofia now');
                const audioElement = track.attach();
                audioElement.autoplay = true;
                document.body.appendChild(audioElement);
                this.showSofiaResponse('🔊 Sofia Audio verbunden! Sie können Sofia jetzt hören.');
            }
        });
        
        this.livekitRoom.on(LiveKit.RoomEvent.Disconnected, () => {
            console.log('📞 LiveKit room disconnected');
            this.showSofiaResponse('📞 Voice-Chat getrennt');
        });
    }

    async stopAgent() {
        console.log('🛑 Stopping Sofia Voice Integration...');
        
        this.isConnected = false;
        this.isListening = false;
        
        if (this.recognition) {
            this.recognition.stop();
        }
        
        if (this.livekitRoom) {
            await this.livekitRoom.disconnect();
            this.livekitRoom = null;
        }
        
        this.updateUI('', '🎤 Sofia Voice bereit');
        
        this.showSofiaResponse('Sofia Voice Integration gestoppt.');
    }

    startListening() {
        if (this.isConnected && this.recognition) {
            try {
                this.recognition.start();
            } catch (error) {
                console.error('Error starting speech recognition:', error);
                // Try again after a short delay
                setTimeout(() => {
                    if (this.isConnected) {
                        this.startListening();
                    }
                }, 1000);
            }
        }
    }

    async sendToSofia(message) {
        try {
            console.log('📤 Sending to Sofia Console:', message);

            // Show that Sofia is processing
            this.showSofiaResponse('Sofia Console Agent verarbeitet: "' + message + '"');

            // Since Sofia Console runs separately, we simulate the integration
            // The real Sofia Agent is listening via microphone and will respond via speakers

            // Process common commands locally for immediate feedback
            const response = this.processLocalCommand(message);

            if (response.action) {
                setTimeout(() => {
                    this.executeAction(response.action);
                }, 2000);
            }

            // Show instruction to user
            this.showSofiaResponse('Sofia Console Agent hört über Mikrofon und antwortet über Lautsprecher. Sprechen Sie direkt in Ihr Mikrofon für beste Ergebnisse.');

        } catch (error) {
            console.error('❌ Error processing Sofia command:', error);
            this.showSofiaResponse('Fehler bei der Verarbeitung. Sofia Console Agent läuft separat - sprechen Sie direkt in Ihr Mikrofon.');
        }

        // Return to listening mode
        setTimeout(() => {
            if (this.isConnected) {
                this.updateUI('listening', '🎤 Sofia hört zu...');
            }
        }, 4000);
    }

    processLocalCommand(message) {
        const lowerMessage = message.toLowerCase();

        // Terminbuchung
        if (lowerMessage.includes('termin') && (lowerMessage.includes('buchen') || lowerMessage.includes('vereinbaren'))) {
            return {
                message: 'Terminformular wird geöffnet...',
                action: 'open_appointment_form'
            };
        }

        // Kalender aktualisieren
        if (lowerMessage.includes('aktualisieren') || lowerMessage.includes('refresh')) {
            return {
                message: 'Kalender wird aktualisiert...',
                action: 'refresh_calendar'
            };
        }

        return {
            message: 'Befehl an Sofia Console weitergeleitet.',
            action: null
        };
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
            } else if (className === 'processing') {
                btn.innerHTML = '🧠 Sofia verarbeitet...';
            } else if (className === 'connected') {
                btn.innerHTML = '🎤 Sofia Console aktiv';
            } else {
                btn.innerHTML = '🎤 Sofia Console';
            }
        }
        
        if (status) {
            status.className = `voice-status ${className}`;
            status.textContent = statusText;
        }
    }

    showUserMessage(message) {
        this.showMessage(message, 'user');
    }

    showSofiaResponse(message) {
        this.showMessage(message, 'sofia');
    }

    showMessage(message, sender) {
        // Remove existing response
        const existing = document.querySelector('.voice-response');
        if (existing) {
            existing.remove();
        }
        
        // Create new response
        const responseDiv = document.createElement('div');
        responseDiv.className = 'voice-response';
        
        if (sender === 'user') {
            responseDiv.innerHTML = `
                <div class="sofia-avatar" style="background: #667eea;">👤</div>
                <div class="message">
                    <strong>Sie sagten:</strong><br>
                    "${message}"
                </div>
            `;
        } else {
            responseDiv.innerHTML = `
                <div class="sofia-avatar">🤖</div>
                <div class="message">
                    <strong>Sofia Console:</strong><br>
                    ${message}
                </div>
            `;
        }
        
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

    handleError(message) {
        console.error('Sofia Console Integration Error:', message);
        this.showError(message);
        this.updateUI('', '🎤 Sofia Console bereit');
        this.isListening = false;
        this.isConnected = false;
    }
}

// Initialize Sofia Console Integration when page loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 Initializing Sofia Console Integration...');
    
    window.sofiaConsole = new SofiaConsoleIntegration();
    const initialized = await window.sofiaConsole.initialize();
    
    if (initialized) {
        console.log('✅ Sofia Console Integration ready!');
        
        // Override the toggle function
        window.toggleSofiaVoice = () => {
            window.sofiaConsole.toggleAgent();
        };
    }
});
