#!/bin/bash

echo "======================================"
echo "Simple GitHub Pages + Tunnels Deploy"
echo "======================================"
echo ""
echo "This will deploy the frontend to elosofia.site (GitHub Pages)"
echo "and keep the backend on the free tunnels."
echo ""

# Create deployment directory
mkdir -p elosofia-deploy

# Copy frontend files
cp -r docs/* elosofia-deploy/

# Update config to use tunnel URLs
cat > elosofia-deploy/config.js << 'EOF'
/**
 * Configuration for elosofia.site
 * Frontend on GitHub Pages, Backend on tunnels
 */

window.SOFIA_CONFIG = {
    // These are your current tunnel URLs
    API_BASE_URL: 'https://impacts-approximate-florist-cartridges.trycloudflare.com',
    CRM_URL: 'https://impacts-approximate-florist-cartridges.trycloudflare.com',
    LIVEKIT_URL: 'wss://maximum-topic-malawi-ltd.trycloudflare.com',
    LIVEKIT_API_URL: 'https://maximum-topic-malawi-ltd.trycloudflare.com',
    WS_URL: 'wss://impacts-approximate-florist-cartridges.trycloudflare.com',
    
    ENVIRONMENT: 'production',
    
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};

console.log('Sofia Dental Calendar - Running on elosofia.site');
console.log('Backend services via Cloudflare tunnels');
EOF

# Create index file for GitHub Pages
cat > elosofia-deploy/index-redirect.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Sofia Dental - Redirecting...</title>
    <meta http-equiv="refresh" content="0; url=index.html">
</head>
<body>
    <p>Redirecting to Sofia Dental Calendar...</p>
    <a href="index.html">Click here if not redirected</a>
</body>
</html>
EOF

# Create README for GitHub
cat > elosofia-deploy/README.md << 'EOF'
# Sofia Dental Calendar

Live at: https://elosofia.site

This is the frontend for Sofia Dental Calendar system.
Backend services run on secure tunnels.

## Features
- 📅 Appointment scheduling
- 🎤 Voice assistant (Sofia)
- 📊 CRM Dashboard
- 🔄 Real-time updates
EOF

echo ""
echo "✅ Deployment files created in ./elosofia-deploy/"
echo ""
echo "Next steps:"
echo "=========="
echo "1. Create a new GitHub repository (or use existing)"
echo "2. Push the elosofia-deploy folder contents:"
echo ""
echo "   cd elosofia-deploy"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Deploy Sofia Dental to GitHub Pages'"
echo "   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
echo "   git push -u origin main"
echo ""
echo "3. In GitHub repo settings:"
echo "   - Go to Settings > Pages"
echo "   - Source: Deploy from branch"
echo "   - Branch: main"
echo "   - Folder: / (root)"
echo ""
echo "4. Update DNS (if needed):"
echo "   - Add CNAME record: elosofia.site -> YOUR_USERNAME.github.io"
echo "   - Or add A records to GitHub Pages IPs"
echo ""
echo "Your site will be live at: https://elosofia.site"
echo ""
echo "⚠️  Important: Keep the tunnel scripts running for backend!"