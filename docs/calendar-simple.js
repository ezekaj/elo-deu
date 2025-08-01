// Simple calendar initialization without Socket.IO
let CONFIG = window.SOFIA_CONFIG || {
    API_BASE_URL: 'https://e13f48333e1e.ngrok-free.app'
};

document.addEventListener('DOMContentLoaded', function() {
    // Update connection status to show API-only mode
    const statusEl = document.getElementById('connectionStatus');
    if (statusEl) {
        // Test API connection
        fetch(CONFIG.API_BASE_URL + '/api/appointments', {
            headers: {
                'ngrok-skip-browser-warning': 'true'
            }
        })
        .then(response => {
            if (response.ok) {
                statusEl.textContent = '🟢 Verbunden (API)';
                statusEl.className = 'connection-status connected';
            } else {
                statusEl.textContent = '🔴 Verbindungsfehler';
                statusEl.className = 'connection-status disconnected';
            }
        })
        .catch(error => {
            statusEl.textContent = '🔴 Keine Verbindung';
            statusEl.className = 'connection-status disconnected';
        });
    }
});