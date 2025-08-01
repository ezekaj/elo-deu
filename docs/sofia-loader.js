// Sofia Loader - Forces fresh load of debug script
console.log('[Sofia Loader] Starting...');

// Remove ALL existing Sofia scripts
const existingScripts = document.querySelectorAll('script[src*="sofia-voice"]');
existingScripts.forEach(script => {
    console.log(`[Sofia Loader] Removing old script: ${script.src}`);
    script.remove();
});

// Clear any existing Sofia functions
delete window.startVoiceAssistant;
delete window.stopVoiceAssistant;
delete window.startSimpleSofia;

// Load the debug version with timestamp to prevent caching
const debugScript = document.createElement('script');
debugScript.src = `sofia-voice-debug.js?t=${Date.now()}`;
debugScript.onload = () => {
    console.log('[Sofia Loader] Debug script loaded successfully');
};
debugScript.onerror = (error) => {
    console.error('[Sofia Loader] Failed to load debug script:', error);
};

document.head.appendChild(debugScript);
console.log('[Sofia Loader] Debug script added to page');