// Sofia Voice Integration for Dental Calendar
let sofiaRoom = null;
let isConnecting = false;
let audioTrack = null;
let dataChannel = null;
let transcriptionBuffer = '';
let sofiaResponses = [];

// Configuration
const LIVEKIT_URL = 'ws://localhost:7880';
const SOFIA_AGENT_API = '/api/sofia/connect';

// UI Elements
let sofiaInterface = null;
let sofiaChat = null;
let voiceIndicator = null;
let statusText = null;
let sofiaBtn = null;

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    sofiaInterface = document.getElementById('sofiaInterface');
    sofiaChat = document.getElementById('sofiaChat');
    voiceIndicator = document.getElementById('voiceIndicator');
    statusText = document.getElementById('sofiaStatusText');
    sofiaBtn = document.getElementById('sofiaAgentBtn');
    
});

// Wait for all scripts to load
window.addEventListener('load', () => {
    // Check for LiveKit under different possible names
    const possibleNames = ['LiveKitClient', 'LiveKit', 'livekitClient', 'livekit'];
    let found = false;
    
    for (const name of possibleNames) {
        if (typeof window[name] !== 'undefined') {
            window.livekit = window[name];
            console.log(`LiveKit SDK found as: ${name}`);
            found = true;
            break;
        }
    }
    
    if (!found) {
        console.error('LiveKit SDK not loaded!');
        // Log all global variables that might be LiveKit
        const globals = Object.keys(window).filter(k => 
            k.toLowerCase().includes('kit') || 
            k.toLowerCase().includes('live') ||
            k.toLowerCase().includes('rtc')
        );
        console.log('Possible LiveKit globals:', globals);
    }
});

// Toggle Sofia Agent
async function toggleSofiaAgent() {
    if (sofiaRoom && sofiaRoom.state === 'connected') {
        await disconnectSofia();
    } else if (!isConnecting) {
        await connectToSofia();
    }
}

// Connect to Sofia
async function connectToSofia() {
    try {
        isConnecting = true;
        sofiaBtn.disabled = true;
        sofiaBtn.classList.add('active');
        sofiaBtn.innerHTML = '<span class="sofia-icon">⏳</span> Verbinde...';
        
        // Show interface
        sofiaInterface.classList.add('visible');
        addMessage('system', 'Verbindung zu Sofia wird hergestellt...');
        
        // Get connection token
        const response = await fetch(SOFIA_AGENT_API, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                participantName: 'Calendar User',
                roomName: 'dental-calendar'
            })
        });
        
        if (!response.ok) {
            throw new Error('Failed to get connection token');
        }
        
        const { token, url } = await response.json();
        
        // Create livekit room
        sofiaRoom = new livekit.Room({
            adaptiveStream: true,
            dynacast: true,
        });
        
        // Set up event handlers
        setupRoomEventHandlers();
        
        // Connect to room
        await sofiaRoom.connect(url, token);
        
        // Create and publish audio track
        await setupAudioTrack();
        
        sofiaBtn.innerHTML = '<span class="sofia-icon">🔴</span> Verbunden';
        addMessage('sofia', 'Hallo! Ich bin Sofia, Ihre mehrsprachige Zahnarzt-Assistentin. Wie kann ich Ihnen heute helfen?');
        updateStatus('Hört zu...', true);
        
    } catch (error) {
        console.error('Connection error:', error);
        addMessage('error', 'Verbindung fehlgeschlagen: ' + error.message);
        sofiaBtn.innerHTML = '<span class="sofia-icon">🎧</span> Sofia Agent';
        sofiaBtn.classList.remove('active');
        sofiaBtn.disabled = false;
        isConnecting = false;
    }
}

// Set up room event handlers
function setupRoomEventHandlers() {
    // Handle participant connected
    sofiaRoom.on(livekit.RoomEvent.ParticipantConnected, (participant) => {
        console.log('Participant connected:', participant.identity);
        if (participant.identity.includes('sofia') || participant.identity.includes('agent')) {
            addMessage('system', 'Sofia ist bereit');
        }
    });
    
    // Handle data received
    sofiaRoom.on(livekit.RoomEvent.DataReceived, (payload, participant) => {
        const decoder = new TextDecoder();
        const message = decoder.decode(payload);
        
        try {
            const data = JSON.parse(message);
            handleSofiaMessage(data);
        } catch (e) {
            console.log('Received text:', message);
        }
    });
    
    // Handle track subscribed
    sofiaRoom.on(livekit.RoomEvent.TrackSubscribed, (track, publication, participant) => {
        console.log('Track subscribed:', track.kind);
        if (track.kind === 'audio') {
            // Attach audio track to play Sofia's voice
            const audioElement = track.attach();
            audioElement.play();
        }
    });
    
    // Handle transcription
    sofiaRoom.on(livekit.RoomEvent.TranscriptionReceived, (transcription) => {
        const segments = transcription.segments;
        segments.forEach(segment => {
            if (segment.final) {
                addMessage('user', segment.text);
            } else {
                // Update live transcription
                updateStatus(`Sie sagen: "${segment.text}"`, true);
            }
        });
    });
    
    // Handle speaking indicators
    sofiaRoom.on(livekit.RoomEvent.ActiveSpeakersChanged, (speakers) => {
        const isSpeaking = speakers.length > 0;
        updateVoiceIndicator(isSpeaking);
    });
}

// Set up audio track
async function setupAudioTrack() {
    try {
        // Request microphone permission
        const stream = await navigator.mediaDevices.getUserMedia({ 
            audio: {
                echoCancellation: true,
                noiseSuppression: true,
                autoGainControl: true
            } 
        });
        
        // Create audio track
        audioTrack = new livekit.LocalAudioTrack(stream.getAudioTracks()[0]);
        
        // Publish audio track
        await sofiaRoom.localParticipant.publishTrack(audioTrack);
        
        console.log('Audio track published');
    } catch (error) {
        console.error('Audio setup error:', error);
        throw new Error('Mikrofon konnte nicht aktiviert werden');
    }
}

// Handle Sofia messages
function handleSofiaMessage(data) {
    if (data.type === 'transcription') {
        // Sofia's response transcription
        addMessage('sofia', data.text);
    } else if (data.type === 'appointment_created') {
        // Appointment was created by Sofia
        addMessage('sofia', `Termin erfolgreich gebucht: ${data.appointment.patient_name} am ${data.appointment.date} um ${data.appointment.time} Uhr`);
        // Refresh calendar
        if (typeof refreshCalendar === 'function') {
            refreshCalendar();
        }
    } else if (data.type === 'status') {
        updateStatus(data.message, data.active);
    }
}

// Disconnect from Sofia
async function disconnectSofia() {
    try {
        if (audioTrack) {
            audioTrack.stop();
            await sofiaRoom.localParticipant.unpublishTrack(audioTrack);
            audioTrack = null;
        }
        
        if (sofiaRoom) {
            await sofiaRoom.disconnect();
            sofiaRoom = null;
        }
        
        sofiaBtn.innerHTML = '<span class="sofia-icon">🎧</span> Sofia Agent';
        sofiaBtn.classList.remove('active');
        sofiaBtn.disabled = false;
        isConnecting = false;
        
        addMessage('system', 'Verbindung getrennt');
        updateStatus('Offline', false);
        
    } catch (error) {
        console.error('Disconnect error:', error);
    }
}

// Close Sofia interface
function closeSofiaInterface() {
    sofiaInterface.classList.remove('visible');
    if (sofiaRoom && sofiaRoom.state === 'connected') {
        disconnectSofia();
    }
}

// Add message to chat
function addMessage(type, text) {
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
    
    sofiaChat.appendChild(messageDiv);
    sofiaChat.scrollTop = sofiaChat.scrollHeight;
}

// Update status
function updateStatus(text, active = false) {
    statusText.textContent = text;
    updateVoiceIndicator(active);
}

// Update voice indicator
function updateVoiceIndicator(active) {
    if (active) {
        voiceIndicator.classList.remove('inactive');
    } else {
        voiceIndicator.classList.add('inactive');
    }
}

// Send data to Sofia
async function sendToSofia(data) {
    if (sofiaRoom && sofiaRoom.state === 'connected') {
        const encoder = new TextEncoder();
        const payload = encoder.encode(JSON.stringify(data));
        await sofiaRoom.localParticipant.publishData(payload, livekit.DataPacket_Kind.RELIABLE);
    }
}

// Keyboard shortcut for Sofia
document.addEventListener('keydown', (e) => {
    if (e.ctrlKey && e.key === 's') {
        e.preventDefault();
        toggleSofiaAgent();
    }
});

// Example functions Sofia can trigger
window.sofiaActions = {
    // Book appointment through Sofia
    bookAppointment: async (details) => {
        const { patientName, date, time, treatmentType, phone } = details;
        
        const response = await fetch('/api/appointments', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                patient_name: patientName,
                date: date,
                time: time,
                end_time: calculateEndTime(time, 30),
                treatment_type: treatmentType,
                phone: phone,
                notes: 'Gebucht über Sofia Voice Assistant'
            })
        });
        
        const result = await response.json();
        return result;
    },
    
    // Check availability
    checkAvailability: async (date) => {
        const response = await fetch(`/api/appointments?date=${date}`);
        const appointments = await response.json();
        return appointments;
    },
    
    // Get next available slot
    getNextAvailable: async () => {
        const response = await fetch('/api/sofia/next-available');
        const result = await response.json();
        return result;
    }
};

// Helper function
function calculateEndTime(startTime, durationMinutes) {
    const [hours, minutes] = startTime.split(':').map(Number);
    const totalMinutes = hours * 60 + minutes + durationMinutes;
    const endHours = Math.floor(totalMinutes / 60);
    const endMins = totalMinutes % 60;
    return `${endHours.toString().padStart(2, '0')}:${endMins.toString().padStart(2, '0')}`;
}