const WebSocket = require('ws');

// Test direct LiveKit connection
console.log('Testing direct LiveKit connection...');
const directWs = new WebSocket('ws://localhost:7880');

directWs.on('open', () => {
    console.log('✅ Direct connection opened');
    directWs.close();
});

directWs.on('error', (err) => {
    console.error('❌ Direct connection error:', err.message);
});

// Test proxy connection
setTimeout(() => {
    console.log('\nTesting proxy connection...');
    const proxyWs = new WebSocket('ws://localhost:3005/livekit-proxy');
    
    proxyWs.on('open', () => {
        console.log('✅ Proxy connection opened');
        proxyWs.close();
    });
    
    proxyWs.on('error', (err) => {
        console.error('❌ Proxy connection error:', err.message);
    });
    
    proxyWs.on('close', (code, reason) => {
        console.log('Proxy closed:', code, reason);
    });
}, 1000);