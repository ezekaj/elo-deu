// Sofia Voice Final - Complete Working Solution
console.log('Sofia Voice Final - Loading...');

// Remove any cached content
if ('caches' in window) {
    caches.keys().then(names => {
        names.forEach(name => caches.delete(name));
    });
}

// Global state
let room = null;
let isConnecting = false;
let audioTrack = null;

// LiveKit SDK Loading Helper
async function ensureLiveKitLoaded() {
    // Check if already loaded
    if (window.LiveKitClient) {
        console.log('LiveKit already available');
        return true;
    }
    
    // Check alternative names
    if (window.livekit) {
        window.LiveKitClient = window.livekit;
        console.log('LiveKit mapped from window.livekit');
        return true;
    }
    
    console.log('Loading LiveKit SDK...');
    
    // Remove any existing scripts to avoid conflicts
    const existingScripts = document.querySelectorAll('script[src*="livekit-client"]');
    existingScripts.forEach(script => script.remove());
    
    return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
        
        const timeout = setTimeout(() => {
            reject(new Error('LiveKit SDK load timeout'));
        }, 10000);
        
        script.onload = () => {
            clearTimeout(timeout);
            
            // Wait a bit for the SDK to initialize
            setTimeout(() => {
                // Check all possible locations
                if (window.LiveKitClient) {
                    console.log('LiveKit SDK loaded successfully');
                    resolve(true);
                } else if (window.livekit) {
                    window.LiveKitClient = window.livekit;
                    console.log('LiveKit SDK loaded as window.livekit');
                    resolve(true);
                } else {
                    // Last resort - check for any object with Room constructor
                    const possibleNames = ['LiveKit', 'Livekit', 'LIVEKIT', 'LivekitClient'];
                    for (const name of possibleNames) {
                        if (window[name] && window[name].Room) {
                            window.LiveKitClient = window[name];
                            console.log(`LiveKit SDK found as window.${name}`);
                            resolve(true);
                            return;
                        }
                    }
                    reject(new Error('LiveKit SDK not found after load'));
                }
            }, 500);
        };
        
        script.onerror = () => {
            clearTimeout(timeout);
            reject(new Error('LiveKit SDK script failed to load'));
        };
        
        document.head.appendChild(script);
    });
}

async function checkMicrophonePermission() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        stream.getTracks().forEach(track => track.stop());
        return true;
    } catch (error) {
        console.error('Microphone permission error:', error);
        throw new Error('Mikrofonzugriff wurde verweigert. Bitte erlauben Sie den Zugriff in Ihren Browsereinstellungen.');
    }
}

async function startVoiceAssistant() {
    console.log('Starting Sofia Voice Assistant...');
    
    const statusEl = document.getElementById('voiceIndicator');
    const statusText = document.getElementById('sofiaStatusText');
    const chatEl = document.getElementById('sofiaChat');
    
    if (chatEl) chatEl.innerHTML = '';
    
    if (isConnecting || room) {
        console.log('Already connecting or connected');
        return;
    }
    
    isConnecting = true;
    statusText.textContent = 'System wird initialisiert...';
    
    try {
        // Load LiveKit SDK
        await ensureLiveKitLoaded();
        
        // Check microphone
        statusText.textContent = 'Mikrofonzugriff wird überprüft...';
        await checkMicrophonePermission();
        
        // Get token
        statusText.textContent = 'Verbindung wird hergestellt...';
        const apiUrl = `${window.CONFIG.API_BASE_URL}/api/sofia/token`;
        
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
            throw new Error(`Token-Fehler: ${tokenResponse.status}`);
        }
        
        const { token, url, roomName } = await tokenResponse.json();
        console.log('Token received for room:', roomName);
        
        // Create room
        room = new window.LiveKitClient.Room({
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
            console.log('Connected to LiveKit!');
            statusEl.classList.remove('inactive');
            statusText.textContent = 'Mikrofon wird aktiviert...';
            
            addMessage('Hallo! Ich bin Sofia, Ihre digitale Zahnarzthelferin. Wie kann ich Ihnen helfen?', 'sofia');
            
            try {
                audioTrack = await window.LiveKitClient.createLocalAudioTrack({
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                });
                
                await room.localParticipant.publishTrack(audioTrack);
                statusText.textContent = '🎤 Bereit - Sie können sprechen';
                console.log('Microphone activated!');
            } catch (micError) {
                console.error('Microphone error:', micError);
                statusText.textContent = '❌ Mikrofonfehler';
                addMessage(`Mikrofonfehler: ${micError.message}`, 'error');
            }
        });
        
        room.on('participantConnected', (participant) => {
            console.log('Participant connected:', participant.identity);
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
                console.error('Data processing error:', e);
            }
        });
        
        room.on('disconnected', (reason) => {
            console.log('Disconnected:', reason);
            handleDisconnection();
        });
        
        // Connect to room
        console.log('Connecting to LiveKit...');
        await room.connect(url, token);
        
        isConnecting = false;
        
    } catch (error) {
        console.error('Connection error:', error);
        statusEl.classList.add('inactive');
        statusText.textContent = '❌ Fehler';
        isConnecting = false;
        
        addMessage(`Fehler: ${error.message}`, 'error');
        
        if (error.message.includes('verweigert')) {
            addMessage('Bitte erlauben Sie den Mikrofonzugriff und laden Sie die Seite neu.', 'sofia');
        }
        
        if (room) {
            room.disconnect();
            room = null;
        }
    }
}

function stopVoiceAssistant() {
    console.log('Stopping Sofia...');
    
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

// Override all existing implementations
window.startVoiceAssistant = startVoiceAssistant;
window.stopVoiceAssistant = stopVoiceAssistant;
window.startSimpleSofia = startVoiceAssistant;

// Set up button handlers
function setupSofiaButton() {
    const sofiaBtn = document.getElementById('sofiaAgentBtn');
    if (sofiaBtn) {
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

// Initialize when ready
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

console.log('Sofia Voice Final - Ready!');