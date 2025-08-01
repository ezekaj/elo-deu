/**
 * Enhanced Sofia Connection with TURN fallback
 * This handles connections across different networks
 */

class EnhancedSofiaConnection {
    constructor() {
        this.connectionStrategies = [];
        this.currentStrategyIndex = 0;
        this.setupStrategies();
    }

    setupStrategies() {
        // Strategy 1: Direct connection (works on same network)
        this.connectionStrategies.push({
            name: 'Direct Connection',
            config: {
                rtcConfig: {
                    iceServers: [
                        { urls: ['stun:stun.l.google.com:19302'] }
                    ]
                }
            }
        });

        // Strategy 2: Public TURN servers (works across networks)
        this.connectionStrategies.push({
            name: 'Public TURN Relay',
            config: {
                rtcConfig: {
                    iceServers: [
                        { urls: ['stun:stun.l.google.com:19302'] },
                        {
                            urls: 'turn:openrelay.metered.ca:80',
                            username: 'openrelayproject',
                            credential: 'openrelayproject'
                        },
                        {
                            urls: 'turn:openrelay.metered.ca:443',
                            username: 'openrelayproject',
                            credential: 'openrelayproject'
                        },
                        {
                            urls: 'turn:openrelay.metered.ca:443?transport=tcp',
                            username: 'openrelayproject',
                            credential: 'openrelayproject'
                        }
                    ],
                    iceTransportPolicy: 'all'
                }
            }
        });

        // Strategy 3: Force TURN only (for very restrictive networks)
        this.connectionStrategies.push({
            name: 'Force TURN Only',
            config: {
                rtcConfig: {
                    iceServers: [
                        {
                            urls: 'turn:openrelay.metered.ca:443?transport=tcp',
                            username: 'openrelayproject',
                            credential: 'openrelayproject'
                        }
                    ],
                    iceTransportPolicy: 'relay' // Force TURN relay only
                }
            }
        });
    }

    async tryNextStrategy(LK, livekitUrl, token, originalConnect) {
        if (this.currentStrategyIndex >= this.connectionStrategies.length) {
            throw new Error('All connection strategies failed');
        }

        const strategy = this.connectionStrategies[this.currentStrategyIndex];
        console.log(`Trying strategy ${this.currentStrategyIndex + 1}/${this.connectionStrategies.length}: ${strategy.name}`);

        try {
            // Apply the strategy's RTC configuration
            if (originalConnect.room && strategy.config.rtcConfig) {
                // Merge with existing room config
                Object.assign(originalConnect.room.options, strategy.config);
                console.log('Applied RTC config:', strategy.config.rtcConfig);
            }

            // Try to connect
            await originalConnect.room.connect(livekitUrl, token);
            console.log(`✅ Connected successfully using: ${strategy.name}`);
            return true;

        } catch (error) {
            console.error(`❌ Strategy "${strategy.name}" failed:`, error.message);
            this.currentStrategyIndex++;
            
            // Disconnect and recreate room for next attempt
            if (originalConnect.room) {
                try {
                    await originalConnect.room.disconnect();
                } catch (e) {
                    // Ignore disconnect errors
                }
            }

            // Wait a bit before trying next strategy
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Recreate room with new strategy
            if (this.currentStrategyIndex < this.connectionStrategies.length) {
                const nextStrategy = this.connectionStrategies[this.currentStrategyIndex];
                originalConnect.room = new LK.Room({
                    adaptiveStream: true,
                    dynacast: true,
                    stopLocalTrackOnUnpublish: true,
                    ...nextStrategy.config
                });
                
                // Re-setup event handlers
                originalConnect.setupEventHandlers();
                
                // Try next strategy
                return this.tryNextStrategy(LK, livekitUrl, token, originalConnect);
            }
        }

        return false;
    }
}

// Enhance the existing connection
window.enhancedConnection = new EnhancedSofiaConnection();

// Override the connect method to use enhanced strategies
const originalConnect = SofiaRealConnection.prototype.connect;
SofiaRealConnection.prototype.connect = async function() {
    console.log('🚀 Enhanced connection with network fallback strategies');
    
    try {
        // Load LiveKit SDK first
        await this.loadLiveKitSDK();
        const LK = window.LiveKit;
        
        if (!LK) {
            throw new Error('LiveKit SDK not loaded');
        }

        // Get connection details
        const response = await fetch(`${window.SOFIA_CONFIG.API_BASE_URL}/api/livekit-token`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true'
            },
            body: JSON.stringify({
                room: 'sofia-dental-' + Date.now(),
                identity: 'calendar-user-' + Math.random().toString(36).substr(2, 9)
            })
        });

        const { token, url } = await response.json();
        const livekitUrl = window.SOFIA_CONFIG?.LIVEKIT_URL || url;

        // Try connection strategies
        this.room = new LK.Room({
            adaptiveStream: true,
            dynacast: true,
            stopLocalTrackOnUnpublish: true
        });
        
        this.setupEventHandlers();
        
        // Use enhanced connection with fallback strategies
        await window.enhancedConnection.tryNextStrategy(LK, livekitUrl, token, this);
        
        // Continue with normal flow after successful connection
        await this.enableMicrophone(LK);
        this.isConnected = true;
        this.isConnecting = false;
        this.updateUI('connected');
        
        // Check for Sofia
        setTimeout(() => this.checkForSofia(), 3000);
        
    } catch (error) {
        console.error('Enhanced connection failed:', error);
        this.isConnecting = false;
        this.updateUI('disconnected');
        this.showError('Verbindung fehlgeschlagen: ' + error.message);
    }
};

console.log('✅ Enhanced Sofia Connection loaded with multi-network support');