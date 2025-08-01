/**
 * Dynamic Configuration for Sofia Dental Calendar
 * This file configures the API endpoints based on environment
 */

window.SOFIA_CONFIG = {
    // API Endpoints - using Cloudflare tunnels
    API_BASE_URL: window.location.hostname === 'localhost' 
        ? 'http://localhost:3005' 
        : 'https://impacts-approximate-florist-cartridges.trycloudflare.com',
    
    CRM_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:5000'
        : 'https://impacts-approximate-florist-cartridges.trycloudflare.com',
    
    LIVEKIT_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:7880'
        : 'wss://maximum-topic-malawi-ltd.trycloudflare.com',  // Direct LiveKit tunnel
    
    LIVEKIT_API_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:7880'
        : 'https://maximum-topic-malawi-ltd.trycloudflare.com',
    
    // WebSocket for real-time updates
    WS_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:3005'
        : 'wss://impacts-approximate-florist-cartridges.trycloudflare.com',
    
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