#!/bin/bash
# Remove ALL old Sofia scripts cleanly

echo "=== Removing ALL Old Sofia Scripts ==="

# 1. First, backup production.html
echo "1. Creating backup..."
docker exec dental-app cp /app/public/production.html /app/public/production.html.backup-$(date +%s)

# 2. Remove all Sofia script lines from production.html
echo ""
echo "2. Removing all Sofia scripts from production.html..."
docker exec dental-app sh -c "
# Remove any line containing sofia scripts
sed -i '/sofia-voice-fix.js/d' /app/public/production.html
sed -i '/sofia-force-reload.js/d' /app/public/production.html
sed -i '/sofia-voice.js/d' /app/public/production.html
sed -i '/sofia-multi-user.js/d' /app/public/production.html
sed -i '/sofia-working.js/d' /app/public/production.html
sed -i '/sofia.js/d' /app/public/production.html
sed -i '/simple-voice.js/d' /app/public/production.html
sed -i '/sofia-final.js/d' /app/public/production.html

echo 'Removed all Sofia script references'
"

# 3. Show what's left
echo ""
echo "3. Checking what scripts remain..."
docker exec dental-app sh -c "
echo 'Script tags in production.html:'
grep '<script' /app/public/production.html
"

# 4. Add only the final Sofia script
echo ""
echo "4. Adding ONLY sofia-final.js..."
docker exec dental-app sh -c "
# Add sofia-final.js before </body>
if ! grep -q 'sofia-final.js' /app/public/production.html; then
    sed -i '/<\\/body>/i \\    <script src=\"sofia-final.js\"></script>' /app/public/production.html
    echo 'Added sofia-final.js'
else
    echo 'sofia-final.js already present'
fi
"

# 5. Verify the changes
echo ""
echo "5. Final verification..."
docker exec dental-app sh -c "
echo 'Sofia scripts in production.html:'
grep 'sofia' /app/public/production.html || echo 'No sofia scripts found!'
"

echo ""
echo "=== Removal Complete ==="
echo ""
echo "Now you MUST:"
echo "1. Clear browser cache (Ctrl+Shift+Delete > Cached images and files)"
echo "2. Close the browser tab"
echo "3. Open a new tab and go to https://elosofia.site"
echo ""
echo "The old scripts are removed. Only sofia-final.js will load."