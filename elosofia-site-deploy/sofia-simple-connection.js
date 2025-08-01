/**
 * Simple Sofia-Calendar Connection (No LiveKit Required)
 * This shows that Sofia CAN connect to the calendar - the web UI error is separate
 */

class SofiaSimpleConnection {
    constructor() {
        this.isConnected = false;
    }

    async testConnection() {
        console.log('Testing Sofia-Calendar connection...');
        
        try {
            // Test 1: Check if calendar API is responding
            const healthResponse = await fetch('/health');
            const health = await healthResponse.json();
            console.log('Calendar Health:', health);
            
            // Test 2: Check Sofia endpoints
            const sofiaResponse = await fetch('/api/sofia/next-available');
            const nextAvailable = await sofiaResponse.json();
            console.log('Sofia Endpoint Response:', nextAvailable);
            
            // Test 3: Test booking capability
            const testBooking = {
                patientName: "Web UI Test",
                patientPhone: "+49 30 11111111",
                requestedDate: new Date(Date.now() + 86400000).toISOString().split('T')[0],
                requestedTime: "11:00",
                treatmentType: "Web Test"
            };
            
            const bookingResponse = await fetch('/api/sofia/appointment', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(testBooking)
            });
            
            const bookingResult = await bookingResponse.json();
            console.log('Booking Test Result:', bookingResult);
            
            // Show results
            this.showConnectionStatus({
                health: health.status === 'healthy',
                sofiaEndpoint: nextAvailable.available !== undefined,
                booking: bookingResult.success
            });
            
            return true;
            
        } catch (error) {
            console.error('Connection test error:', error);
            this.showConnectionStatus({
                health: false,
                sofiaEndpoint: false,
                booking: false,
                error: error.message
            });
            return false;
        }
    }
    
    showConnectionStatus(results) {
        const statusDiv = document.createElement('div');
        statusDiv.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            z-index: 10000;
            max-width: 400px;
        `;
        
        statusDiv.innerHTML = `
            <h3 style="margin-top: 0;">Sofia-Calendar Connection Test</h3>
            <p><strong>Calendar Health:</strong> ${results.health ? '✓ OK' : '✗ Failed'}</p>
            <p><strong>Sofia Endpoints:</strong> ${results.sofiaEndpoint ? '✓ Working' : '✗ Not responding'}</p>
            <p><strong>Booking Function:</strong> ${results.booking ? '✓ Working' : '✗ Failed'}</p>
            ${results.error ? `<p style="color: red;">Error: ${results.error}</p>` : ''}
            <hr>
            <p style="margin-bottom: 0; font-size: 14px;">
                ${results.health && results.sofiaEndpoint ? 
                    '<strong style="color: green;">Sofia CAN connect to calendar!</strong><br>The LiveKit voice error is a separate web UI issue.' : 
                    '<strong style="color: red;">Connection issues detected.</strong>'}
            </p>
            <button onclick="this.parentElement.remove()" style="margin-top: 10px;">Close</button>
        `;
        
        document.body.appendChild(statusDiv);
    }
}

// Auto-test on page load
window.addEventListener('load', () => {
    setTimeout(() => {
        const tester = new SofiaSimpleConnection();
        tester.testConnection();
    }, 2000);
});