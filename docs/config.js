/**
 * Dynamic Configuration for Sofia Dental Calendar
 * This file configures the API endpoints based on environment
 */

window.SOFIA_CONFIG = {
    // API Endpoints - will use Ngrok tunnels when running from GitHub Pages
    API_BASE_URL: window.location.hostname === 'localhost' 
        ? 'http://localhost:3005' 
        : 'https://772ec752906e.ngrok-free.app',
    
    CRM_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:5000'
        : 'https://3358fa3712d6.ngrok-free.app',
    
    LIVEKIT_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:7880'
        : 'wss://9608f5535742.ngrok-free.app',
    
    LIVEKIT_API_URL: window.location.hostname === 'localhost'
        ? 'http://localhost:7880'
        : 'https://9608f5535742.ngrok-free.app',
    
    // WebSocket for real-time updates
    WS_URL: window.location.hostname === 'localhost'
        ? 'ws://localhost:3005'
        : 'wss://772ec752906e.ngrok-free.app',
    
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