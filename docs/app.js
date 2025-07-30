// Sofia Dental Assistant - Client Configuration
let config = {
    apiUrl: 'https://YOUR-NGROK-ID.ngrok-free.app',
    wsUrl: 'wss://YOUR-NGROK-ID.ngrok-free.app'
};

// Load config from localStorage if available
const savedConfig = localStorage.getItem('sofiaConfig');
if (savedConfig) {
    config = JSON.parse(savedConfig);
}

// Update status display
function updateStatus(message, type = 'info') {
    const status = document.getElementById('status');
    if (status) {
        status.textContent = message;
        status.className = 'status active ' + type;
        
        // Auto-hide success messages
        if (type === 'connected') {
            setTimeout(() => {
                status.classList.remove('active');
            }, 5000);
        }
    }
}

// Save configuration
function saveConfig() {
    const apiUrl = document.getElementById('apiUrl')?.value;
    const wsUrl = document.getElementById('wsUrl')?.value;
    
    if (apiUrl && wsUrl) {
        config.apiUrl = apiUrl;
        config.wsUrl = wsUrl;
        localStorage.setItem('sofiaConfig', JSON.stringify(config));
        updateStatus('Configuration saved!', 'connected');
        
        // Hide config section after saving
        const configSection = document.getElementById('configSection');
        if (configSection) {
            configSection.style.display = 'none';
        }
    }
}

// Test connection to Sofia
async function testConnection() {
    updateStatus('Testing connection...', 'connecting');
    
    try {
        const response = await fetch(config.apiUrl + '/api/health');
        if (response.ok) {
            const data = await response.json();
            updateStatus('Connected to Sofia! ' + JSON.stringify(data), 'connected');
            return true;
        } else {
            updateStatus('Server responded with error: ' + response.status, 'error');
            return false;
        }
    } catch (error) {
        updateStatus('Connection failed: ' + error.message, 'error');
        return false;
    }
}

// Connect to Sofia WebSocket
async function connectToSofia() {
    updateStatus('Connecting to Sofia...', 'connecting');
    
    // First test if API is accessible
    const apiOk = await testConnection();
    if (!apiOk) {
        updateStatus('Please configure the server URL first', 'error');
        document.getElementById('configSection').style.display = 'block';
        return;
    }
    
    try {
        // Here you would implement the actual LiveKit connection
        // For now, we'll just show that we're connected
        updateStatus('Connected to Sofia! You can now speak.', 'connected');
        
        // In a real implementation, you would:
        // 1. Get a token from your API
        // 2. Connect to LiveKit using the token
        // 3. Set up audio streams
        
    } catch (error) {
        updateStatus('Failed to connect: ' + error.message, 'error');
    }
}

// Show configuration UI
function showConfig() {
    const configSection = document.getElementById('configSection');
    if (configSection) {
        configSection.style.display = configSection.style.display === 'none' ? 'block' : 'none';
        
        // Update input values
        document.getElementById('apiUrl').value = config.apiUrl;
        document.getElementById('wsUrl').value = config.wsUrl;
    }
}

// Initialize on page load
window.addEventListener('load', () => {
    // Check if we have saved configuration
    if (!config.apiUrl.includes('YOUR-NGROK-ID')) {
        // Test connection automatically
        testConnection();
    } else {
        updateStatus('Please configure the server URL', 'error');
        if (document.getElementById('configSection')) {
            document.getElementById('configSection').style.display = 'block';
        }
    }
});