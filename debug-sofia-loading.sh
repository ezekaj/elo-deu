#!/bin/bash
# Debug why Sofia script isn't loading

echo "=== Debugging Sofia Script Loading ==="

# 1. Check what HTML file is being served
echo "1. Checking which HTML file is being served..."
docker exec dental-app sh -c "
echo 'Files in public directory:'
ls -la /app/public/*.html
echo ''
echo 'Checking for sofia script in each HTML file:'
for file in /app/public/*.html; do
    echo \"=== \$file ===\"
    grep 'sofia' \$file || echo 'No sofia reference'
done
"

# 2. Check if the route is serving production.html or something else
echo ""
echo "2. Checking server.js routing..."
docker exec dental-app sh -c "
grep -A5 -B5 'sendFile\\|static\\|html' /app/server.js | head -30
"

# 3. The issue might be that index.html is being served instead
echo ""
echo "3. Adding sofia-final.js to ALL HTML files..."
docker exec dental-app sh -c "
for file in /app/public/*.html; do
    if [ -f \"\$file\" ]; then
        echo \"Adding to \$file...\"
        # Remove any existing sofia scripts
        sed -i '/<script.*sofia.*js/d' \"\$file\"
        # Add sofia-final.js before </body>
        sed -i '/<\\/body>/i \\    <script src=\"sofia-final.js\"></script>' \"\$file\"
    fi
done
"

# 4. Create a test endpoint to check which file is served
echo ""
echo "4. Creating test endpoint..."
cat > /tmp/which-file.js << 'EOF'
// Add this to server.js to debug
app.get('/debug/which-file', (req, res) => {
    res.json({
        publicDir: __dirname + '/public',
        files: require('fs').readdirSync(__dirname + '/public').filter(f => f.endsWith('.html'))
    });
});
EOF

# 5. Check if sofia-final.js exists and is accessible
echo ""
echo "5. Testing sofia-final.js accessibility..."
curl -s http://localhost:3005/sofia-final.js | head -5
if [ $? -eq 0 ]; then
    echo "✓ sofia-final.js is accessible"
else
    echo "✗ sofia-final.js NOT accessible"
fi

# 6. Try a different approach - inject directly into the page
echo ""
echo "6. Creating auto-loader script..."
cat > /tmp/sofia-loader.js << 'EOF'
// Auto-load Sofia when page loads
(function() {
    console.log('[Sofia Loader] Checking for Sofia...');
    
    // Check if Sofia is already loaded
    if (window.Sofia) {
        console.log('[Sofia Loader] Sofia already loaded');
        return;
    }
    
    // Load Sofia script
    const script = document.createElement('script');
    script.src = '/sofia-final.js';
    script.onload = () => console.log('[Sofia Loader] Sofia script loaded');
    script.onerror = () => console.error('[Sofia Loader] Failed to load Sofia script');
    document.head.appendChild(script);
})();
EOF

docker cp /tmp/sofia-loader.js dental-app:/app/public/

# Add loader to calendar.js since we know that loads
echo ""
echo "7. Adding Sofia loader to calendar.js..."
docker exec dental-app sh -c "
echo '' >> /app/public/calendar.js
echo '// Load Sofia' >> /app/public/calendar.js
cat /app/public/sofia-loader.js >> /app/public/calendar.js
"

echo ""
echo "=== Debug Complete ==="
echo ""
echo "Now refresh the page and check console for:"
echo "- [Sofia Loader] messages"
echo "- [Sofia] Script loaded"
echo ""
echo "This will force Sofia to load since we know calendar.js loads."