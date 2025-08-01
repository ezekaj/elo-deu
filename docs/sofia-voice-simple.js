// Simplified Sofia Voice Connection
console.log('Sofia Voice Simple - Loading...');

let room = null;
let localParticipant = null;
let isConnecting = false;

async function startSimpleSofia() {
    console.log('Starting Simple Sofia...');
    
    const statusEl = document.getElementById('voiceIndicator');
    const statusText = document.getElementById('sofiaStatusText');
    
    if (isConnecting) {
        console.log('Already connecting...');
        return;
    }
    
    isConnecting = true;
    statusText.textContent = 'Verbindung wird hergestellt...';
    
    try {
        // Skip LiveKit for now - just update UI to show it's "working"
        console.log('Simple Sofia - Simulating connection...');
        
        // Update UI to show connected
        setTimeout(() => {
            statusEl.classList.remove('inactive');
            statusText.textContent = '🎤 Mikrofon bereit (Demo-Modus)';
            
            // Add demo message
            addSofiaMessage('Hallo! Ich bin Sofia, Ihre digitale Zahnarzthelferin. Im Demo-Modus kann ich Ihnen zeigen, wie ich normalerweise funktioniere.');
            
            // Simulate listening
            setTimeout(() => {
                statusText.textContent = '👂 Höre zu... (Demo-Modus)';
            }, 2000);
            
        }, 1000);
        
    } catch (error) {
        console.error('Simple Sofia error:', error);
        statusEl.classList.add('inactive');
        statusText.textContent = '❌ Verbindungsfehler';
        isConnecting = false;
    }
}

function addSofiaMessage(text) {
    const chatEl = document.getElementById('sofiaChat');
    if (chatEl) {
        const messageEl = document.createElement('div');
        messageEl.className = 'sofia-message sofia';
        messageEl.textContent = text;
        chatEl.appendChild(messageEl);
        chatEl.scrollTop = chatEl.scrollHeight;
    }
}

// Override the original Sofia functions
window.startVoiceAssistant = startSimpleSofia;
window.stopVoiceAssistant = function() {
    console.log('Stopping Simple Sofia...');
    const statusEl = document.getElementById('voiceIndicator');
    const statusText = document.getElementById('sofiaStatusText');
    
    statusEl.classList.add('inactive');
    statusText.textContent = 'Gestoppt';
    isConnecting = false;
};

// Auto-start when Sofia interface is opened
document.addEventListener('DOMContentLoaded', function() {
    const sofiaBtn = document.getElementById('sofiaAgentBtn');
    if (sofiaBtn) {
        sofiaBtn.addEventListener('click', function() {
            this.classList.toggle('active');
            const sofiaInterface = document.getElementById('sofiaInterface');
            
            if (this.classList.contains('active')) {
                sofiaInterface.classList.add('visible');
                // Start simple Sofia
                setTimeout(startSimpleSofia, 500);
            } else {
                sofiaInterface.classList.remove('visible');
                window.stopVoiceAssistant();
            }
        });
    }
});

console.log('Sofia Voice Simple - Ready!');