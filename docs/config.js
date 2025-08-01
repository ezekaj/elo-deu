/**
 * Sofia Dental Calendar Configuration
 * Updated with new ngrok URL
 */

// Determine if we're on the GitHub Pages site or local
const isGitHubPages = window.location.hostname === 'elosofia.site';
const isLocalhost = window.location.hostname === 'localhost';

// Create CONFIG object
window.CONFIG = {
    // API endpoints - GitHub Pages needs to use ngrok
    API_BASE_URL: isGitHubPages 
        ? 'https://0ac90f1eb152.ngrok-free.app'  // Current ngrok URL
        : (isLocalhost ? 'http://localhost:3005' : window.location.origin),
    
    // WebSocket URL
    WS_URL: isGitHubPages 
        ? 'wss://0ac90f1eb152.ngrok-free.app'
        : (isLocalhost ? 'ws://localhost:3005' : window.location.origin.replace('https:', 'wss:').replace('http:', 'ws:')),
    
    // LiveKit configuration - for GitHub Pages, use proxy through ngrok
    LIVEKIT_URL: isGitHubPages
        ? 'wss://0ac90f1eb152.ngrok-free.app/livekit-proxy'
        : 'ws://localhost:7880',
    
    // Features
    DEMO_MODE: false,
    VOICE_ENABLED: true
};

// Also create SOFIA_CONFIG for backward compatibility
window.SOFIA_CONFIG = {
    API_BASE_URL: window.CONFIG.API_BASE_URL,
    CRM_URL: window.CONFIG.API_BASE_URL,
    LIVEKIT_URL: window.CONFIG.LIVEKIT_URL,
    LIVEKIT_API_URL: window.CONFIG.API_BASE_URL,
    WS_URL: window.CONFIG.WS_URL,
    ENVIRONMENT: isLocalhost ? 'development' : 'production',
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};

// Log configuration
console.log('Sofia Configuration Fixed:', {
    environment: window.SOFIA_CONFIG.ENVIRONMENT,
    apiBase: window.CONFIG.API_BASE_URL,
    wsUrl: window.CONFIG.WS_URL,
    isGitHubPages: isGitHubPages,
    currentDomain: window.location.hostname
});