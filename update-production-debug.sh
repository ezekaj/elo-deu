#!/bin/bash
# Add debug script to production.html

echo "Adding Sofia debug script to production..."

# Add the debug script to production.html
cd /root/elo-deu/dental-calendar/public

# Check if debug script is already included
if ! grep -q "sofia-voice-debug.js" production.html; then
    # Add before the closing body tag
    sed -i '/<\/body>/i \    <script src="sofia-voice-debug.js"></script>' production.html
    echo "✅ Added sofia-voice-debug.js to production.html"
else
    echo "✅ Debug script already included"
fi

# Restart the app container to serve the new file
docker restart $(docker ps --format "{{.Names}}" | grep -E "app|dental" | head -1)

echo ""
echo "Debug mode enabled!"
echo ""
echo "Instructions:"
echo "1. Clear browser cache (Ctrl+Shift+R)"
echo "2. Open browser console (F12)"
echo "3. Click the Sofia voice button"
echo "4. Watch for detailed debug messages in console"
echo ""
echo "Or manually test in console with: window.startSofiaVoiceDebug()"