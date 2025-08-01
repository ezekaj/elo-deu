/**
 * Sofia WebSocket Client - Browser Integration
 * Connects browsers to Sofia WebSocket Bridge for voice interaction
 */

class SofiaWebSocketClient {
    constructor() {
        this.ws = null;
        this.isConnected = false;
        this.isRecording = false;
        this.clientId = null;
        
        // Audio setup
        this.audioContext = null;
        this.mediaRecorder = null;
        this.audioStream = null;
        this.audioChunks = [];
        
        // UI elements
        this.connectBtn = null;
        this.recordBtn = null;
        this.statusDiv = null;
        this.messagesDiv = null;
        this.textInput = null;
        this.sendBtn = null;
        
        // Configuration
        this.wsUrl = 'ws://localhost:8081';
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.reconnectDelay = 1000;
        
        // Statistics
        this.stats = {
            messagesReceived: 0,
            messagesSent: 0,
            audioChunksSent: 0,
            connectionTime: null,
            lastActivity: null
        };
        
        this.initialize();
    }
    
    initialize() {
        console.log('🎤 Initializing Sofia WebSocket Client...');
        this.setupUI();
        this.setupAudio();
    }
    
    setupUI() {
        // Create main container if it doesn't exist
        let container = document.getElementById('sofia-websocket-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'sofia-websocket-container';
            container.innerHTML = `
                <div class="sofia-websocket-ui">
                    <div class="sofia-header">
                        <h3>🤖 Sofia WebSocket Voice Interface</h3>
                        <div id="sofia-status" class="status">Nicht verbunden</div>
                    </div>
                    
                    <div class="sofia-controls">
                        <button id="sofia-connect-btn" class="btn btn-primary">Verbinden</button>
                        <button id="sofia-record-btn" class="btn btn-secondary" disabled>🎤 Aufnehmen</button>
                        <button id="sofia-stats-btn" class="btn btn-info">📊 Statistiken</button>
                    </div>
                    
                    <div class="sofia-chat">
                        <div id="sofia-messages" class="messages"></div>
                        <div class="input-group">
                            <input type="text" id="sofia-text-input" class="form-control" placeholder="Nachricht an Sofia...">
                            <button id="sofia-send-btn" class="btn btn-success">Senden</button>
                        </div>
                    </div>
                    
                    <div id="sofia-debug" class="debug-info" style="display: none;">
                        <h4>Debug Information</h4>
                        <pre id="sofia-debug-content"></pre>
                    </div>
                </div>
            `;
            document.body.appendChild(container);
        }
        
        // Get UI elements
        this.connectBtn = document.getElementById('sofia-connect-btn');
        this.recordBtn = document.getElementById('sofia-record-btn');
        this.statusDiv = document.getElementById('sofia-status');
        this.messagesDiv = document.getElementById('sofia-messages');
        this.textInput = document.getElementById('sofia-text-input');
        this.sendBtn = document.getElementById('sofia-send-btn');
        this.statsBtn = document.getElementById('sofia-stats-btn');
        this.debugDiv = document.getElementById('sofia-debug-content');
        
        // Bind events
        this.connectBtn.onclick = () => this.toggleConnection();
        this.recordBtn.onclick = () => this.toggleRecording();
        this.sendBtn.onclick = () => this.sendTextMessage();
        this.statsBtn.onclick = () => this.showStats();
        
        // Enter key for text input
        this.textInput.onkeypress = (e) => {
            if (e.key === 'Enter') {
                this.sendTextMessage();
            }
        };
        
        console.log('✅ UI setup complete');
    }
    
    async setupAudio() {
        try {
            // Request microphone permission
            this.audioStream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    sampleRate: 16000,
                    channelCount: 1
                }
            });
            
            // Create audio context
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
                sampleRate: 16000
            });
            
            console.log('✅ Audio setup complete');
            return true;
            
        } catch (error) {
            console.error('❌ Audio setup failed:', error);
            this.addMessage('system', 'Mikrofon-Zugriff fehlgeschlagen. Bitte Berechtigungen prüfen.');
            return false;
        }
    }
    
    async toggleConnection() {
        if (this.isConnected) {
            await this.disconnect();
        } else {
            await this.connect();
        }
    }
    
    async connect() {
        try {
            this.updateStatus('Verbinde...', 'connecting');
            this.connectBtn.disabled = true;
            
            // Create WebSocket connection
            this.ws = new WebSocket(this.wsUrl);
            
            this.ws.onopen = () => {
                console.log('✅ WebSocket connected');
                this.isConnected = true;
                this.reconnectAttempts = 0;
                this.stats.connectionTime = new Date();
                this.updateStatus('Verbunden', 'connected');
                this.connectBtn.textContent = 'Trennen';
                this.connectBtn.disabled = false;
                this.recordBtn.disabled = false;
                this.addMessage('system', 'Mit Sofia WebSocket Bridge verbunden!');
            };
            
            this.ws.onmessage = (event) => {
                this.handleMessage(JSON.parse(event.data));
            };
            
            this.ws.onclose = (event) => {
                console.log('🔌 WebSocket disconnected:', event.code, event.reason);
                this.isConnected = false;
                this.updateStatus('Getrennt', 'disconnected');
                this.connectBtn.textContent = 'Verbinden';
                this.connectBtn.disabled = false;
                this.recordBtn.disabled = true;
                
                if (event.code !== 1000) { // Not a normal closure
                    this.attemptReconnect();
                }
            };
            
            this.ws.onerror = (error) => {
                console.error('❌ WebSocket error:', error);
                this.addMessage('error', 'WebSocket Verbindungsfehler');
            };
            
        } catch (error) {
            console.error('❌ Connection failed:', error);
            this.updateStatus('Verbindung fehlgeschlagen', 'error');
            this.connectBtn.disabled = false;
            this.addMessage('error', 'Verbindung fehlgeschlagen: ' + error.message);
        }
    }
    
    async disconnect() {
        if (this.ws) {
            this.ws.close(1000, 'User disconnect');
        }
        
        if (this.isRecording) {
            this.stopRecording();
        }
        
        this.isConnected = false;
        this.updateStatus('Getrennt', 'disconnected');
        this.connectBtn.textContent = 'Verbinden';
        this.recordBtn.disabled = true;
    }
    
    attemptReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);
            
            console.log(`🔄 Reconnect attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts} in ${delay/1000}s`);
            this.updateStatus(`Verbinde neu in ${delay/1000}s...`, 'reconnecting');
            
            setTimeout(() => {
                if (!this.isConnected) {
                    this.connect();
                }
            }, delay);
        } else {
            this.addMessage('error', 'Maximale Anzahl Verbindungsversuche erreicht');
            this.updateStatus('Verbindung fehlgeschlagen', 'error');
        }
    }
    
    handleMessage(message) {
        this.stats.messagesReceived++;
        this.stats.lastActivity = new Date();
        
        console.log('📨 Received message:', message);
        
        switch (message.type) {
            case 'connected':
                this.clientId = message.client_id;
                this.addMessage('system', message.message);
                this.showCapabilities(message.capabilities);
                break;
                
            case 'status':
                this.updateStatus(message.message, 'processing');
                break;
                
            case 'transcription':
                this.addMessage('user', `🎤 "${message.text}"`);
                break;
                
            case 'sofia_response':
                this.addMessage('sofia', message.text);
                break;
                
            case 'sofia_audio':
                this.playAudio(message.audio_data, message.format);
                break;
                
            case 'appointment_response':
                this.handleAppointmentResponse(message);
                break;
                
            case 'stats':
                this.showServerStats(message.data);
                break;
                
            case 'error':
                this.addMessage('error', message.message);
                break;
                
            case 'pong':
                console.log('📡 Pong received');
                break;
                
            default:
                console.log('Unknown message type:', message.type);
        }
        
        this.updateDebugInfo();
    }
    
    async toggleRecording() {
        if (this.isRecording) {
            this.stopRecording();
        } else {
            await this.startRecording();
        }
    }
    
    async startRecording() {
        if (!this.isConnected) {
            this.addMessage('error', 'Nicht verbunden');
            return;
        }
        
        if (!this.audioStream) {
            const audioSetup = await this.setupAudio();
            if (!audioSetup) {
                return;
            }
        }
        
        try {
            // Create MediaRecorder
            this.mediaRecorder = new MediaRecorder(this.audioStream, {
                mimeType: 'audio/webm;codecs=opus'
            });
            
            this.audioChunks = [];
            
            this.mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    this.audioChunks.push(event.data);
                    this.sendAudioChunk(event.data);
                }
            };
            
            this.mediaRecorder.onstop = () => {
                console.log('🛑 Recording stopped');
                this.processRecordedAudio();
            };
            
            // Start recording
            this.mediaRecorder.start(1000); // Send chunks every 1 second
            this.isRecording = true;
            
            this.recordBtn.textContent = '🛑 Stoppen';
            this.recordBtn.className = 'btn btn-danger';
            this.updateStatus('Nehme auf...', 'recording');
            
            console.log('🎤 Recording started');
            
        } catch (error) {
            console.error('❌ Recording failed:', error);
            this.addMessage('error', 'Aufnahme fehlgeschlagen: ' + error.message);
        }
    }
    
    stopRecording() {
        if (this.mediaRecorder && this.isRecording) {
            this.mediaRecorder.stop();
            this.isRecording = false;
            
            this.recordBtn.textContent = '🎤 Aufnehmen';
            this.recordBtn.className = 'btn btn-secondary';
            this.updateStatus('Verbunden', 'connected');
        }
    }
    
    async sendAudioChunk(audioBlob) {
        try {
            // Convert blob to base64
            const arrayBuffer = await audioBlob.arrayBuffer();
            const base64Audio = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
            
            // Send to server
            this.sendMessage({
                type: 'audio_chunk',
                audio_data: base64Audio,
                format: 'webm'
            });
            
            this.stats.audioChunksSent++;
            
        } catch (error) {
            console.error('❌ Error sending audio chunk:', error);
        }
    }
    
    processRecordedAudio() {
        // Audio processing complete
        console.log('✅ Audio processing complete');
    }
    
    sendTextMessage() {
        const text = this.textInput.value.trim();
        if (!text || !this.isConnected) {
            return;
        }
        
        this.sendMessage({
            type: 'text_message',
            text: text
        });
        
        this.addMessage('user', text);
        this.textInput.value = '';
    }
    
    sendMessage(message) {
        if (this.ws && this.isConnected) {
            this.ws.send(JSON.stringify(message));
            this.stats.messagesSent++;
            this.stats.lastActivity = new Date();
        }
    }
    
    playAudio(base64Audio, format) {
        try {
            // Convert base64 to blob
            const audioData = atob(base64Audio);
            const audioArray = new Uint8Array(audioData.length);
            for (let i = 0; i < audioData.length; i++) {
                audioArray[i] = audioData.charCodeAt(i);
            }
            
            const audioBlob = new Blob([audioArray], { type: `audio/${format}` });
            const audioUrl = URL.createObjectURL(audioBlob);
            
            // Create and play audio element
            const audio = new Audio(audioUrl);
            audio.onended = () => {
                URL.revokeObjectURL(audioUrl);
            };
            
            audio.play().then(() => {
                console.log('🔊 Playing Sofia audio response');
                this.addMessage('system', '🔊 Sofia spricht...');
            }).catch(error => {
                console.error('❌ Audio playback failed:', error);
                this.addMessage('error', 'Audio-Wiedergabe fehlgeschlagen');
            });
            
        } catch (error) {
            console.error('❌ Audio processing failed:', error);
            this.addMessage('error', 'Audio-Verarbeitung fehlgeschlagen');
        }
    }
    
    addMessage(type, content) {
        const messageDiv = document.createElement('div');
        messageDiv.className = `message message-${type}`;
        
        const timestamp = new Date().toLocaleTimeString();
        const icon = this.getMessageIcon(type);
        
        messageDiv.innerHTML = `
            <div class="message-header">
                <span class="message-icon">${icon}</span>
                <span class="message-type">${this.getMessageType(type)}</span>
                <span class="message-time">${timestamp}</span>
            </div>
            <div class="message-content">${content}</div>
        `;
        
        this.messagesDiv.appendChild(messageDiv);
        this.messagesDiv.scrollTop = this.messagesDiv.scrollHeight;
    }
    
    getMessageIcon(type) {
        const icons = {
            'user': '👤',
            'sofia': '🤖',
            'system': '🔧',
            'error': '❌'
        };
        return icons[type] || '💬';
    }
    
    getMessageType(type) {
        const types = {
            'user': 'Sie',
            'sofia': 'Sofia',
            'system': 'System',
            'error': 'Fehler'
        };
        return types[type] || 'Unbekannt';
    }
    
    updateStatus(message, className = '') {
        if (this.statusDiv) {
            this.statusDiv.textContent = message;
            this.statusDiv.className = `status ${className}`;
        }
    }
    
    showCapabilities(capabilities) {
        const capList = Object.entries(capabilities)
            .map(([key, value]) => `${key}: ${value ? '✅' : '❌'}`)
            .join(', ');
        
        this.addMessage('system', `Verfügbare Funktionen: ${capList}`);
    }
    
    handleAppointmentResponse(message) {
        if (message.success) {
            this.addMessage('system', `✅ ${message.message} (ID: ${message.appointment_id})`);
        } else {
            this.addMessage('error', message.message);
        }
    }
    
    showStats() {
        this.sendMessage({ type: 'get_stats' });
        
        const clientStats = {
            'Client ID': this.clientId || 'Nicht verbunden',
            'Verbindungszeit': this.stats.connectionTime ? this.stats.connectionTime.toLocaleString() : 'Nicht verbunden',
            'Nachrichten empfangen': this.stats.messagesReceived,
            'Nachrichten gesendet': this.stats.messagesSent,
            'Audio-Chunks gesendet': this.stats.audioChunksSent,
            'Letzte Aktivität': this.stats.lastActivity ? this.stats.lastActivity.toLocaleTimeString() : 'Keine'
        };
        
        const statsText = Object.entries(clientStats)
            .map(([key, value]) => `${key}: ${value}`)
            .join('\n');
        
        this.addMessage('system', `📊 Client-Statistiken:\n${statsText}`);
    }
    
    showServerStats(serverStats) {
        const statsText = Object.entries(serverStats)
            .map(([key, value]) => {
                if (key === 'uptime') {
                    const hours = Math.floor(value / 3600);
                    const minutes = Math.floor((value % 3600) / 60);
                    return `${key}: ${hours}h ${minutes}m`;
                }
                return `${key}: ${value}`;
            })
            .join('\n');
        
        this.addMessage('system', `📊 Server-Statistiken:\n${statsText}`);
    }
    
    updateDebugInfo() {
        if (this.debugDiv) {
            const debugInfo = {
                isConnected: this.isConnected,
                isRecording: this.isRecording,
                clientId: this.clientId,
                wsUrl: this.wsUrl,
                stats: this.stats
            };
            
            this.debugDiv.textContent = JSON.stringify(debugInfo, null, 2);
        }
    }
    
    // Public API methods
    sendAppointmentRequest(appointmentData) {
        this.sendMessage({
            type: 'appointment_request',
            appointment: appointmentData
        });
    }
    
    ping() {
        this.sendMessage({ type: 'ping' });
    }
}

// Auto-initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
    console.log('🚀 Initializing Sofia WebSocket Client...');
    window.sofiaWebSocketClient = new SofiaWebSocketClient();
});

// Add CSS styles
const style = document.createElement('style');
style.textContent = `
.sofia-websocket-ui {
    max-width: 800px;
    margin: 20px auto;
    padding: 20px;
    border: 1px solid #ddd;
    border-radius: 10px;
    background: #f9f9f9;
    font-family: Arial, sans-serif;
}

.sofia-header {
    text-align: center;
    margin-bottom: 20px;
}

.sofia-header h3 {
    margin: 0 0 10px 0;
    color: #333;
}

.status {
    padding: 10px;
    border-radius: 5px;
    font-weight: bold;
}

.status.connected { background: #d4edda; color: #155724; }
.status.connecting { background: #fff3cd; color: #856404; }
.status.recording { background: #f8d7da; color: #721c24; }
.status.processing { background: #cce7ff; color: #004085; }
.status.error { background: #f8d7da; color: #721c24; }

.sofia-controls {
    text-align: center;
    margin-bottom: 20px;
}

.sofia-controls button {
    margin: 0 10px;
    padding: 10px 20px;
    border: none;
    border-radius: 5px;
    cursor: pointer;
    font-size: 14px;
}

.btn-primary { background: #007bff; color: white; }
.btn-secondary { background: #6c757d; color: white; }
.btn-success { background: #28a745; color: white; }
.btn-danger { background: #dc3545; color: white; }
.btn-info { background: #17a2b8; color: white; }

.sofia-chat {
    margin-top: 20px;
}

.messages {
    height: 300px;
    overflow-y: auto;
    border: 1px solid #ddd;
    padding: 10px;
    background: white;
    border-radius: 5px;
    margin-bottom: 10px;
}

.message {
    margin-bottom: 15px;
    padding: 10px;
    border-radius: 5px;
}

.message-user { background: #e3f2fd; }
.message-sofia { background: #f3e5f5; }
.message-system { background: #f5f5f5; }
.message-error { background: #ffebee; }

.message-header {
    font-size: 12px;
    color: #666;
    margin-bottom: 5px;
}

.message-icon { margin-right: 5px; }
.message-type { font-weight: bold; margin-right: 10px; }
.message-time { float: right; }

.message-content {
    font-size: 14px;
    line-height: 1.4;
    white-space: pre-wrap;
}

.input-group {
    display: flex;
    gap: 10px;
}

.form-control {
    flex: 1;
    padding: 10px;
    border: 1px solid #ddd;
    border-radius: 5px;
    font-size: 14px;
}

.debug-info {
    margin-top: 20px;
    padding: 10px;
    background: #f8f9fa;
    border: 1px solid #dee2e6;
    border-radius: 5px;
}

.debug-info pre {
    margin: 0;
    font-size: 12px;
    white-space: pre-wrap;
}
`;
document.head.appendChild(style);