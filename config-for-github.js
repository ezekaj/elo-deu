/**
 * Sofia Dental Configuration
 * Live at elosofia.site
 * Last updated: August 1, 2025
 */

window.SOFIA_CONFIG = {
    // Backend API endpoints (running on your machine via tunnels)
    API_BASE_URL: 'https://robot-schools-prices-clip.trycloudflare.com',
    CRM_URL: 'https://robot-schools-prices-clip.trycloudflare.com',
    
    // LiveKit Voice Service
    LIVEKIT_URL: 'wss://depends-sympathy-federation-invention.trycloudflare.com',
    LIVEKIT_API_URL: 'https://depends-sympathy-federation-invention.trycloudflare.com',
    
    // WebSocket for real-time updates
    WS_URL: 'wss://robot-schools-prices-clip.trycloudflare.com',
    
    // Environment
    ENVIRONMENT: 'production',
    
    // Features
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};

// Log configuration for debugging
console.log('Sofia Dental - Live at elosofia.site');
console.log('Backend API:', window.SOFIA_CONFIG.API_BASE_URL);
console.log('Voice Service:', window.SOFIA_CONFIG.LIVEKIT_URL);