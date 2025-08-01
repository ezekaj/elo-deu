// Sofia Force Reload - Emergency Fix
console.log('Sofia Force Reload - Removing ALL demo traces...');

// Force clear all storage
try {
    localStorage.clear();
    sessionStorage.clear();
} catch (e) {
    console.log('Storage clear error:', e);
}

// Clear service workers
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function(registrations) {
        for(let registration of registrations) {
            registration.unregister();
            console.log('Unregistered service worker');
        }
    });
}

// Override immediately on load
window.addEventListener('load', function() {
    // Check every 100ms for demo text and remove it
    const checkInterval = setInterval(() => {
        const chatEl = document.getElementById('sofiaChat');
        const statusEl = document.getElementById('sofiaStatusText');
        
        if (chatEl) {
            const messages = chatEl.querySelectorAll('.sofia-message');
            messages.forEach(msg => {
                if (msg.textContent.includes('Demo-Modus') || 
                    msg.textContent.includes('demo mode') ||
                    msg.textContent.includes('Im Demo-Modus')) {
                    console.log('Found demo message, removing:', msg.textContent);
                    msg.remove();
                }
            });
        }
        
        if (statusEl && (statusEl.textContent.includes('Demo-Modus') || 
                        statusEl.textContent.includes('Höre zu... (Demo-Modus)'))) {
            console.log('Found demo status, fixing:', statusEl.textContent);
            statusEl.textContent = 'Initialisierung...';
            clearInterval(checkInterval);
            
            // Force reload the real implementation
            const script = document.createElement('script');
            script.src = 'sofia-voice-fix.js?v=' + Date.now();
            script.onload = () => {
                console.log('Reloaded sofia-voice-fix.js');
                if (window.startVoiceAssistant) {
                    // Auto-start if Sofia interface is visible
                    const sofiaInterface = document.getElementById('sofiaInterface');
                    if (sofiaInterface && sofiaInterface.classList.contains('visible')) {
                        console.log('Auto-starting real Sofia...');
                        window.startVoiceAssistant();
                    }
                }
            };
            document.body.appendChild(script);
        }
    }, 100);
    
    // Stop checking after 10 seconds
    setTimeout(() => clearInterval(checkInterval), 10000);
});

console.log('Sofia Force Reload - Active');