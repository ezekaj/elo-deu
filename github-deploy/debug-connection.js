/**
 * Debug Connection Script
 * Tests the actual connections from the browser perspective
 */

// Add this script to the page to test connections
(function() {
    console.log('🔍 Starting Connection Debug...');
    
    // Get configuration
    const CONFIG = window.SOFIA_CONFIG || {
        API_BASE_URL: 'https://772ec752906e.ngrok-free.app',
        LIVEKIT_URL: 'wss://9608f5535742.ngrok-free.app',
        CRM_URL: 'https://3358fa3712d6.ngrok-free.app',
        WS_URL: 'wss://772ec752906e.ngrok-free.app'
    };
    
    console.log('Configuration:', CONFIG);
    
    // Test API connection
    async function testAPI() {
        console.log('\n📡 Testing API Connection...');
        try {
            const response = await fetch(CONFIG.API_BASE_URL + '/api/appointments', {
                headers: {
                    'ngrok-skip-browser-warning': 'true'
                }
            });
            const data = await response.json();
            console.log('✅ API Connection OK - Appointments:', data.length);
        } catch (error) {
            console.error('❌ API Connection Failed:', error);
        }
    }
    
    // Test WebSocket connection
    function testWebSocket() {
        console.log('\n🔌 Testing WebSocket Connection...');
        try {
            // Socket.IO specific connection
            if (typeof io !== 'undefined') {
                const socket = io(CONFIG.API_BASE_URL, {
                    transports: ['websocket', 'polling'],
                    withCredentials: true
                });
                
                socket.on('connect', () => {
                    console.log('✅ WebSocket Connected via Socket.IO');
                    socket.disconnect();
                });
                
                socket.on('connect_error', (error) => {
                    console.error('❌ WebSocket Connection Error:', error.message);
                });
            } else {
                console.warn('⚠️ Socket.IO not loaded');
            }
        } catch (error) {
            console.error('❌ WebSocket Test Failed:', error);
        }
    }
    
    // Test LiveKit connection
    async function testLiveKit() {
        console.log('\n🎤 Testing LiveKit Connection...');
        try {
            // Try to get token from API
            const response = await fetch(CONFIG.API_BASE_URL + '/api/livekit-token', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'ngrok-skip-browser-warning': 'true'
                },
                body: JSON.stringify({
                    identity: 'test-user-' + Date.now(),
                    room: 'test-room'
                })
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log('✅ LiveKit Token Obtained:', data.token ? 'Valid' : 'Invalid');
                console.log('LiveKit URL:', data.url || CONFIG.LIVEKIT_URL);
            } else {
                console.error('❌ LiveKit Token Request Failed:', response.status);
            }
        } catch (error) {
            console.error('❌ LiveKit Test Failed:', error);
        }
    }
    
    // Run all tests
    console.log('Environment:', window.location.hostname);
    testAPI();
    testWebSocket();
    testLiveKit();
    
    // Also log if Sofia integration is loaded
    setTimeout(() => {
        console.log('\n🤖 Sofia Integration Status:');
        console.log('- sofiaLiveKit:', typeof window.sofiaLiveKit);
        console.log('- toggleSofiaVoice:', typeof window.toggleSofiaVoice);
        console.log('- LiveKit SDK:', typeof window.LivekitClient || typeof window.LiveKit);
    }, 1000);
})();