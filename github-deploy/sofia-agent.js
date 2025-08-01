/**
 * Sofia Agent - Direkt im Kalender integriert
 * Deutsche Zahnarzt-Assistentin mit Voice-Funktionalität
 */

class SofiaAgent {
    constructor() {
        this.isActive = false;
        this.isListening = false;
        this.recognition = null;
        this.synthesis = null;
        this.currentConversation = null;
        this.calendarAPI = 'http://localhost:3005/api';
    }

    async initialize() {
        console.log('🤖 Sofia Agent wird initialisiert...');
        
        // Check browser support
        if (!this.checkBrowserSupport()) {
            this.showError('Ihr Browser unterstützt keine Spracherkennung. Bitte verwenden Sie Chrome oder Edge.');
            return false;
        }

        // Initialize speech APIs
        this.initializeSpeechAPIs();
        
        // Setup UI
        this.setupUI();
        
        console.log('✅ Sofia Agent bereit!');
        return true;
    }

    checkBrowserSupport() {
        return ('webkitSpeechRecognition' in window) || ('SpeechRecognition' in window);
    }

    initializeSpeechAPIs() {
        // Speech Recognition
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        this.recognition = new SpeechRecognition();
        this.recognition.lang = 'de-DE';
        this.recognition.continuous = false;
        this.recognition.interimResults = false;
        this.recognition.maxAlternatives = 1;

        // Speech Synthesis
        this.synthesis = window.speechSynthesis;

        // Setup recognition events
        this.setupRecognitionEvents();
    }

    setupRecognitionEvents() {
        this.recognition.onstart = () => {
            console.log('🎤 Sofia hört zu...');
            this.isListening = true;
            this.updateUI('listening', '🎤 Sofia hört zu - sprechen Sie jetzt!');
        };

        this.recognition.onresult = (event) => {
            const transcript = event.results[0][0].transcript;
            console.log('🗣️ Benutzer sagte:', transcript);
            this.processUserInput(transcript);
        };

        this.recognition.onerror = (event) => {
            console.error('Spracherkennungsfehler:', event.error);
            this.handleError('Entschuldigung, ich konnte Sie nicht verstehen. Bitte versuchen Sie es erneut.');
        };

        this.recognition.onend = () => {
            if (this.isActive && this.isListening) {
                // Restart listening after a short delay
                setTimeout(() => {
                    if (this.isActive) {
                        this.recognition.start();
                    }
                }, 1000);
            }
        };
    }

    setupUI() {
        const btn = document.getElementById('sofiaVoiceBtn');
        const status = document.getElementById('voiceStatus');
        
        if (btn) {
            btn.onclick = () => this.toggleAgent();
            btn.innerHTML = '🤖 Sofia Agent';
        }
        
        if (status) {
            status.textContent = '🤖 Sofia Agent bereit';
        }
    }

    async toggleAgent() {
        if (!this.isActive) {
            await this.startAgent();
        } else {
            await this.stopAgent();
        }
    }

    async startAgent() {
        console.log('🚀 Sofia Agent startet...');
        
        this.isActive = true;
        this.updateUI('connected', '🤖 Sofia ist aktiv');
        
        // Greet user
        await this.speak('Hallo! Ich bin Sofia, Ihre Zahnarzt-Assistentin. Wie kann ich Ihnen heute helfen?');
        
        // Start listening
        this.startListening();
    }

    async stopAgent() {
        console.log('🛑 Sofia Agent stoppt...');
        
        this.isActive = false;
        this.isListening = false;
        
        if (this.recognition) {
            this.recognition.stop();
        }
        
        if (this.synthesis) {
            this.synthesis.cancel();
        }
        
        this.updateUI('', '🤖 Sofia Agent bereit');
        
        await this.speak('Auf Wiedersehen! Rufen Sie mich jederzeit wieder.');
    }

    startListening() {
        if (this.isActive && this.recognition) {
            try {
                this.recognition.start();
            } catch (error) {
                console.error('Fehler beim Starten der Spracherkennung:', error);
            }
        }
    }

    async processUserInput(input) {
        console.log('🧠 Sofia verarbeitet:', input);
        
        this.updateUI('processing', '🧠 Sofia denkt...');
        
        const response = await this.generateResponse(input);
        await this.speak(response.text);
        
        if (response.action) {
            await this.executeAction(response.action);
        }
        
        // Return to listening
        setTimeout(() => {
            if (this.isActive) {
                this.updateUI('listening', '🎤 Sofia hört zu...');
            }
        }, 2000);
    }

    async generateResponse(input) {
        const lowerInput = input.toLowerCase();
        
        // Terminbuchung
        if (lowerInput.includes('termin') && (lowerInput.includes('buchen') || lowerInput.includes('vereinbaren'))) {
            return {
                text: 'Gerne helfe ich Ihnen bei der Terminbuchung! Ich öffne das Terminformular für Sie.',
                action: 'open_appointment_form'
            };
        }
        
        // Verfügbare Zeiten
        if (lowerInput.includes('verfügbar') || lowerInput.includes('frei') || lowerInput.includes('zeiten')) {
            const times = await this.getAvailableTimes();
            return {
                text: `Hier sind die verfügbaren Zeiten: ${times}`,
                action: null
            };
        }
        
        // Meine Termine
        if (lowerInput.includes('meine termine') || lowerInput.includes('termine anzeigen')) {
            return {
                text: 'Gerne zeige ich Ihnen Ihre Termine. Wie ist Ihre Telefonnummer?',
                action: 'ask_phone_number'
            };
        }
        
        // Öffnungszeiten
        if (lowerInput.includes('öffnungszeiten') || lowerInput.includes('geöffnet')) {
            return {
                text: 'Unsere Öffnungszeiten sind Montag bis Freitag von 8 bis 18 Uhr, Samstag von 9 bis 13 Uhr. Sonntag haben wir geschlossen.',
                action: 'show_opening_hours'
            };
        }
        
        // Hilfe
        if (lowerInput.includes('hilfe') || lowerInput.includes('help')) {
            return {
                text: 'Ich kann Ihnen bei folgenden Dingen helfen: Termine buchen, verfügbare Zeiten anzeigen, Ihre Termine anzeigen, oder Praxisinformationen geben.',
                action: 'show_help'
            };
        }
        
        // Begrüßung
        if (lowerInput.includes('hallo') || lowerInput.includes('hi') || lowerInput.includes('guten')) {
            return {
                text: 'Hallo! Schön, dass Sie da sind. Wie kann ich Ihnen heute helfen?',
                action: null
            };
        }
        
        // Standard Antwort
        return {
            text: 'Entschuldigung, das habe ich nicht verstanden. Ich kann Ihnen bei Terminen, verfügbaren Zeiten oder Praxisinformationen helfen. Sagen Sie einfach "Hilfe" für mehr Optionen.',
            action: null
        };
    }

    async executeAction(action) {
        switch (action) {
            case 'open_appointment_form':
                setTimeout(() => {
                    if (typeof openNewAppointmentModal === 'function') {
                        openNewAppointmentModal();
                    }
                }, 1000);
                break;
                
            case 'show_opening_hours':
                this.showResponse('🕒 Öffnungszeiten:<br>Mo-Fr: 8:00-18:00 Uhr<br>Sa: 9:00-13:00 Uhr<br>So: Geschlossen');
                break;
                
            case 'show_help':
                this.showResponse('Ich kann helfen bei:<br>• Termine buchen<br>• Verfügbare Zeiten<br>• Ihre Termine<br>• Praxisinformationen');
                break;
        }
    }

    async getAvailableTimes() {
        try {
            const tomorrow = new Date();
            tomorrow.setDate(tomorrow.getDate() + 1);
            const dateStr = tomorrow.toISOString().split('T')[0];
            
            const response = await fetch(`${this.calendarAPI}/appointments`);
            if (response.ok) {
                // Simulate available times
                return 'Morgen um 9:00, 10:30, 14:00, 15:30 und 16:00 Uhr';
            }
        } catch (error) {
            console.error('Fehler beim Abrufen der Zeiten:', error);
        }
        
        return 'Morgen um 9:00, 10:30, 14:00, 15:30 und 16:00 Uhr';
    }

    async speak(text) {
        return new Promise((resolve) => {
            if (this.synthesis) {
                // Cancel any ongoing speech
                this.synthesis.cancel();
                
                const utterance = new SpeechSynthesisUtterance(text);
                utterance.lang = 'de-DE';
                utterance.rate = 0.9;
                utterance.pitch = 1.1;
                utterance.volume = 0.8;
                
                // Try to use a German voice
                const voices = this.synthesis.getVoices();
                const germanVoice = voices.find(voice => 
                    voice.lang.includes('de') && voice.name.toLowerCase().includes('female')
                ) || voices.find(voice => voice.lang.includes('de'));
                
                if (germanVoice) {
                    utterance.voice = germanVoice;
                }
                
                utterance.onend = () => resolve();
                utterance.onerror = () => resolve();
                
                this.synthesis.speak(utterance);
                
                // Also show visual response
                this.showResponse(text);
            } else {
                resolve();
            }
        });
    }

    updateUI(className, statusText) {
        const btn = document.getElementById('sofiaVoiceBtn');
        const status = document.getElementById('voiceStatus');
        
        if (btn) {
            btn.className = `sofia-voice-btn ${className}`;
            
            if (className === 'listening') {
                btn.innerHTML = '🔴 Sofia hört zu...';
            } else if (className === 'processing') {
                btn.innerHTML = '🧠 Sofia denkt...';
            } else if (className === 'connected') {
                btn.innerHTML = '🤖 Sofia aktiv';
            } else {
                btn.innerHTML = '🤖 Sofia Agent';
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
                <strong>Sofia sagt:</strong><br>
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
        console.error('Sofia Fehler:', message);
        this.showError(message);
        this.updateUI('', '🤖 Sofia Agent bereit');
        this.isListening = false;
    }
}

// Initialize Sofia Agent when page loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 Sofia Agent wird geladen...');
    
    window.sofiaAgent = new SofiaAgent();
    const initialized = await window.sofiaAgent.initialize();
    
    if (initialized) {
        console.log('✅ Sofia Agent erfolgreich geladen!');
        
        // Override the toggle function
        window.toggleSofiaVoice = () => {
            window.sofiaAgent.toggleAgent();
        };
    }
});
