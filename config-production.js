/**
 * Sofia Dental Configuration
 * Live at elosofia.site
 */
window.SOFIA_CONFIG = {
    API_BASE_URL: 'https://robot-schools-prices-clip.trycloudflare.com',
    CRM_URL: 'https://robot-schools-prices-clip.trycloudflare.com',
    LIVEKIT_URL: ''.replace('https', 'wss'),
    LIVEKIT_API_URL: '',
    WS_URL: 'https://robot-schools-prices-clip.trycloudflare.com'.replace('https', 'wss'),
    ENVIRONMENT: 'production',
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};

console.log('Sofia Dental - Live Configuration');
console.log('API:', window.SOFIA_CONFIG.API_BASE_URL);
console.log('Voice:', window.SOFIA_CONFIG.LIVEKIT_URL);
