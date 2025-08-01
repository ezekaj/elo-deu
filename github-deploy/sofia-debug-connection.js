/**
 * Sofia Debug Connection - Minimal test to isolate the connection issue
 */

console.log('🔍 Sofia Debug Connection Script Loading...');

// Debug function to check what's available
window.debugSofiaConnection = function() {
    console.log('=== Sofia Connection Debug ===');
    
    // Check LiveKit SDK availability
    console.log('1. LiveKit SDK Check:');
    console.log('   window.LivekitClient:', typeof window.LivekitClient);
    console.log('   window.livekitClient:', typeof window.livekitClient);  
    console.log('   window.LiveKit:', typeof window.LiveKit);
    console.log('   window.livekit:', typeof window.livekit);
    
    // Show available LiveKit components
    const livekitVariants = ['LivekitClient', 'livekitClient', 'LiveKit', 'livekit'];
    livekitVariants.forEach(variant => {
        if (window[variant]) {
            console.log(`   ${variant} components:`, Object.keys(window[variant]).slice(0, 10));
        }
    });
    
    // Test basic room creation
    try {
        let Client = window.LivekitClient || window.livekitClient || window.LiveKit;
        if (Client && Client.Room) {
            console.log('2. Room Creation Test:');
            const testRoom = new Client.Room();
            console.log('   ✅ Room created successfully');
            console.log('   Room type:', typeof testRoom);
            console.log('   Room methods:', Object.getOwnPropertyNames(Object.getPrototypeOf(testRoom)).slice(0, 10));
        } else {
            console.log('2. Room Creation Test: ❌ No Room constructor found');
        }
    } catch (error) {
        console.log('2. Room Creation Test: ❌ Error:', error.message);
    }
    
    // Test token endpoint
    console.log('3. Token Endpoint Test:');
    fetch('/api/livekit-token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            identity: 'debug-user-' + Date.now(),
            room: 'sofia-room'
        })
    })
    .then(response => response.json())
    .then(data => {
        console.log('   ✅ Token received:', {
            success: data.success,
            tokenLength: data.token ? data.token.length : 0,
            room: data.room,
            url: data.url
        });
    })
    .catch(error => {
        console.log('   ❌ Token error:', error.message);
    });
    
    console.log('=== End Debug ===');
};

// Auto-run debug on load
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        console.log('🚀 Running automatic Sofia connection debug...');
        window.debugSofiaConnection();
    }, 1000);
});

// Simple connection test
window.testSofiaConnection = async function() {
    console.log('🧪 Testing Sofia Connection...');
    
    try {
        // Normalize SDK reference
        let LiveKit = window.LivekitClient || window.livekitClient || window.LiveKit;
        
        if (!LiveKit || !LiveKit.Room) {
            throw new Error('LiveKit SDK not properly loaded');
        }
        
        console.log('✅ LiveKit SDK found');
        
        // Get token
        const response = await fetch('/api/livekit-token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                identity: 'test-user-' + Date.now(),
                room: 'sofia-room'
            })
        });
        
        if (!response.ok) {
            throw new Error(`Token request failed: ${response.status}`);
        }
        
        const tokenData = await response.json();
        console.log('✅ Token received');
        
        // Create room
        const room = new LiveKit.Room({
            adaptiveStream: true,
            dynacast: true
        });
        
        console.log('✅ Room created');
        
        // Set up basic event handlers
        room.on(LiveKit.RoomEvent.Connected, () => {
            console.log('✅ Connected to room!');
        });
        
        room.on(LiveKit.RoomEvent.ParticipantConnected, (participant) => {
            console.log('✅ Participant connected:', participant.identity);
        });
        
        room.on(LiveKit.RoomEvent.Disconnected, (reason) => {
            console.log('❌ Disconnected:', reason);
        });
        
        // Connect
        console.log('🔌 Connecting to room...');
        await room.connect(tokenData.url || 'ws://localhost:7880', tokenData.token);
        
        console.log('✅ Connection test successful!');
        
        // Disconnect after 5 seconds
        setTimeout(async () => {
            await room.disconnect();
            console.log('✅ Test disconnected');
        }, 5000);
        
    } catch (error) {
        console.error('❌ Connection test failed:', error);
        console.error('Error details:', {
            message: error.message,
            stack: error.stack
        });
    }
};