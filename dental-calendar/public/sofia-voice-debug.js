// Sofia Voice Debug Version
(function() {
    console.log('Sofia Voice Debug - Starting...');
    
    let room = null;
    let localParticipant = null;
    let isConnecting = false;
    
    window.startSofiaVoiceDebug = async function() {
        console.log('=== SOFIA DEBUG START ===');
        
        // Check if LiveKit is loaded
        if (typeof LivekitClient === 'undefined') {
            console.error('❌ LiveKit SDK not loaded!');
            console.log('Checking window.LivekitClient:', window.LivekitClient);
            console.log('Checking window.livekit:', window.livekit);
            
            // Try alternative names
            if (window.livekit) {
                console.log('Found window.livekit, using that');
                window.LivekitClient = window.livekit;
            } else {
                alert('LiveKit SDK konnte nicht geladen werden');
                return;
            }
        }
        
        console.log('✅ LiveKit SDK found');
        
        try {
            // Get configuration
            const config = window.SOFIA_CONFIG || {};
            console.log('Configuration:', config);
            
            const livekitUrl = config.LIVEKIT_URL || 'wss://elosofia.site/ws';
            console.log('Attempting to connect to:', livekitUrl);
            
            // Request token from backend
            console.log('Requesting connection token...');
            const response = await fetch('/api/sofia/connect', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    participantName: 'Patient-' + Date.now(),
                    roomName: 'sofia-room-' + Date.now()
                })
            });
            
            console.log('Token response status:', response.status);
            
            if (!response.ok) {
                const errorText = await response.text();
                console.error('Token request failed:', errorText);
                throw new Error('Failed to get connection token: ' + errorText);
            }
            
            const data = await response.json();
            console.log('Token received:', {
                hasToken: !!data.token,
                url: data.url,
                roomName: data.roomName
            });
            
            // Try to connect
            console.log('Creating LiveKit room...');
            const roomOptions = {
                adaptiveStream: true,
                dynacast: true,
                videoCaptureDefaults: {
                    resolution: { width: 640, height: 480 },
                    frameRate: 30,
                },
                publishDefaults: {
                    audioPreset: 'speech',
                },
                reconnectPolicy: {
                    maxRetries: 5,
                    nextRetryDelayInMs: (retryCount) => {
                        console.log(`Reconnect attempt ${retryCount}`);
                        return Math.min(retryCount * 1000, 5000);
                    }
                },
                log: {
                    level: 'debug'
                }
            };
            
            room = new LivekitClient.Room(roomOptions);
            
            // Add event listeners
            room.on('connected', () => {
                console.log('✅ Connected to LiveKit room!');
                console.log('Room name:', room.name);
                console.log('Local participant:', room.localParticipant?.identity);
            });
            
            room.on('disconnected', (reason) => {
                console.log('❌ Disconnected from room:', reason);
            });
            
            room.on('connectionStateChanged', (state) => {
                console.log('Connection state changed:', state);
            });
            
            room.on('error', (error) => {
                console.error('Room error:', error);
            });
            
            room.on('participantConnected', (participant) => {
                console.log('Participant connected:', participant.identity);
                if (participant.identity.includes('sofia')) {
                    console.log('🎉 Sofia agent connected!');
                }
            });
            
            // Connect to room
            console.log('Connecting to room with URL:', data.url || livekitUrl);
            await room.connect(data.url || livekitUrl, data.token);
            
            console.log('✅ Successfully connected!');
            
            // Enable microphone
            console.log('Enabling microphone...');
            await room.localParticipant.setMicrophoneEnabled(true);
            console.log('✅ Microphone enabled');
            
        } catch (error) {
            console.error('❌ Connection error:', error);
            console.error('Error stack:', error.stack);
            alert('Verbindungsfehler: ' + error.message);
        }
        
        console.log('=== SOFIA DEBUG END ===');
    };
    
    // Auto-start when clicked
    document.addEventListener('DOMContentLoaded', () => {
        const sofiaButton = document.getElementById('sofiaVoiceBtn');
        if (sofiaButton) {
            sofiaButton.addEventListener('click', (e) => {
                e.preventDefault();
                console.log('Sofia button clicked - starting debug connection');
                window.startSofiaVoiceDebug();
            });
        }
    });
    
    console.log('Sofia Voice Debug - Ready. Call window.startSofiaVoiceDebug() to test');
})();