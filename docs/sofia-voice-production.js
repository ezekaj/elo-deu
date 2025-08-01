// Sofia Voice Production - Real Implementation Only
console.log('Sofia Voice Production - Loading...');

// Global variables
let room = null;
let localParticipant = null;
let isConnecting = false;
let audioTrack = null;

async function startVoiceAssistant() {
    console.log('Starting Sofia Voice Assistant...');
    
    const statusEl = document.getElementById('voiceIndicator');
    const statusText = document.getElementById('sofiaStatusText');
    const chatEl = document.getElementById('sofiaChat');
    
    if (isConnecting || room) {
        console.log('Already connected or connecting...');
        return;
    }
    
    // Clear chat
    chatEl.innerHTML = '';
    
    isConnecting = true;
    statusText.textContent = 'Verbindung wird hergestellt...';
    
    try {
        // Get token from server
        const apiBase = CONFIG.API_BASE_URL || 'http://localhost:3005';
        console.log('Requesting token from:', apiBase);
        
        const tokenResponse = await fetch(`${apiBase}/api/sofia/token`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true'
            },
            body: JSON.stringify({
                participant_name: 'Sofia User ' + Date.now()
            })
        });
        
        if (!tokenResponse.ok) {
            throw new Error(`Token request failed: ${tokenResponse.status}`);
        }
        
        const { token, url, roomName } = await tokenResponse.json();
        console.log('Token received for room:', roomName);
        
        // Create LiveKit room
        room = new LiveKitClient.Room({
            adaptiveStream: true,
            dynacast: true,
            audioCaptureDefaults: {
                autoGainControl: true,
                echoCancellation: true,
                noiseSuppression: true
            }
        });
        
        // Set up event handlers
        room.on('connected', async () => {
            console.log('Connected to LiveKit room!');
            localParticipant = room.localParticipant;
            statusEl.classList.remove('inactive');
            statusText.textContent = '🎤 Verbunden - Mikrofon wird aktiviert...';
            
            // Add welcome message
            addMessage('Hallo! Ich bin Sofia, Ihre digitale Zahnarzthelferin. Wie kann ich Ihnen helfen?', 'sofia');
            
            // Enable microphone
            try {
                audioTrack = await LiveKitClient.createLocalAudioTrack({
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                });
                
                await room.localParticipant.publishTrack(audioTrack);
                statusText.textContent = '🎙️ Bereit - Sie können jetzt sprechen';
                console.log('Microphone enabled!');
                
            } catch (micError) {
                console.error('Microphone error:', micError);
                statusText.textContent = '❌ Mikrofon-Fehler';
                addMessage('Mikrofon konnte nicht aktiviert werden. Bitte überprüfen Sie Ihre Berechtigungen.', 'error');
            }
        });
        
        room.on('participantConnected', (participant) => {
            console.log('Participant connected:', participant.identity);
            if (participant.identity.toLowerCase().includes('sofia') || 
                participant.identity.toLowerCase().includes('agent')) {
                addMessage('Sofia ist jetzt verbunden und hört zu.', 'system');
                statusText.textContent = '👂 Sofia hört zu...';
            }
        });
        
        room.on('participantDisconnected', (participant) => {
            console.log('Participant disconnected:', participant.identity);
            if (participant.identity.toLowerCase().includes('sofia') || 
                participant.identity.toLowerCase().includes('agent')) {
                addMessage('Sofia hat den Raum verlassen.', 'system');
            }
        });
        
        room.on('trackSubscribed', (track, publication, participant) => {
            console.log('Track subscribed:', track.kind, 'from', participant.identity);
            if (track.kind === 'audio' && participant.identity.toLowerCase().includes('sofia')) {
                const audioElement = track.attach();
                audioElement.style.display = 'none';
                document.body.appendChild(audioElement);
                console.log('Playing Sofia audio');
            }
        });
        
        room.on('trackUnsubscribed', (track) => {
            track.detach();
        });
        
        room.on('dataReceived', (payload, participant) => {
            try {
                const message = new TextDecoder().decode(payload);
                const data = JSON.parse(message);
                console.log('Data received:', data);
                
                if (data.type === 'transcript') {
                    if (data.role === 'user') {
                        addMessage(data.text, 'user');
                        statusText.textContent = '🤔 Sofia denkt nach...';
                    } else if (data.role === 'assistant') {
                        addMessage(data.text, 'sofia');
                        statusText.textContent = '👂 Sofia hört zu...';
                    }
                } else if (data.type === 'status') {
                    statusText.textContent = data.message;
                } else if (data.message) {
                    addMessage(data.message, 'sofia');
                }
            } catch (error) {
                console.error('Error parsing data:', error);
            }
        });
        
        room.on('connectionQualityChanged', (quality) => {
            console.log('Connection quality:', quality);
            if (quality === 'poor') {
                statusText.textContent = '⚠️ Schlechte Verbindung...';
            }
        });
        
        room.on('disconnected', (reason) => {
            console.log('Disconnected:', reason);
            handleDisconnection();
        });
        
        // Connect to room
        console.log('Connecting to LiveKit room...');
        await room.connect(url, token);
        
        isConnecting = false;
        
    } catch (error) {
        console.error('Sofia connection error:', error);
        statusEl.classList.add('inactive');
        statusText.textContent = '❌ Verbindungsfehler';
        isConnecting = false;
        
        addMessage(`Verbindungsfehler: ${error.message}`, 'error');
        addMessage('Bitte versuchen Sie es später erneut oder laden Sie die Seite neu.', 'sofia');
        
        if (room) {
            room.disconnect();
            room = null;
        }
    }
}

function stopVoiceAssistant() {
    console.log('Stopping Sofia Voice Assistant...');
    
    const statusEl = document.getElementById('voiceIndicator');
    const statusText = document.getElementById('sofiaStatusText');
    
    if (room) {
        room.disconnect();
        room = null;
    }
    
    if (audioTrack) {
        audioTrack.stop();
        audioTrack = null;
    }
    
    localParticipant = null;
    isConnecting = false;
    
    statusEl.classList.add('inactive');
    statusText.textContent = 'Getrennt';
}

function handleDisconnection() {
    const statusEl = document.getElementById('voiceIndicator');
    const statusText = document.getElementById('sofiaStatusText');
    
    statusEl.classList.add('inactive');
    statusText.textContent = 'Verbindung getrennt';
    
    if (audioTrack) {
        audioTrack.stop();
        audioTrack = null;
    }
    
    room = null;
    localParticipant = null;
    isConnecting = false;
    
    addMessage('Die Verbindung wurde getrennt.', 'system');
}

function addMessage(text, type = 'sofia') {
    const chatEl = document.getElementById('sofiaChat');
    if (!chatEl) return;
    
    const messageEl = document.createElement('div');
    messageEl.className = `sofia-message ${type}`;
    
    if (type === 'error') {
        messageEl.style.background = '#fee';
        messageEl.style.color = '#c00';
    } else if (type === 'system') {
        messageEl.style.background = '#f0f0f0';
        messageEl.style.color = '#666';
        messageEl.style.fontStyle = 'italic';
    }
    
    messageEl.textContent = text;
    chatEl.appendChild(messageEl);
    chatEl.scrollTop = chatEl.scrollHeight;
}

// Set up UI event handlers
document.addEventListener('DOMContentLoaded', function() {
    const sofiaBtn = document.getElementById('sofiaAgentBtn');
    const sofiaInterface = document.getElementById('sofiaInterface');
    
    if (sofiaBtn) {
        sofiaBtn.addEventListener('click', function() {
            this.classList.toggle('active');
            
            if (this.classList.contains('active')) {
                sofiaInterface.classList.add('visible');
                setTimeout(startVoiceAssistant, 300);
            } else {
                sofiaInterface.classList.remove('visible');
                stopVoiceAssistant();
            }
        });
    }
    
    // Close button handler
    const closeBtn = document.querySelector('.sofia-close');
    if (closeBtn) {
        closeBtn.addEventListener('click', function() {
            sofiaInterface.classList.remove('visible');
            const btn = document.getElementById('sofiaAgentBtn');
            if (btn) btn.classList.remove('active');
            stopVoiceAssistant();
        });
    }
});

// Global close function
window.closeSofiaInterface = function() {
    const sofiaInterface = document.getElementById('sofiaInterface');
    const sofiaBtn = document.getElementById('sofiaAgentBtn');
    
    if (sofiaInterface) {
        sofiaInterface.classList.remove('visible');
    }
    if (sofiaBtn) {
        sofiaBtn.classList.remove('active');
    }
    stopVoiceAssistant();
};

console.log('Sofia Voice Production - Ready!');