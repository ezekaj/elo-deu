/**
 * Sofia Dental Calendar Configuration
 * VPS Deployment Configuration
 */

// VPS Configuration - Update these when you have your VPS
const VPS_CONFIG = {
    // Replace with your VPS IP or domain
    VPS_IP: 'YOUR_VPS_IP',  // e.g., '123.456.789.0' or 'api.elosofia.site'
    USE_HTTPS: false        // Set to true after SSL setup
};

// Determine environment
const isLocalhost = window.location.hostname === 'localhost';
const protocol = VPS_CONFIG.USE_HTTPS ? 'https' : 'http';
const wsProtocol = VPS_CONFIG.USE_HTTPS ? 'wss' : 'ws';

// Create CONFIG object
window.CONFIG = {
    // API endpoints
    API_BASE_URL: isLocalhost 
        ? 'http://localhost:3005'
        : `${protocol}://${VPS_CONFIG.VPS_IP}:3005`,
    
    // WebSocket URL
    WS_URL: isLocalhost 
        ? 'ws://localhost:3005'
        : `${wsProtocol}://${VPS_CONFIG.VPS_IP}:3005`,
    
    // LiveKit configuration - Direct connection, no proxy needed!
    LIVEKIT_URL: isLocalhost
        ? 'ws://localhost:7880'
        : `${wsProtocol}://${VPS_CONFIG.VPS_IP}:7880`,
    
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