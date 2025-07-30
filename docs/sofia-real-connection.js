// Real Sofia LiveKit Connection
console.log('Loading Sofia Real Connection...');

// Wait for page to fully load
window.addEventListener('load', async () => {
    
    // Sofia connection manager
    class SofiaConnection {
        constructor() {
            this.room = null;
            this.token = null;
            this.isConnecting = false;
            this.isConnected = false;
        }
        
        async connect() {
            if (this.isConnecting || this.isConnected) return;
            
            try {
                this.isConnecting = true;
                this.updateUI('connecting');
                console.log('Getting LiveKit token...');
                
                // Get token from server
                const response = await fetch('/api/sofia/connect', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        participantName: 'Calendar User',
                        roomName: 'sofia-dental-' + Date.now()
                    })
                });
                
                if (!response.ok) {
                    throw new Error('Failed to get token');
                }
                
                const { token, url } = await response.json();
                console.log('Got token, connecting to LiveKit...');
                
                // Load LiveKit SDK if not already loaded
                if (typeof window.LiveKit === 'undefined') {
                    await this.loadLiveKitSDK();
                }
                
                // Use the LiveKit SDK - try different patterns
                let LK = window.LiveKitClient || window.LiveKit || window.livekit;
                
                // For v1.x, it might be under a different structure
                if (!LK) {
                    // Check if it's a default export pattern
                    const possibleLocations = [
                        window.livekitClient,
                        window['livekit-client'],
                        window.default,
                        window.LivekitClient
                    ];
                    
                    for (const loc of possibleLocations) {
                        if (loc && (loc.Room || loc.default?.Room)) {
                            LK = loc.default || loc;
                            console.log('Found LiveKit at alternative location');
                            break;
                        }
                    }
                }
                
                if (!LK) {
                    // Last resort - check all window properties
                    for (const key in window) {
                        const val = window[key];
                        if (val && typeof val === 'object' && val.Room && val.createLocalAudioTrack) {
                            console.log(`Found LiveKit at window.${key}`);
                            LK = val;
                            break;
                        }
                    }
                }
                
                if (!LK) {
                    throw new Error('LiveKit SDK not found after extensive search');
                }
                
                // Create room
                this.room = new LK.Room({
                    adaptiveStream: true,
                    dynacast: true,
                    stopLocalTrackOnUnpublish: true
                });
                
                // Setup event handlers before connecting
                this.setupEventHandlers();
                
                // Connect to room
                await this.room.connect(url, token);
                console.log('Connected to LiveKit room!');
                
                // Enable microphone
                await this.enableMicrophone(LK);
                
                this.isConnected = true;
                this.isConnecting = false;
                
                this.updateUI('connected');
                
                // Check for Sofia periodically after participant is established
                let sofiaCheckCount = 0;
                const checkForSofia = () => {
                    sofiaCheckCount++;
                    console.log(`Checking for Sofia (attempt ${sofiaCheckCount})...`);
                    
                    // Check if room is still connected
                    if (!this.room || !this.room.localParticipant) {
                        console.log('Room disconnected, stopping Sofia checks');
                        return false;
                    }
                    
                    console.log('Local participant:', this.room.localParticipant.identity);
                    console.log('Published tracks:', this.room.localParticipant.audioTracks.size);
                    
                    const participants = Array.from(this.room.participants.values());
                    console.log('Remote participants:', participants.map(p => p.identity));
                    
                    const sofia = participants.find(p => {
                        const identity = p.identity.toLowerCase();
                        return identity.includes('agent') || identity.includes('sofia') || identity.includes('dental') || identity.includes('worker');
                    });
                    
                    if (sofia) {
                        console.log('✅ Sofia found in room:', sofia.identity);
                        this.addMessage('system', `Sofia (${sofia.identity}) ist bereit`);
                        return true;
                    } else {
                        if (sofiaCheckCount < 10) {
                            this.addMessage('system', `Warte auf Sofia... (${sofiaCheckCount}/10)`);
                            setTimeout(checkForSofia, 2000);
                        } else {
                            this.addMessage('system', '❌ Sofia konnte nicht gefunden werden');
                            console.log('⚠️ Sofia did not join after 20 seconds');
                        }
                        return false;
                    }
                };
                
                // Start checking after initial connection
                setTimeout(checkForSofia, 3000);
                
            } catch (error) {
                console.error('Connection error:', error);
                this.isConnecting = false;
                this.updateUI('disconnected');
                this.showError('Verbindung fehlgeschlagen: ' + error.message);
            }
        }
        
        async loadLiveKitSDK() {
            return new Promise((resolve, reject) => {
                // Check multiple possible locations
                const scripts = [
                    'https://cdn.jsdelivr.net/npm/livekit-client@1.15.4/dist/livekit-client.umd.js',
                    'https://unpkg.com/livekit-client@1.15.4/dist/livekit-client.umd.js',
                    'https://cdn.jsdelivr.net/npm/livekit-client@2.5.7/dist/livekit-client.umd.js'
                ];
                
                let loaded = false;
                
                const tryNextScript = (index) => {
                    if (index >= scripts.length) {
                        reject(new Error('Failed to load LiveKit SDK from all sources'));
                        return;
                    }
                    
                    const script = document.createElement('script');
                    script.src = scripts[index];
                    script.onload = () => {
                        console.log('LiveKit SDK loaded from:', scripts[index]);
                        // Give it time to initialize
                        setTimeout(() => {
                            // Check what globals are available
                            console.log('Checking for LiveKit globals...');
                            const possibleNames = ['LiveKitClient', 'LiveKit', 'livekitClient', 'livekit', 'LK'];
                            
                            for (const name of possibleNames) {
                                if (window[name]) {
                                    console.log(`Found LiveKit as: window.${name}`);
                                    window.LiveKit = window[name];
                                    loaded = true;
                                    break;
                                }
                            }
                            
                            if (!loaded) {
                                // Check for livekit-client module pattern
                                const keys = Object.keys(window).filter(k => 
                                    k.toLowerCase().includes('livekit') || 
                                    k.toLowerCase().includes('kit')
                                );
                                console.log('Window keys containing "kit":', keys);
                                
                                // Log the actual objects
                                keys.forEach(key => {
                                    const value = window[key];
                                    console.log(`window.${key} =`, value);
                                    if (value && typeof value === 'object' && value.Room) {
                                        console.log(`Found LiveKit at window.${key}`);
                                        window.LiveKit = value;
                                        loaded = true;
                                    }
                                });
                                
                                // Also check for require pattern
                                if (!loaded && window.require) {
                                    try {
                                        const lk = window.require('livekit-client');
                                        if (lk) {
                                            console.log('Found LiveKit via require');
                                            window.LiveKit = lk;
                                            loaded = true;
                                        }
                                    } catch (e) {
                                        console.log('Require pattern failed:', e);
                                    }
                                }
                            }
                            
                            resolve();
                        }, 500);
                    };
                    script.onerror = () => {
                        console.warn('Failed to load from:', scripts[index]);
                        tryNextScript(index + 1);
                    };
                    document.head.appendChild(script);
                };
                
                tryNextScript(0);
            });
        }
        
        setupEventHandlers() {
            // When room is connected
            this.room.on('connected', () => {
                console.log('Room connected event');
                this.addMessage('system', 'Mit Sofia verbunden');
            });
            
            // When a participant joins
            this.room.on('participantConnected', (participant) => {
                console.log('Participant connected:', participant.identity);
                if (participant.identity.toLowerCase().includes('agent')) {
                    this.addMessage('system', 'Sofia ist bereit');
                }
            });
            
            // Track subscribed (Sofia's audio)
            this.room.on('trackSubscribed', async (track, publication, participant) => {
                console.log('Track subscribed:', track.kind, 'from', participant.identity);
                if (track.kind === 'audio') {
                    // Check if this is from the agent
                    const isAgent = participant.identity.toLowerCase().includes('agent') || 
                                   participant.identity.toLowerCase().includes('sofia') ||
                                   participant.metadata?.agent === true;
                    
                    if (isAgent) {
                        console.log('Sofia audio track received, attaching...');
                        const audioElement = track.attach();
                        audioElement.autoplay = true;
                        audioElement.volume = 1.0;
                        
                        // Add to DOM (hidden) to ensure playback
                        audioElement.style.display = 'none';
                        document.body.appendChild(audioElement);
                        
                        // Try to play with user interaction handling
                        try {
                            await audioElement.play();
                            console.log('✅ Sofia audio playing successfully');
                            this.addMessage('system', 'Audio-Verbindung hergestellt');
                        } catch (error) {
                            console.error('Audio play error:', error);
                            // Show play button if autoplay blocked
                            this.addMessage('system', '⚠️ Bitte klicken Sie hier, um Audio zu aktivieren');
                            
                            // Create a play button
                            const playBtn = document.createElement('button');
                            playBtn.textContent = '🔊 Audio aktivieren';
                            playBtn.className = 'btn btn-success';
                            playBtn.style.margin = '10px';
                            playBtn.onclick = async () => {
                                try {
                                    await audioElement.play();
                                    playBtn.remove();
                                    this.addMessage('system', '✅ Audio aktiviert');
                                } catch (e) {
                                    console.error('Manual play failed:', e);
                                }
                            };
                            document.getElementById('sofiaChat').appendChild(playBtn);
                        }
                    }
                }
            });
            
            // Data received
            this.room.on('dataReceived', (data, participant) => {
                try {
                    const decoder = new TextDecoder();
                    const message = decoder.decode(data);
                    console.log('Data received:', message);
                    const parsed = JSON.parse(message);
                    if (parsed.text) {
                        this.addMessage('sofia', parsed.text);
                    }
                } catch (e) {
                    console.log('Raw data:', data);
                }
            });
            
            // Active speakers changed
            this.room.on('activeSpeakersChanged', (speakers) => {
                console.log('Active speakers changed:', speakers.map(s => s.identity));
                
                const sofiaIsSpeaking = speakers.some(s => {
                    const identity = s.identity.toLowerCase();
                    return identity.includes('agent') || identity.includes('sofia') || identity.includes('dental');
                });
                
                const userIsSpeaking = speakers.some(s => {
                    const identity = s.identity.toLowerCase();
                    return identity.includes('user') || identity.includes('calendar');
                });
                
                this.updateVoiceIndicator(sofiaIsSpeaking || userIsSpeaking);
                
                if (sofiaIsSpeaking) {
                    this.updateStatus('Sofia spricht...', true);
                } else if (userIsSpeaking) {
                    this.updateStatus('Sie sprechen...', true);
                } else {
                    this.updateStatus('Bereit zum Zuhören...', false);
                }
            });
            
            // Track published (when user publishes microphone)
            this.room.on('trackPublished', (publication, participant) => {
                console.log('Track published:', publication.trackInfo.name, 'by', participant.identity);
                if (participant === this.room.localParticipant) {
                    console.log('✅ Your microphone is now active');
                }
            });
        }
        
        async enableMicrophone(LK) {
            try {
                console.log('Requesting microphone access...');
                
                // Request microphone with enhanced settings
                const audioTrack = await LK.createLocalAudioTrack({
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true,
                    sampleRate: 48000,
                    channelCount: 1
                });
                
                console.log('Audio track created, publishing...');
                
                // Publish the track
                const publication = await this.room.localParticipant.publishTrack(audioTrack, {
                    name: 'calendar-user-microphone'
                });
                
                console.log('✅ Microphone published successfully');
                this.addMessage('system', 'Mikrofon aktiviert - Sie können jetzt sprechen');
                
                // Store the track for later use
                this.localAudioTrack = audioTrack;
                
                return publication;
                
            } catch (error) {
                console.error('Microphone error:', error);
                this.addMessage('system', '❌ Mikrofon-Fehler: ' + error.message);
                throw new Error('Mikrofon konnte nicht aktiviert werden: ' + error.message);
            }
        }
        
        async disconnect() {
            if (this.room) {
                await this.room.disconnect();
                this.room = null;
                this.isConnected = false;
                this.updateUI('disconnected');
            }
        }
        
        updateUI(state) {
            const btn = document.getElementById('sofiaAgentBtn');
            const sofiaInterface = document.getElementById('sofiaInterface');
            
            if (state === 'connected') {
                btn?.classList.add('active');
                if (btn) btn.innerHTML = '<span class="sofia-icon">🔴</span> Verbunden';
                sofiaInterface?.classList.add('visible');
                
                // Clear previous messages and show fresh connection
                const chat = document.getElementById('sofiaChat');
                if (chat) chat.innerHTML = '';
                
                this.addMessage('system', 'LiveKit-Verbindung hergestellt');
                this.updateStatus('Warte auf Sofia...', false);
                
            } else if (state === 'connecting') {
                if (btn) btn.innerHTML = '<span class="sofia-icon">⏳</span> Verbinde...';
                sofiaInterface?.classList.add('visible');
                
            } else {
                btn?.classList.remove('active');
                if (btn) btn.innerHTML = '<span class="sofia-icon">🎧</span> Sofia Agent';
                sofiaInterface?.classList.remove('visible');
                this.updateStatus('Getrennt', false);
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
            } else if (type === 'system') {
                messageDiv.style.background = '#f0f0f0';
                messageDiv.style.color = '#666';
                messageDiv.style.fontStyle = 'italic';
                messageDiv.style.textAlign = 'center';
                messageDiv.style.margin = '10px auto';
                messageDiv.innerHTML = text;
            }
            
            chat.appendChild(messageDiv);
            chat.scrollTop = chat.scrollHeight;
        }
        
        updateVoiceIndicator(active) {
            const indicator = document.getElementById('voiceIndicator');
            if (indicator) {
                if (active) {
                    indicator.classList.remove('inactive');
                } else {
                    indicator.classList.add('inactive');
                }
            }
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
        
        showError(message) {
            const chat = document.getElementById('sofiaChat');
            if (!chat) return;
            
            const errorDiv = document.createElement('div');
            errorDiv.className = 'sofia-message error';
            errorDiv.style.background = '#fee';
            errorDiv.style.color = '#c00';
            errorDiv.style.textAlign = 'center';
            errorDiv.innerHTML = '⚠️ ' + message;
            
            chat.appendChild(errorDiv);
        }
    }
    
    // Create global Sofia connection
    window.sofiaConnection = new SofiaConnection();
    
    // Attach to button
    const btn = document.getElementById('sofiaAgentBtn');
    if (btn) {
        btn.onclick = async () => {
            if (window.sofiaConnection.isConnected) {
                await window.sofiaConnection.disconnect();
            } else {
                await window.sofiaConnection.connect();
            }
        };
    }
    
    // Close button
    window.closeSofiaInterface = () => {
        const sofiaInterface = document.getElementById('sofiaInterface');
        if (sofiaInterface) {
            sofiaInterface.classList.remove('visible');
        }
        if (window.sofiaConnection?.isConnected) {
            window.sofiaConnection.disconnect();
        }
    };
});