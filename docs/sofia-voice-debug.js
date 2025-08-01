// Sofia Voice Debug Version - Shows detailed status
console.log('Sofia Voice Debug - Starting...');

// Global state
let room = null;
let isConnecting = false;
let audioTrack = null;

function updateStatus(message, isError = false) {
    console.log(`[Sofia Debug] ${message}`);
    const statusText = document.getElementById('sofiaStatusText');
    if (statusText) {
        statusText.textContent = message;
        if (isError) {
            statusText.style.color = '#c00';
        } else {
            statusText.style.color = '';
        }
    }
    
    // Also add to chat
    const chatEl = document.getElementById('sofiaChat');
    if (chatEl) {
        const debugMsg = document.createElement('div');
        debugMsg.className = 'sofia-message system';
        debugMsg.style.fontSize = '12px';
        debugMsg.style.color = isError ? '#c00' : '#666';
        debugMsg.textContent = `[Debug] ${message}`;
        chatEl.appendChild(debugMsg);
    }
}

async function ensureLiveKitLoaded() {
    updateStatus('Checking for LiveKit SDK...');
    
    // Check all possible locations
    const possibleSDKs = [
        { name: 'window.LiveKitClient', obj: window.LiveKitClient },
        { name: 'window.livekit', obj: window.livekit },
        { name: 'window.LiveKit', obj: window.LiveKit },
        { name: 'window.Livekit', obj: window.Livekit }
    ];
    
    for (const sdk of possibleSDKs) {
        if (sdk.obj) {
            updateStatus(`Found SDK at ${sdk.name}`);
            window.LiveKitClient = sdk.obj;
            return true;
        }
    }
    
    updateStatus('LiveKit SDK not found, loading...');
    
    return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://unpkg.com/livekit-client@2.5.7/dist/livekit-client.umd.js';
        
        const timeout = setTimeout(() => {
            updateStatus('LiveKit SDK load timeout!', true);
            reject(new Error('SDK load timeout'));
        }, 15000);
        
        script.onload = () => {
            clearTimeout(timeout);
            updateStatus('LiveKit script loaded, checking availability...');
            
            // Check after a delay
            let checkCount = 0;
            const checkInterval = setInterval(() => {
                checkCount++;
                updateStatus(`Checking for SDK (attempt ${checkCount}/10)...`);
                
                // Check all locations again
                for (const sdk of possibleSDKs) {
                    if (window[sdk.name.split('.')[1]]) {
                        window.LiveKitClient = window[sdk.name.split('.')[1]];
                        updateStatus(`SDK found at ${sdk.name}!`);
                        clearInterval(checkInterval);
                        resolve(true);
                        return;
                    }
                }
                
                if (checkCount >= 10) {
                    clearInterval(checkInterval);
                    updateStatus('SDK not found after 10 attempts!', true);
                    reject(new Error('SDK not available'));
                }
            }, 500);
        };
        
        script.onerror = (error) => {
            clearTimeout(timeout);
            updateStatus('Failed to load SDK script!', true);
            reject(error);
        };
        
        updateStatus('Appending SDK script to document...');
        document.head.appendChild(script);
    });
}

async function checkMicrophonePermission() {
    updateStatus('Checking microphone permission...');
    
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        updateStatus('Microphone permission granted!');
        stream.getTracks().forEach(track => track.stop());
        return true;
    } catch (error) {
        updateStatus(`Microphone error: ${error.message}`, true);
        throw error;
    }
}

async function startVoiceAssistant() {
    console.log('[Sofia Debug] Starting voice assistant...');
    
    const statusEl = document.getElementById('voiceIndicator');
    const chatEl = document.getElementById('sofiaChat');
    
    if (chatEl) chatEl.innerHTML = '';
    
    if (isConnecting || room) {
        updateStatus('Already connecting or connected');
        return;
    }
    
    isConnecting = true;
    updateStatus('Starting initialization...');
    
    try {
        // Step 1: Load SDK
        await ensureLiveKitLoaded();
        updateStatus('LiveKit SDK ready!');
        
        // Step 2: Check microphone
        await checkMicrophonePermission();
        
        // Step 3: Get token
        updateStatus('Requesting connection token...');
        const apiUrl = `${window.CONFIG.API_BASE_URL}/api/sofia/token`;
        updateStatus(`Token URL: ${apiUrl}`);
        
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
        
        updateStatus(`Token response status: ${tokenResponse.status}`);
        
        if (!tokenResponse.ok) {
            const errorText = await tokenResponse.text();
            throw new Error(`Token error ${tokenResponse.status}: ${errorText}`);
        }
        
        const tokenData = await tokenResponse.json();
        updateStatus(`Token received for room: ${tokenData.roomName}`);
        
        // Step 4: Create room
        updateStatus('Creating LiveKit room...');
        if (!window.LiveKitClient || !window.LiveKitClient.Room) {
            throw new Error('LiveKitClient.Room not available!');
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
        
        updateStatus('Room created, setting up handlers...');
        
        // Event handlers
        room.on('connected', async () => {
            updateStatus('Connected to LiveKit!');
            statusEl.classList.remove('inactive');
            
            try {
                updateStatus('Creating local audio track...');
                audioTrack = await window.LiveKitClient.createLocalAudioTrack({
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                });
                
                updateStatus('Publishing audio track...');
                await room.localParticipant.publishTrack(audioTrack);
                updateStatus('🎤 Microphone active - You can speak!');
            } catch (micError) {
                updateStatus(`Microphone error: ${micError.message}`, true);
            }
        });
        
        room.on('disconnected', (reason) => {
            updateStatus(`Disconnected: ${reason}`);
            handleDisconnection();
        });
        
        room.on('reconnecting', () => {
            updateStatus('Reconnecting...');
        });
        
        room.on('reconnected', () => {
            updateStatus('Reconnected!');
        });
        
        // Step 5: Connect
        updateStatus(`Connecting to ${tokenData.url}...`);
        await room.connect(tokenData.url, tokenData.token);
        
        isConnecting = false;
        
    } catch (error) {
        updateStatus(`Error: ${error.message}`, true);
        console.error('[Sofia Debug] Full error:', error);
        
        isConnecting = false;
        if (room) {
            room.disconnect();
            room = null;
        }
    }
}

function stopVoiceAssistant() {
    updateStatus('Stopping Sofia...');
    
    if (room) {
        room.disconnect();
        room = null;
    }
    
    if (audioTrack) {
        audioTrack.stop();
        audioTrack = null;
    }
    
    isConnecting = false;
    document.getElementById('voiceIndicator').classList.add('inactive');
}

function handleDisconnection() {
    updateStatus('Handling disconnection...');
    
    document.getElementById('voiceIndicator').classList.add('inactive');
    
    if (audioTrack) {
        audioTrack.stop();
        audioTrack = null;
    }
    
    room = null;
    isConnecting = false;
}

// Override all implementations
window.startVoiceAssistant = startVoiceAssistant;
window.stopVoiceAssistant = stopVoiceAssistant;

// Set up button
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

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupSofiaButton);
} else {
    setupSofiaButton();
}

window.closeSofiaInterface = function() {
    const sofiaInterface = document.getElementById('sofiaInterface');
    const sofiaBtn = document.getElementById('sofiaAgentBtn');
    
    if (sofiaInterface) sofiaInterface.classList.remove('visible');
    if (sofiaBtn) sofiaBtn.classList.remove('active');
    stopVoiceAssistant();
};

console.log('[Sofia Debug] Script loaded!');