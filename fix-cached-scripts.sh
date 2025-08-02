#!/bin/bash
# Fix the cached script problem by removing version parameters

echo "=== Fixing Cached Script Problem ==="

# 1. Find where these scripts are being loaded from
echo "1. Finding script references in all HTML files..."
docker exec dental-app sh -c "
echo 'Searching for sofia scripts with version parameters...'
grep -r 'sofia.*\.js?v=' /app/public/*.html 2>/dev/null | head -20
"

# 2. Remove from ALL HTML files, not just production.html
echo ""
echo "2. Removing sofia scripts from ALL HTML files..."
docker exec dental-app sh -c "
# Find all HTML files
for file in /app/public/*.html; do
    if [ -f \"\$file\" ]; then
        echo \"Cleaning \$file...\"
        # Remove any script tag containing sofia
        sed -i '/<script.*sofia.*js/d' \"\$file\"
    fi
done
"

# 3. Check JavaScript files that might be loading these
echo ""
echo "3. Checking JS files for dynamic script loading..."
docker exec dental-app sh -c "
grep -r 'sofia.*\.js' /app/public/*.js 2>/dev/null | grep -v 'sofia-final' | head -10
"

# 4. The problem might be in index.html or another file
echo ""
echo "4. Checking index.html specifically..."
docker exec dental-app sh -c "
if [ -f /app/public/index.html ]; then
    echo 'Scripts in index.html:'
    grep '<script' /app/public/index.html | grep -E 'sofia|config'
    
    echo ''
    echo 'Removing sofia scripts from index.html...'
    sed -i '/<script.*sofia.*js/d' /app/public/index.html
fi
"

# 5. Force remove the actual script files
echo ""
echo "5. Removing old script files..."
docker exec dental-app sh -c "
rm -f /app/public/sofia-voice-fix.js
rm -f /app/public/sofia-force-reload.js
rm -f /app/public/sofia-voice.js
rm -f /app/public/sofia-multi-user.js
rm -f /app/public/sofia-working.js
rm -f /app/public/simple-voice.js
echo 'Old script files removed'
"

# 6. List remaining files
echo ""
echo "6. Remaining sofia files:"
docker exec dental-app sh -c "ls -la /app/public/sofia*.js 2>/dev/null || echo 'No sofia files found'"

# 7. Add cache-busting to sofia-final.js
echo ""
echo "7. Adding sofia-final.js with cache busting..."
TIMESTAMP=$(date +%s)
docker exec dental-app sh -c "
# Add to production.html with timestamp to force reload
sed -i '/<\\/body>/i \\    <script src=\"sofia-final.js?t=$TIMESTAMP\"></script>' /app/public/production.html
"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "IMPORTANT STEPS:"
echo "1. Open Chrome DevTools (F12)"
echo "2. Go to Network tab"
echo "3. Check 'Disable cache' checkbox"
echo "4. Keep DevTools open"
echo "5. Refresh the page with Ctrl+R"
echo ""
echo "This will force the browser to ignore ALL cached files."