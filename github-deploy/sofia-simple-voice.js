// Simple Sofia Voice Integration without LiveKit
class SofiaSimpleVoice {
    constructor() {
        this.isConnected = false;
        this.isRecording = false;
        this.mediaRecorder = null;
        this.audioChunks = [];
        this.recognition = null;
        this.ws = null;
    }

    async initialize() {
        console.log('Initializing Sofia Simple Voice...');
        
        // Setup speech recognition
        if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
            const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
            this.recognition = new SpeechRecognition();
            this.recognition.lang = 'de-DE'; // German by default
            this.recognition.continuous = true;
            this.recognition.interimResults = true;
            
            this.recognition.onresult = (event) => {
                const transcript = Array.from(event.results)
                    .map(result => result[0].transcript)
                    .join('');
                
                if (event.results[event.results.length - 1].isFinal) {
                    this.handleUserSpeech(transcript);
                } else {
                    this.updateStatus(`Sie sagen: "${transcript}"`, true);
                }
            };
            
            this.recognition.onerror = (event) => {
                console.error('Speech recognition error:', event.error);
                this.updateStatus('Spracherkennung Fehler: ' + event.error, false);
            };
        }
        
        // Connect to Sofia through the calendar server
        this.connectWebSocket();
    }

    connectWebSocket() {
        try {
            // Use existing socket.io connection instead of raw WebSocket
            if (window.socket) {
                this.ws = window.socket;
                console.log('Using existing Socket.io connection');
                this.isConnected = true;
                this.updateStatus('Mit Sofia verbunden', true);
                this.addMessage('system', 'Verbindung hergestellt');
            }
        } catch (error) {
            console.error('WebSocket connection error:', error);
        }
    }

    async toggleVoice() {
        const btn = document.getElementById('sofiaAgentBtn');
        const sofiaInterface = document.getElementById('sofiaInterface');
        
        if (this.isRecording) {
            // Stop recording
            this.stopListening();
            btn.classList.remove('active');
            btn.innerHTML = '<span class="sofia-icon">🎧</span> Sofia Agent';
            sofiaInterface.classList.remove('visible');
        } else {
            // Start recording
            sofiaInterface.classList.add('visible');
            await this.startListening();
            btn.classList.add('active');
            btn.innerHTML = '<span class="sofia-icon">🔴</span> Verbunden';
            
            // Send greeting
            this.addMessage('sofia', 'Hallo! Ich bin Sofia, Ihre mehrsprachige Zahnarzt-Assistentin. Wie kann ich Ihnen helfen?');
        }
    }

    async startListening() {
        try {
            // Request microphone permission
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            
            // Start speech recognition
            if (this.recognition) {
                this.recognition.start();
                this.isRecording = true;
                this.updateStatus('Höre zu...', true);
            }
            
            // Alternative: Use MediaRecorder for audio chunks
            this.mediaRecorder = new MediaRecorder(stream);
            this.mediaRecorder.ondataavailable = (event) => {
                this.audioChunks.push(event.data);
            };
            
            console.log('Started listening');
        } catch (error) {
            console.error('Error accessing microphone:', error);
            this.addMessage('error', 'Mikrofon konnte nicht aktiviert werden: ' + error.message);
        }
    }

    stopListening() {
        if (this.recognition) {
            this.recognition.stop();
        }
        if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
            this.mediaRecorder.stop();
        }
        this.isRecording = false;
        this.updateStatus('Gestoppt', false);
    }

    handleUserSpeech(transcript) {
        console.log('User said:', transcript);
        this.addMessage('user', transcript);
        
        // Process locally for quick actions and get Sofia's response
        this.processLocalCommand(transcript);
    }

    handleSofiaResponse(data) {
        if (data.type === 'sofia_response') {
            this.addMessage('sofia', data.text);
            // Use speech synthesis to speak the response
            this.speak(data.text, data.language || 'de-DE');
        } else if (data.type === 'appointment_created') {
            this.addMessage('sofia', `Termin erstellt: ${data.appointment.patient_name} am ${data.appointment.date}`);
            if (typeof refreshCalendar === 'function') {
                refreshCalendar();
            }
        }
    }

    processLocalCommand(text) {
        const lowerText = text.toLowerCase();
        
        // Detect appointment booking intent
        if (lowerText.includes('termin') && (lowerText.includes('buchen') || lowerText.includes('vereinbaren'))) {
            const response = 'Gerne helfe ich Ihnen bei der Terminbuchung. Für welchen Tag möchten Sie einen Termin?';
            this.addMessage('sofia', response);
            this.speak(response, this.recognition.lang);
        }
        // Detect availability check
        else if (lowerText.includes('frei') || lowerText.includes('verfügbar')) {
            this.checkAvailability();
        }
        // Check for greetings
        else if (lowerText.match(/hallo|guten tag|guten morgen|hi|hello|ciao|buongiorno/)) {
            const responses = {
                'de-DE': 'Hallo! Ich bin Sofia, Ihre Zahnarzt-Assistentin. Wie kann ich Ihnen heute helfen?',
                'en-US': 'Hello! I\'m Sofia, your dental assistant. How can I help you today?',
                'it-IT': 'Ciao! Sono Sofia, la tua assistente dentale. Come posso aiutarti oggi?'
            };
            const response = responses[this.recognition.lang] || responses['de-DE'];
            this.addMessage('sofia', response);
            this.speak(response, this.recognition.lang);
        }
        // Check for appointment queries
        else if (lowerText.match(/wann|quando|when/) && lowerText.match(/termin|appointment|appuntamento/)) {
            const response = 'Einen Moment, ich prüfe die verfügbaren Termine für Sie...';
            this.addMessage('sofia', response);
            this.speak(response, this.recognition.lang);
            this.checkAvailability();
        }
        // Check for treatment questions
        else if (lowerText.match(/behandlung|treatment|trattamento|zahnreinigung|füllung|krone/)) {
            const responses = {
                'de-DE': 'Wir bieten verschiedene Behandlungen an: Kontrolle, Zahnreinigung, Füllungen, Wurzelbehandlung und mehr. Für welche Behandlung interessieren Sie sich?',
                'en-US': 'We offer various treatments: check-ups, teeth cleaning, fillings, root canals and more. Which treatment are you interested in?',
                'it-IT': 'Offriamo vari trattamenti: controlli, pulizia dei denti, otturazioni, devitalizzazioni e altro. Quale trattamento ti interessa?'
            };
            const response = responses[this.recognition.lang] || responses['de-DE'];
            this.addMessage('sofia', response);
            this.speak(response, this.recognition.lang);
        }
        // Language switching
        else if (lowerText.includes('english') || lowerText.includes('inglese')) {
            this.recognition.lang = 'en-US';
            // Restart recognition with new language
            if (this.isRecording) {
                this.recognition.stop();
                setTimeout(() => {
                    this.recognition.start();
                }, 100);
            }
            this.addMessage('sofia', 'Switching to English. How can I help you?');
            this.speak('Switching to English. How can I help you?', 'en-US');
        }
        else if (lowerText.includes('italiano') || lowerText.includes('italienisch')) {
            this.recognition.lang = 'it-IT';
            // Restart recognition with new language
            if (this.isRecording) {
                this.recognition.stop();
                setTimeout(() => {
                    this.recognition.start();
                }, 100);
            }
            this.addMessage('sofia', 'Passo all\'italiano. Come posso aiutarla?');
            this.speak('Passo all\'italiano. Come posso aiutarla?', 'it-IT');
        }
        else if (lowerText.includes('deutsch') || lowerText.includes('german')) {
            this.recognition.lang = 'de-DE';
            // Restart recognition with new language
            if (this.isRecording) {
                this.recognition.stop();
                setTimeout(() => {
                    this.recognition.start();
                }, 100);
            }
            this.addMessage('sofia', 'Ich spreche jetzt Deutsch. Wie kann ich Ihnen helfen?');
            this.speak('Ich spreche jetzt Deutsch. Wie kann ich Ihnen helfen?', 'de-DE');
        }
        // Default response for unrecognized commands
        else {
            const responses = {
                'de-DE': 'Entschuldigung, ich habe das nicht ganz verstanden. Ich kann Ihnen bei Terminbuchungen, Behandlungsinformationen und allgemeinen Fragen zur Praxis helfen.',
                'en-US': 'Sorry, I didn\'t quite understand that. I can help you with appointment bookings, treatment information, and general practice questions.',
                'it-IT': 'Scusi, non ho capito bene. Posso aiutarti con prenotazioni, informazioni sui trattamenti e domande generali sulla clinica.'
            };
            const response = responses[this.recognition.lang] || responses['de-DE'];
            this.addMessage('sofia', response);
            this.speak(response, this.recognition.lang);
        }
    }

    getLanguageFromText(text) {
        // Simple language detection
        const germanWords = ['ich', 'der', 'die', 'das', 'und', 'ist', 'bin', 'habe'];
        const englishWords = ['the', 'and', 'is', 'are', 'have', 'has', 'will', 'would'];
        const italianWords = ['il', 'la', 'sono', 'ho', 'che', 'per', 'con', 'una'];
        
        const words = text.toLowerCase().split(/\s+/);
        
        let germanCount = words.filter(w => germanWords.includes(w)).length;
        let englishCount = words.filter(w => englishWords.includes(w)).length;
        let italianCount = words.filter(w => italianWords.includes(w)).length;
        
        if (englishCount > germanCount && englishCount > italianCount) return 'en';
        if (italianCount > germanCount && italianCount > englishCount) return 'it';
        return 'de';
    }

    async checkAvailability() {
        try {
            const response = await fetch('/api/sofia/next-available');
            const data = await response.json();
            this.addMessage('sofia', data.message);
            this.speak(data.message, this.recognition.lang);
        } catch (error) {
            const errorMsg = 'Entschuldigung, ich kann gerade nicht auf die Terminverfügbarkeit zugreifen. Bitte versuchen Sie es später erneut.';
            this.addMessage('sofia', errorMsg);
            this.speak(errorMsg, this.recognition.lang);
        }
    }

    speak(text, lang = 'de-DE') {
        if ('speechSynthesis' in window) {
            const utterance = new SpeechSynthesisUtterance(text);
            utterance.lang = lang;
            utterance.rate = 0.9;
            utterance.pitch = 1.1;
            
            // Try to find a female voice
            const voices = speechSynthesis.getVoices();
            const femaleVoice = voices.find(v => 
                v.lang.startsWith(lang.substring(0, 2)) && 
                (v.name.includes('female') || v.name.includes('Female') || v.name.includes('woman'))
            );
            
            if (femaleVoice) {
                utterance.voice = femaleVoice;
            }
            
            speechSynthesis.speak(utterance);
        }
    }

    addMessage(type, text) {
        const chat = document.getElementById('sofiaChat');
        if (!chat) return;
        
        const messageDiv = document.createElement('div');
        messageDiv.className = `sofia-message ${type}`;
        
        const time = new Date().toLocaleTimeString('de-DE', { 
            hour: '2-digit', 
            minute: '2-digit' 
        });
        
        if (type === 'sofia') {
            messageDiv.innerHTML = `
                <div style="font-weight: bold; margin-bottom: 4px;">Sofia</div>
                <div>${text}</div>
                <div style="font-size: 0.8em; opacity: 0.7; margin-top: 4px;">${time}</div>
            `;
        } else if (type === 'user') {
            messageDiv.innerHTML = `
                <div>${text}</div>
                <div style="font-size: 0.8em; opacity: 0.7; margin-top: 4px;">${time}</div>
            `;
        } else if (type === 'system') {
            messageDiv.style.background = '#f0f0f0';
            messageDiv.style.color = '#666';
            messageDiv.style.fontStyle = 'italic';
            messageDiv.style.textAlign = 'center';
            messageDiv.style.margin = '10px auto';
            messageDiv.innerHTML = text;
        } else if (type === 'error') {
            messageDiv.style.background = '#fee';
            messageDiv.style.color = '#c00';
            messageDiv.style.textAlign = 'center';
            messageDiv.style.margin = '10px auto';
            messageDiv.innerHTML = '⚠️ ' + text;
        }
        
        chat.appendChild(messageDiv);
        chat.scrollTop = chat.scrollHeight;
    }

    updateStatus(text, active = false) {
        const statusText = document.getElementById('sofiaStatusText');
        const indicator = document.getElementById('voiceIndicator');
        
        if (statusText) statusText.textContent = text;
        if (indicator) {
            if (active) {
                indicator.classList.remove('inactive');
            } else {
                indicator.classList.add('inactive');
            }
        }
    }
}

// Close interface function
function closeSofiaInterface() {
    const sofiaInterface = document.getElementById('sofiaInterface');
    if (sofiaInterface) sofiaInterface.classList.remove('visible');
    
    if (window.sofiaVoice && window.sofiaVoice.isRecording) {
        window.sofiaVoice.stopListening();
    }
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', async () => {
    console.log('Initializing Sofia Simple Voice...');
    window.sofiaVoice = new SofiaSimpleVoice();
    await window.sofiaVoice.initialize();
    
    // Update button onclick
    const btn = document.getElementById('sofiaAgentBtn');
    if (btn) {
        console.log('Sofia button found, attaching click handler');
        btn.onclick = () => {
            console.log('Sofia button clicked');
            window.sofiaVoice.toggleVoice();
        };
    } else {
        console.error('Sofia button not found!');
    }
});

// Keyboard shortcut
document.addEventListener('keydown', (e) => {
    if (e.ctrlKey && e.key === 's') {
        e.preventDefault();
        if (window.sofiaVoice) {
            window.sofiaVoice.toggleVoice();
        }
    }
});