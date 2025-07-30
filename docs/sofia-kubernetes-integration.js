/**
 * Sofia Kubernetes Auto-Deployment Integration
 * Handles button-triggered Sofia agent deployment in Docker/Kubernetes
 */

class SofiaKubernetesManager {
    constructor() {
        this.deploymentStatus = 'idle';
        this.currentRoom = null;
        this.livekitRoom = null;
        this.deploymentTimeout = 90000; // 90 seconds timeout
        
        console.log('🎯 Sofia Kubernetes Manager initialized');
    }

    // Main method called by Sofia button
    async deployAndConnect(userId = null) {
        console.log('🚀 Sofia button clicked - starting Kubernetes deployment...');
        
        try {
            this.deploymentStatus = 'deploying';
            this.updateUI('Deploying Sofia in Kubernetes...', 'warning');
            
            // Step 1: Trigger Sofia deployment via API
            const deploymentResult = await this.triggerSofiaDeployment(userId);
            
            if (!deploymentResult.success) {
                throw new Error(`Deployment failed: ${deploymentResult.error}`);
            }
            
            console.log('✅ Sofia deployment initiated:', deploymentResult);
            
            // Step 2: Connect to LiveKit room with provided token
            const connectionResult = await this.connectToSofiaRoom(deploymentResult);
            
            if (connectionResult.success) {
                this.deploymentStatus = 'connected';
                
                if (connectionResult.fallback_mode) {
                    this.updateUI('Sofia deployed successfully! (Note: Voice connection requires LiveKit)', 'warning');
                } else {
                    this.updateUI('Sofia is ready! You can now speak.', 'success');
                }
                
                return {
                    success: true,
                    message: 'Sofia agent deployed and connected successfully',
                    deployment: deploymentResult,
                    connection: connectionResult
                };
            } else {
                throw new Error(`Connection failed: ${connectionResult.error}`);
            }
            
        } catch (error) {
            console.error('❌ Sofia deployment/connection failed:', error);
            this.deploymentStatus = 'failed';
            this.updateUI(`Failed to start Sofia: ${error.message}`, 'danger');
            
            return {
                success: false,
                error: error.message,
                fallback_available: true
            };
        }
    }

    // Trigger Sofia deployment via calendar server API
    async triggerSofiaDeployment(userId) {
        console.log('🎯 Triggering Sofia Kubernetes deployment...');
        
        try {
            const response = await fetch('/api/sofia/deploy', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    userId: userId || `browser-user-${Date.now()}`,
                    roomName: 'sofia-room',
                    deploymentType: 'kubernetes-auto',
                    triggerSource: 'calendar-button'
                })
            });
            
            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.message || `HTTP ${response.status}`);
            }
            
            const result = await response.json();
            console.log('📦 Deployment API response:', result);
            
            if (result.success) {
                console.log(`✅ Sofia deployment: ${result.deployment_status}`);
                console.log(`⏱️ Estimated ready time: ${result.estimated_ready_time}`);
                console.log(`🏷️ Pod name: ${result.pod_name}`);
                
                // Update UI with deployment progress
                this.updateUI(`Sofia is starting up... (${result.estimated_ready_time})`, 'info');
                
                return {
                    success: true,
                    token: result.token,
                    room: result.room,
                    livekit_url: result.livekit_url,
                    deployment_status: result.deployment_status,
                    sofia_ready: result.sofia_ready,
                    pod_name: result.pod_name
                };
            } else {
                throw new Error(result.message || 'Unknown deployment error');
            }
            
        } catch (error) {
            console.error('❌ Deployment API error:', error);
            throw new Error(`Deployment failed: ${error.message}`);
        }
    }

    // Connect to Sofia room using LiveKit
    async connectToSofiaRoom(deploymentData) {
        console.log('🔗 Connecting to Sofia LiveKit room...');
        
        try {
            // Wait for LiveKit to be available
            if (typeof LiveKit === 'undefined') {
                console.log('⏳ Waiting for LiveKit SDK to load...');
                await this.waitForLiveKit();
            }
            
            // Initialize LiveKit room
            this.livekitRoom = new LiveKit.Room({
                adaptiveStream: true,
                dynacast: true,
                videoCaptureDefaults: {
                    resolution: LiveKit.VideoPresets.h720.resolution,
                }
            });
            
            // Set up event handlers
            this.setupLiveKitEventHandlers();
            
            // Connect to room with deployment token
            console.log(`🌐 Connecting to ${deploymentData.livekit_url}...`);
            await this.livekitRoom.connect(deploymentData.livekit_url, deploymentData.token);
            
            console.log('✅ Connected to Sofia room:', this.livekitRoom.name);
            this.currentRoom = deploymentData.room;
            
            // Enable microphone for user
            await this.livekitRoom.localParticipant.setMicrophoneEnabled(true);
            console.log('🎤 Microphone enabled for user');
            
            // Wait for Sofia agent to join (with timeout)
            const sofiaJoined = await this.waitForSofiaAgent(30000); // 30 second timeout
            
            if (sofiaJoined) {
                console.log('🤖 Sofia agent joined the room!');
                return {
                    success: true,
                    room: this.currentRoom,
                    sofia_present: true,
                    ready_for_voice: true
                };
            } else {
                console.log('⏰ Sofia agent join timeout - but connection established');
                return {
                    success: true,
                    room: this.currentRoom,
                    sofia_present: false,
                    ready_for_voice: true,
                    warning: 'Sofia may still be starting up'
                };
            }
            
        } catch (error) {
            console.error('❌ LiveKit connection error:', error);
            
            // Fallback: Return success even without LiveKit for testing
            if (error.message.includes('LiveKit SDK failed to load')) {
                console.log('🔄 Using fallback mode without LiveKit');
                return {
                    success: true,
                    room: deploymentData.room,
                    sofia_present: false,
                    ready_for_voice: false,
                    fallback_mode: true,
                    warning: 'LiveKit SDK not available - using fallback mode'
                };
            }
            
            return {
                success: false,
                error: error.message
            };
        }
    }

    // Set up LiveKit event handlers
    setupLiveKitEventHandlers() {
        if (!this.livekitRoom) return;
        
        this.livekitRoom.on(LiveKit.RoomEvent.Connected, () => {
            console.log('✅ LiveKit Room Connected');
            this.updateUI('Connected to Sofia room', 'info');
        });
        
        this.livekitRoom.on(LiveKit.RoomEvent.ParticipantConnected, (participant) => {
            console.log('👤 Participant joined:', participant.identity);
            
            if (participant.identity.includes('sofia')) {
                console.log('🤖 Sofia agent joined the room!');
                this.updateUI('Sofia is now listening...', 'success');
            }
        });
        
        this.livekitRoom.on(LiveKit.RoomEvent.TrackSubscribed, (track, publication, participant) => {
            console.log('🎵 Track subscribed:', track.kind, 'from', participant.identity);
            
            if (track.kind === LiveKit.Track.Kind.Audio && participant.identity.includes('sofia')) {
                console.log('🔊 Sofia audio track received');
                // Attach Sofia's audio to the page
                const audioElement = track.attach();
                audioElement.autoplay = true;
                document.body.appendChild(audioElement);
            }
        });
        
        this.livekitRoom.on(LiveKit.RoomEvent.DataReceived, (payload, participant) => {
            if (participant && participant.identity.includes('sofia')) {
                const message = new TextDecoder().decode(payload);
                console.log('💬 Sofia message:', message);
                this.updateUI(`Sofia: ${message}`, 'info');
            }
        });
        
        this.livekitRoom.on(LiveKit.RoomEvent.Disconnected, (reason) => {
            console.log('📞 Room disconnected:', reason);
            this.updateUI('Disconnected from Sofia', 'warning');
            this.deploymentStatus = 'disconnected';
        });
    }

    // Wait for Sofia agent to join the room
    async waitForSofiaAgent(timeoutMs = 30000) {
        console.log('⏱️ Waiting for Sofia agent to join...');
        
        const startTime = Date.now();
        
        return new Promise((resolve) => {
            const checkSofia = () => {
                // Check if Sofia is among participants
                const participants = Array.from(this.livekitRoom.remoteParticipants.values());
                const sofiaParticipant = participants.find(p => 
                    p.identity.includes('sofia') || p.identity.includes('agent')
                );
                
                if (sofiaParticipant) {
                    console.log('✅ Sofia found:', sofiaParticipant.identity);
                    resolve(true);
                    return;
                }
                
                // Check timeout
                if (Date.now() - startTime > timeoutMs) {
                    console.log('⏰ Sofia agent wait timeout');
                    resolve(false);
                    return;
                }
                
                // Continue checking
                setTimeout(checkSofia, 1000);
            };
            
            checkSofia();
        });
    }

    // Update UI with deployment status
    updateUI(message, type = 'info') {
        console.log(`📱 UI Update [${type}]: ${message}`);
        
        // Update Sofia button and status
        const sofiaButton = document.getElementById('sofia-button');
        const statusDiv = document.getElementById('sofia-status') || this.createStatusDiv();
        
        if (sofiaButton) {
            switch (this.deploymentStatus) {
                case 'deploying':
                    sofiaButton.textContent = 'Deploying Sofia...';
                    sofiaButton.disabled = true;
                    sofiaButton.className = 'btn btn-warning';
                    break;
                case 'connected':
                    sofiaButton.textContent = 'Sofia Active 🎤';
                    sofiaButton.disabled = false;
                    sofiaButton.className = 'btn btn-success';
                    break;
                case 'failed':
                    sofiaButton.textContent = 'Retry Sofia';
                    sofiaButton.disabled = false;
                    sofiaButton.className = 'btn btn-danger';
                    break;
                default:
                    sofiaButton.textContent = 'Start Sofia Agent';
                    sofiaButton.disabled = false;
                    sofiaButton.className = 'btn btn-primary';
            }
        }
        
        if (statusDiv) {
            statusDiv.textContent = message;
            statusDiv.className = `alert alert-${type}`;
        }
    }

    // Wait for LiveKit SDK to be available
    async waitForLiveKit(maxWaitMs = 15000) {
        const startTime = Date.now();
        
        return new Promise((resolve, reject) => {
            // First check if it's already loaded
            if (typeof LiveKit !== 'undefined') {
                console.log('✅ LiveKit SDK already available');
                resolve();
                return;
            }
            
            // Listen for the custom event
            const handleLiveKitLoaded = () => {
                console.log('✅ LiveKit SDK loaded via event');
                window.removeEventListener('livekitLoaded', handleLiveKitLoaded);
                resolve();
            };
            
            window.addEventListener('livekitLoaded', handleLiveKitLoaded);
            
            // Fallback polling check
            const checkLiveKit = () => {
                if (typeof LiveKit !== 'undefined') {
                    console.log('✅ LiveKit SDK loaded via polling');
                    window.removeEventListener('livekitLoaded', handleLiveKitLoaded);
                    resolve();
                    return;
                }
                
                if (Date.now() - startTime > maxWaitMs) {
                    window.removeEventListener('livekitLoaded', handleLiveKitLoaded);
                    reject(new Error('LiveKit SDK failed to load within timeout. Please check your internet connection and try again.'));
                    return;
                }
                
                setTimeout(checkLiveKit, 500);
            };
            
            // Start polling after a short delay
            setTimeout(checkLiveKit, 100);
        });
    }

    // Create status div if it doesn't exist
    createStatusDiv() {
        let statusDiv = document.getElementById('sofia-status');
        if (!statusDiv) {
            statusDiv = document.createElement('div');
            statusDiv.id = 'sofia-status';
            statusDiv.className = 'alert alert-info';
            
            const sofiaButton = document.getElementById('sofia-button');
            if (sofiaButton && sofiaButton.parentNode) {
                sofiaButton.parentNode.insertBefore(statusDiv, sofiaButton.nextSibling);
            } else {
                document.body.appendChild(statusDiv);
            }
        }
        return statusDiv;
    }

    // Disconnect from Sofia
    async disconnect() {
        console.log('📞 Disconnecting from Sofia...');
        
        if (this.livekitRoom) {
            await this.livekitRoom.disconnect();
            this.livekitRoom = null;
        }
        
        this.currentRoom = null;
        this.deploymentStatus = 'idle';
        this.updateUI('Disconnected', 'secondary');
    }

    // Get current status
    getStatus() {
        return {
            status: this.deploymentStatus,
            room: this.currentRoom,
            connected: this.livekitRoom?.state === LiveKit.ConnectionState.Connected
        };
    }
}

// Global Sofia manager instance
let sofiaKubernetesManager = null;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    console.log('🎯 Initializing Sofia Kubernetes integration...');
    
    sofiaKubernetesManager = new SofiaKubernetesManager();
    
    // Bind to Sofia button
    const sofiaButton = document.getElementById('sofia-button');
    if (sofiaButton) {
        sofiaButton.addEventListener('click', async function(e) {
            e.preventDefault();
            
            console.log('🚀 Sofia button clicked - triggering Kubernetes deployment');
            
            try {
                const userId = `user-${Date.now()}`;
                const result = await sofiaKubernetesManager.deployAndConnect(userId);
                
                if (result.success) {
                    console.log('✅ Sofia deployment and connection successful');
                } else {
                    console.error('❌ Sofia deployment failed:', result.error);
                    
                    // Show fallback options
                    if (result.fallback_available) {
                        console.log('🔄 Fallback options available');
                        // Could implement direct connection fallback here
                    }
                }
                
            } catch (error) {
                console.error('❌ Sofia button handler error:', error);
            }
        });
        
        console.log('✅ Sofia button handler attached');
    } else {
        console.error('❌ Sofia button not found');
    }
});

// Export for global access
window.SofiaKubernetesManager = SofiaKubernetesManager;
window.sofiaKubernetesManager = sofiaKubernetesManager;