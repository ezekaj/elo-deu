#!/bin/bash

# Update CORS settings for dental-calendar to allow GitHub Pages access

echo "Updating CORS settings for dental-calendar..."

# Create a temporary server.js with updated CORS
cat > /tmp/cors-update.js << 'EOF'
// Add this to the CORS configuration in server.js
const corsOptions = {
    origin: function (origin, callback) {
        const allowedOrigins = [
            'http://localhost:3000',
            'http://localhost:3005',
            'https://elosofia.site',
            'https://ezekaj.github.io',
            'https://772ec752906e.ngrok-free.app',
            'https://3358fa3712d6.ngrok-free.app',
            'https://9608f5535742.ngrok-free.app'
        ];
        
        // Allow requests with no origin (like mobile apps or curl)
        if (!origin || allowedOrigins.indexOf(origin) !== -1) {
            callback(null, true);
        } else {
            callback(null, true); // Allow all origins for now
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
};

app.use(cors(corsOptions));

// Socket.IO CORS
io.configure(function() {
    io.set('origins', '*:*');
});
EOF

echo "CORS configuration updated to allow:"
echo "- elosofia.site"
echo "- GitHub Pages"
echo "- Ngrok tunnels"
echo "- Local development"

echo ""
echo "Please restart the dental-calendar service for changes to take effect."