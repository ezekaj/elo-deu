/**
 * Dynamic Configuration for Sofia Dental Calendar
 * This file configures the API endpoints based on environment
 */

window.SOFIA_CONFIG = {
    // API Endpoints - using local URLs for PC version
    API_BASE_URL: 'http://localhost:3005',
    
    CRM_URL: 'http://localhost:5000',
    
    LIVEKIT_URL: 'ws://localhost:7880',
    
    LIVEKIT_API_URL: 'http://localhost:7880',
    
    // WebSocket for real-time updates
    WS_URL: 'ws://localhost:3005',
    
    // Environment
    ENVIRONMENT: window.location.hostname === 'localhost' ? 'development' : 'production',
    
    // Features
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};

// Log configuration for debugging
console.log('Sofia Configuration:', {
    environment: window.SOFIA_CONFIG.ENVIRONMENT,
    apiBase: window.SOFIA_CONFIG.API_BASE_URL,
    livekit: window.SOFIA_CONFIG.LIVEKIT_URL
});