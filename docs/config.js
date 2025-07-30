// Configuration for Sofia Dental Calendar
// This file handles both local and ngrok deployments

// Check if we have saved config in localStorage
let savedConfig = null;
try {
    savedConfig = localStorage.getItem('sofiaConfig');
    if (savedConfig) {
        savedConfig = JSON.parse(savedConfig);
    }
} catch (e) {
    console.log('No saved config found');
}

// Default configuration
const defaultConfig = {
    // API endpoints
    apiUrl: window.location.origin,
    socketUrl: window.location.origin,
    
    // LiveKit configuration
    livekitUrl: 'ws://localhost:7880',
    livekitApiKey: 'devkey',
    livekitApiSecret: 'secret'
};

// Use saved config or defaults
const config = savedConfig || defaultConfig;

// Update config based on current location
if (window.location.hostname === 'localhost') {
    // Local development
    config.apiUrl = 'http://localhost:3005';
    config.socketUrl = 'http://localhost:3005';
    config.livekitUrl = 'ws://localhost:7880';
} else if (window.location.hostname.includes('ngrok')) {
    // Running through ngrok
    config.apiUrl = window.location.origin;
    config.socketUrl = window.location.origin;
    // LiveKit URL needs to be updated manually or through config UI
} else if (window.location.hostname === 'elosofia.site' || window.location.hostname.includes('github.io')) {
    // GitHub Pages - needs manual configuration
    console.log('Running on GitHub Pages - please configure server URLs');
}

// Function to update configuration
function updateConfig(newConfig) {
    Object.assign(config, newConfig);
    try {
        localStorage.setItem('sofiaConfig', JSON.stringify(config));
    } catch (e) {
        console.error('Failed to save config:', e);
    }
}

// Function to get current configuration
function getConfig() {
    return config;
}

// Export for use in other scripts
window.sofiaConfig = config;
window.updateSofiaConfig = updateConfig;
window.getSofiaConfig = getConfig;