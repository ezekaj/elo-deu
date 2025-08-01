// Sofia Override - Force Remove Demo Mode
console.log('Sofia Override - Removing ALL demo mode traces...');

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', function() {
    // Override any demo mode functions that might exist
    window.startSimpleSofia = null;
    
    // Clear the chat immediately when Sofia opens
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            if (mutation.target.id === 'sofiaInterface' && 
                mutation.target.classList.contains('visible')) {
                
                // Clear any demo messages
                const chatEl = document.getElementById('sofiaChat');
                if (chatEl) {
                    const demoMessages = chatEl.querySelectorAll('.sofia-message');
                    demoMessages.forEach(msg => {
                        if (msg.textContent.includes('Demo-Modus') || 
                            msg.textContent.includes('demo mode')) {
                            msg.remove();
                        }
                    });
                }
                
                // Fix status text
                const statusText = document.getElementById('sofiaStatusText');
                if (statusText && statusText.textContent.includes('Demo-Modus')) {
                    statusText.textContent = 'Verbindung wird hergestellt...';
                }
            }
        });
    });
    
    const sofiaInterface = document.getElementById('sofiaInterface');
    if (sofiaInterface) {
        observer.observe(sofiaInterface, { attributes: true, attributeFilter: ['class'] });
    }
    
    // Also check periodically for demo mode text
    setInterval(() => {
        const statusText = document.getElementById('sofiaStatusText');
        if (statusText && statusText.textContent.includes('Demo-Modus')) {
            statusText.textContent = 'Verbindung wird hergestellt...';
            // Trigger real connection
            if (typeof startVoiceAssistant === 'function') {
                startVoiceAssistant();
            }
        }
    }, 500);
});

console.log('Sofia Override - Active');