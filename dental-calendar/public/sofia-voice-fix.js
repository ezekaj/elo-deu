// Sofia Voice Fix - Complete Solution
console.log('Sofia Voice Fix - Loading...');

// First, remove any cached demo mode
if ('caches' in window) {
    caches.keys().then(names => {
        names.forEach(name => {
            caches.delete(name);
            console.log('Cleared cache:', name);
        });
    });
}

// Global variables
let room = null;
let isConnecting = false;
let audioTrack = null;

// Ensure LiveKit is loaded
async function ensureLiveKitLoaded() {
    if (typeof window.LiveKitClient !== 'undefined') {
        console.log('LiveKit already loaded');
        return true;
    }
    
    console.log('Loading LiveKit SDK...');
    return new Promise((resolve, reject) => {
        // Check if script already exists
        const existingScript = document.querySelector('script[src*="livekit-client"]');
        if (existingScript) {
            // Wait for it to load
            if (window.LiveKitClient) {
                resolve(true);
            } else {
                existingScript.addEventListener('load', () => resolve(true));
                existingScript.addEventListener('error', () => reject(new Error('LiveKit load failed')));
            }
            return;
        }
        
        // Create new script
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
        script.onload = () => {
            console.log('LiveKit SDK loaded successfully');
            resolve(true);
        };
        script.onerror = () => {
            console.error('Failed to load LiveKit SDK');
            reject(new Error('LiveKit SDK konnte nicht geladen werden'));
        };
        document.head.appendChild(script);
    });
}

async function checkMicrophonePermission() {
    try {
        // Check if we already have permission
        const result = await navigator.permissions.query({ name: 'microphone' });
        console.log('Microphone permission:', result.state);
        
        if (result.state === 'denied') {
            throw new Error('Mikrofonzugriff wurde verweigert. Bitte erlauben Sie den Zugriff in Ihren Browsereinstellungen.');
        }
        
        // Request microphone access
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        // Stop the test stream
        stream.getTracks().forEach(track => track.stop());
        
        return true;
    } catch (error) {
        console.error('Microphone permission error:', error);
        throw error;
    }
}

async function startVoiceAssistant() {
    console.log('Starting Sofia Voice (Fixed Version)...');
    
    const statusEl = document.getElementById('voiceIndicator');
    const statusText = document.getElementById('sofiaStatusText');
    const chatEl = document.getElementById('sofiaChat');
    
    // Clear any demo messages immediately
    if (chatEl) {
        chatEl.innerHTML = '';
    }
    
    if (isConnecting || room) {
        console.log('Already connecting or connected');
        return;
    }
    
    isConnecting = true;
    statusText.textContent = 'System wird initialisiert...';
    
    try {
        // Step 1: Ensure LiveKit is loaded
        await ensureLiveKitLoaded();
        
        // Step 2: Check microphone permission
        statusText.textContent = 'Mikrofonzugriff wird überprüft...';
        await checkMicrophonePermission();
        
        // Step 3: Get token
        statusText.textContent = 'Verbindung wird hergestellt...';
        const apiUrl = `${window.CONFIG.API_BASE_URL}/api/sofia/token`;
        console.log('Requesting token from:', apiUrl);
        
        const tokenResponse = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true'
            },
            body: JSON.stringify({
                participant_name: 'User ' + Date.now()
            })
        });
        
        if (!tokenResponse.ok) {
            const errorText = await tokenResponse.text();
            console.error('Token response:', errorText);
            throw new Error(`Token-Fehler: ${tokenResponse.status}`);
        }
        
        const { token, url, roomName } = await tokenResponse.json();
        console.log('Token erhalten für Raum:', roomName);
        
        // Step 4: Create room - now LiveKit is definitely loaded
        if (!window.LiveKitClient) {
            throw new Error('LiveKit SDK nicht verfügbar');
        }
        
        room = new window.LiveKitClient.Room({
            adaptiveStream: true,
            dynacast: true,
            audioCaptureDefaults: {
                autoGainControl: true,
                echoCancellation: true,
                noiseSuppression: true
            }
        });
        
        // Step 5: Set up handlers
        room.on('connected', async () => {
            console.log('Mit LiveKit verbunden!');
            statusEl.classList.remove('inactive');
            statusText.textContent = 'Mikrofon wird aktiviert...';
            
            addMessage('Hallo! Ich bin Sofia, Ihre digitale Zahnarzthelferin. Wie kann ich Ihnen helfen?', 'sofia');
            
            try {
                // Create and publish audio track
                audioTrack = await window.LiveKitClient.createLocalAudioTrack({
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                });
                
                await room.localParticipant.publishTrack(audioTrack);
                statusText.textContent = '🎤 Bereit - Sie können sprechen';
                console.log('Mikrofon aktiviert!');
                
            } catch (micError) {
                console.error('Mikrofonfehler:', micError);
                statusText.textContent = '❌ Mikrofonfehler';
                addMessage(`Mikrofonfehler: ${micError.message}`, 'error');
            }
        });
        
        room.on('participantConnected', (participant) => {
            console.log('Teilnehmer verbunden:', participant.identity);
            if (participant.identity.toLowerCase().includes('sofia') || 
                participant.identity.toLowerCase().includes('agent')) {
                addMessage('Sofia ist jetzt im Raum und hört zu.', 'system');
            }
        });
        
        room.on('trackSubscribed', (track, publication, participant) => {
            if (track.kind === 'audio') {
                const audioEl = track.attach();
                audioEl.style.display = 'none';
                document.body.appendChild(audioEl);
                console.log('Audio track attached from:', participant.identity);
            }
        });
        
        room.on('dataReceived', (payload, participant) => {
            try {
                const data = JSON.parse(new TextDecoder().decode(payload));
                console.log('Data received:', data);
                if (data.type === 'transcript') {
                    addMessage(data.text, data.role === 'user' ? 'user' : 'sofia');
                } else if (data.message) {
                    addMessage(data.message, 'sofia');
                }
            } catch (e) {
                console.error('Datenverarbeitungsfehler:', e);
            }
        });
        
        room.on('connectionStateChanged', (state) => {
            console.log('Connection state:', state);
            if (state === 'reconnecting') {
                statusText.textContent = '🔄 Verbindung wird wiederhergestellt...';
            }
        });
        
        room.on('disconnected', (reason) => {
            console.log('Verbindung getrennt:', reason);
            handleDisconnection();
        });
        
        // Step 6: Connect
        console.log('Verbinde mit LiveKit...');
        await room.connect(url, token);
        
        isConnecting = false;
        
    } catch (error) {
        console.error('Verbindungsfehler:', error);
        statusEl.classList.add('inactive');
        statusText.textContent = '❌ Fehler';
        isConnecting = false;
        
        addMessage(`Fehler: ${error.message}`, 'error');
        
        if (error.message.includes('verweigert')) {
            addMessage('Bitte erlauben Sie den Mikrofonzugriff in Ihrem Browser und laden Sie die Seite neu.', 'sofia');
        } else if (error.message.includes('Token-Fehler')) {
            addMessage('Verbindung zum Server fehlgeschlagen. Bitte überprüfen Sie Ihre Internetverbindung.', 'sofia');
        }
        
        if (room) {
            room.disconnect();
            room = null;
        }
    }
}

function stopVoiceAssistant() {
    console.log('Stoppe Sofia...');
    
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

// Override any existing implementations
window.startVoiceAssistant = startVoiceAssistant;
window.stopVoiceAssistant = stopVoiceAssistant;
window.startSimpleSofia = startVoiceAssistant; // Override demo

// Set up button handlers when DOM is ready
function setupSofiaButton() {
    const sofiaBtn = document.getElementById('sofiaAgentBtn');
    if (sofiaBtn) {
        // Remove old handlers
        const newBtn = sofiaBtn.cloneNode(true);
        sofiaBtn.parentNode.replaceChild(newBtn, sofiaBtn);
        
        newBtn.addEventListener('click', function() {
            this.classList.toggle('active');
            const sofiaInterface = document.getElementById('sofiaInterface');
            
            if (this.classList.contains('active')) {
                sofiaInterface.classList.add('visible');
                setTimeout(startVoiceAssistant, 100);
            } else {
                sofiaInterface.classList.remove('visible');
                stopVoiceAssistant();
            }
        });
    }
}

// Setup when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupSofiaButton);
} else {
    setupSofiaButton();
}

// Global close function
window.closeSofiaInterface = function() {
    const sofiaInterface = document.getElementById('sofiaInterface');
    const sofiaBtn = document.getElementById('sofiaAgentBtn');
    
    if (sofiaInterface) sofiaInterface.classList.remove('visible');
    if (sofiaBtn) sofiaBtn.classList.remove('active');
    stopVoiceAssistant();
};

console.log('Sofia Voice Fix - Bereit!');