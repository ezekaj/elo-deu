/**
 * Sofia Debug Integration - Mit erweiterten Debug-Funktionen
 */

class SofiaDebugIntegration {
    constructor() {
        this.room = null;
        this.isConnected = false;
        this.livekitUrl = 'ws://localhost:7880';
        this.debugLog = [];
    }

    log(message, type = 'info') {
        const timestamp = new Date().toLocaleTimeString();
        const logEntry = `[${timestamp}] ${type.toUpperCase()}: ${message}`;
        console.log(logEntry);
        this.debugLog.push(logEntry);
        
        // Show in UI
        const debugDiv = document.getElementById('sofia-debug');
        if (debugDiv) {
            debugDiv.innerHTML = this.debugLog.slice(-10).join('<br>');
        }
    }

    async connect() {
        try {
            this.log('Starting connection to Sofia...');
            
            // Get token
            this.log('Fetching LiveKit token...');
            const tokenResponse = await fetch('http://localhost:5001/api/livekit-token', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    identity: 'calendar-user-' + Date.now(),
                    room: 'sofia-room'
                })
            });
            
            if (!tokenResponse.ok) {
                throw new Error(`Token fetch failed: ${tokenResponse.status}`);
            }
            
            const data = await tokenResponse.json();
            this.log('Token received successfully');
            
            // Create room
            this.log('Creating LiveKit room...');
            this.room = new LivekitClient.Room({
                adaptiveStream: true,
                dynacast: true,
                audioCaptureDefaults: {
                    autoGainControl: true,
                    echoCancellation: true,
                    noiseSuppression: true,
                }
            });
            
            // Setup all event handlers before connecting
            this.setupEvents();
            
            // Connect
            this.log('Connecting to LiveKit server...');
            await this.room.connect(this.livekitUrl, data.token);
            
            this.log(`Connected! Room: ${this.room.name}, Identity: ${this.room.localParticipant.identity}`);
            
            // Enable microphone
            this.log('Enabling microphone...');
            await this.room.localParticipant.setMicrophoneEnabled(true);
            
            this.isConnected = true;
            this.log('Fully connected and microphone enabled');
            
            // Check participants
            const participants = Array.from(this.room.remoteParticipants.values());
            this.log(`Remote participants: ${participants.length}`);
            participants.forEach(p => {
                this.log(` - ${p.identity} (audio: ${p.audioTrackPublications.size})`);
            });
            
            // Send initial message
            this.log('Sending initial message to Sofia...');
            this.sendTextMessage('Hallo Sofia, ich bin da!');
            
        } catch (error) {
            this.log(`Connection error: ${error.message}`, 'error');
            console.error(error);
        }
    }

    setupEvents() {
        // Participant connected
        this.room.on(LivekitClient.RoomEvent.ParticipantConnected, (participant) => {
            this.log(`Participant connected: ${participant.identity}`);
            
            // Check if it's Sofia
            if (participant.identity.toLowerCase().includes('sofia') || 
                participant.identity.includes('agent')) {
                this.log('Sofia agent detected!', 'success');
            }
        });
        
        // Track published
        this.room.on(LivekitClient.RoomEvent.TrackPublished, (publication, participant) => {
            this.log(`Track published by ${participant.identity}: ${publication.trackName} (${publication.kind})`);
        });
        
        // Track subscribed
        this.room.on(LivekitClient.RoomEvent.TrackSubscribed, (track, publication, participant) => {
            this.log(`Track subscribed from ${participant.identity}: ${track.kind}`);
            
            if (track.kind === 'audio') {
                this.log('Attaching audio track...');
                const audioElement = track.attach();
                audioElement.id = 'sofia-audio';
                audioElement.autoplay = true;
                audioElement.controls = true; // Show controls for debugging
                document.body.appendChild(audioElement);
                
                // Try to play
                audioElement.play().then(() => {
                    this.log('Audio playback started', 'success');
                }).catch(err => {
                    this.log(`Audio playback error: ${err.message}`, 'error');
                });
            }
        });
        
        // Track unsubscribed
        this.room.on(LivekitClient.RoomEvent.TrackUnsubscribed, (track, publication, participant) => {
            this.log(`Track unsubscribed from ${participant.identity}: ${track.kind}`);
            track.detach();
        });
        
        // Data received
        this.room.on(LivekitClient.RoomEvent.DataReceived, (payload, participant) => {
            const message = new TextDecoder().decode(payload);
            this.log(`Data from ${participant.identity}: ${message}`);
        });
        
        // Speaking changed
        this.room.on(LivekitClient.RoomEvent.IsSpeakingChanged, (speaking, participant) => {
            if (speaking) {
                this.log(`${participant.identity} is speaking`);
            }
        });
        
        // Active speakers changed
        this.room.on(LivekitClient.RoomEvent.ActiveSpeakersChanged, (speakers) => {
            const names = speakers.map(s => s.identity).join(', ');
            this.log(`Active speakers: ${names}`);
        });
        
        // Connection quality changed
        this.room.on(LivekitClient.RoomEvent.ConnectionQualityChanged, (quality, participant) => {
            this.log(`Connection quality for ${participant.identity}: ${quality}`);
        });
    }

    sendTextMessage(text) {
        if (this.room && this.room.localParticipant) {
            const encoder = new TextEncoder();
            const data = encoder.encode(JSON.stringify({
                type: 'message',
                text: text,
                timestamp: Date.now()
            }));
            
            this.room.localParticipant.publishData(data, true);
            this.log(`Sent message: ${text}`);
        }
    }

    async disconnect() {
        if (this.room) {
            this.log('Disconnecting...');
            await this.room.disconnect();
            this.room = null;
            this.isConnected = false;
            this.log('Disconnected');
        }
    }
}

// Initialize when ready
document.addEventListener('DOMContentLoaded', () => {
    console.log('Sofia Debug Integration loaded');
    
    // Add debug UI
    const debugDiv = document.createElement('div');
    debugDiv.id = 'sofia-debug';
    debugDiv.style.cssText = `
        position: fixed;
        bottom: 10px;
        right: 10px;
        width: 400px;
        height: 200px;
        background: rgba(0,0,0,0.8);
        color: #0f0;
        font-family: monospace;
        font-size: 12px;
        padding: 10px;
        overflow-y: auto;
        border: 1px solid #0f0;
        z-index: 10000;
    `;
    document.body.appendChild(debugDiv);
    
    // Add control buttons
    const controls = document.createElement('div');
    controls.style.cssText = `
        position: fixed;
        bottom: 220px;
        right: 10px;
        z-index: 10001;
    `;
    controls.innerHTML = `
        <button onclick="sofiaDebug.connect()">Connect</button>
        <button onclick="sofiaDebug.disconnect()">Disconnect</button>
        <button onclick="sofiaDebug.sendTextMessage('Hallo Sofia!')">Say Hello</button>
    `;
    document.body.appendChild(controls);
    
    // Create global instance
    window.sofiaDebug = new SofiaDebugIntegration();
});