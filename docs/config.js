/**
 * Dynamic Configuration for Sofia Dental Calendar
 * This file configures the API endpoints based on environment
 */

window.SOFIA_CONFIG = {
    // API Endpoints - will use Ngrok tunnels when running from GitHub Pages
    API_BASE_URL: window.location.hostname === 'localhost' 
        ? 'http://localhost:3005' 
        : 'https://0ac90f1eb152.ngrok-free.app',
    
    CRM_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:5000'
        : 'https://0ac90f1eb152.ngrok-free.app',  // CRM will be proxied through main ngrok
    
    LIVEKIT_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:7880'
        : 'wss://0ac90f1eb152.ngrok-free.app/livekit',  // WebSocket proxy path
    
    LIVEKIT_API_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:7880'
        : 'https://0ac90f1eb152.ngrok-free.app/livekit',
    
    // WebSocket for real-time updates
    WS_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:3005'
        : 'wss://0ac90f1eb152.ngrok-free.app',
    
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