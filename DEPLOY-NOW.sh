#!/bin/bash

echo "🚀 RAPID DEPLOYMENT TO ELOSOFIA.SITE"
echo "===================================="

# Get current tunnel URLs
CALENDAR_URL="https://impacts-approximate-florist-cartridges.trycloudflare.com"
VOICE_URL="https://maximum-topic-malawi-ltd.trycloudflare.com"

# Create GitHub Pages deployment
mkdir -p elosofia-site-deploy
cp -r docs/* elosofia-site-deploy/

# Update config with current working tunnels
cat > elosofia-site-deploy/config.js << EOF
window.SOFIA_CONFIG = {
    API_BASE_URL: '$CALENDAR_URL',
    CRM_URL: '$CALENDAR_URL',
    LIVEKIT_URL: '${VOICE_URL}'.replace('https', 'wss'),
    LIVEKIT_API_URL: '$VOICE_URL',
    WS_URL: '${CALENDAR_URL}'.replace('https', 'wss'),
    ENVIRONMENT: 'production',
    FEATURES: {
        VOICE_ENABLED: true,
        REALTIME_UPDATES: true,
        DEMO_MODE: false
    }
};
EOF

# Create CNAME file for GitHub Pages
echo "elosofia.site" > elosofia-site-deploy/CNAME

# Create professional landing page
cat > elosofia-site-deploy/landing.html << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sofia Dental - KI-Zahnarztpraxis</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 60px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 600px;
        }
        h1 { 
            color: #333; 
            margin-bottom: 20px;
            font-size: 3em;
        }
        .subtitle {
            color: #666;
            font-size: 1.3em;
            margin-bottom: 40px;
        }
        .features {
            text-align: left;
            margin: 40px 0;
        }
        .feature {
            padding: 15px 0;
            border-bottom: 1px solid #eee;
        }
        .feature:last-child { border: none; }
        .cta-button {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 20px 60px;
            border-radius: 50px;
            text-decoration: none;
            font-size: 1.3em;
            transition: all 0.3s;
            margin-top: 20px;
        }
        .cta-button:hover {
            background: #5a6fd8;
            transform: translateY(-2px);
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.4);
        }
        .logo { font-size: 4em; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🦷</div>
        <h1>Sofia Dental</h1>
        <p class="subtitle">Die erste KI-gestützte Zahnarztpraxis</p>
        
        <div class="features">
            <div class="feature">✅ Online Terminbuchung 24/7</div>
            <div class="feature">🎤 KI-Sprachassistentin Sofia</div>
            <div class="feature">📅 Intelligente Terminverwaltung</div>
            <div class="feature">🔄 Echtzeit-Updates</div>
            <div class="feature">📊 Digitales Praxismanagement</div>
        </div>
        
        <a href="index.html" class="cta-button">Zur Terminbuchung →</a>
    </div>
</body>
</html>
EOF

# Copy landing as index for GitHub to recognize
cp elosofia-site-deploy/landing.html elosofia-site-deploy/start.html
mv elosofia-site-deploy/index.html elosofia-site-deploy/calendar.html

# Create new index that redirects
cat > elosofia-site-deploy/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Sofia Dental</title>
    <meta http-equiv="refresh" content="0; url=calendar.html">
</head>
<body>
    <p>Loading Sofia Dental Calendar...</p>
</body>
</html>
EOF

# Initialize git repo
cd elosofia-site-deploy
git init
git add .
git commit -m "Deploy Sofia Dental to elosofia.site"

echo ""
echo "✅ READY FOR DEPLOYMENT!"
echo "========================"
echo ""
echo "Quick Deploy Commands:"
echo "====================="
echo ""
echo "cd elosofia-site-deploy"
echo "git remote add origin https://github.com/YOUR_USERNAME/elosofia-site.git"
echo "git push -u origin main"
echo ""
echo "Or if repository exists:"
echo "git push --force origin main"
echo ""
echo "Your site will be LIVE at: https://elosofia.site"
echo ""
echo "Backend services running at:"
echo "- Calendar API: $CALENDAR_URL"
echo "- Voice Service: $VOICE_URL"
echo ""
echo "⏰ This will work IMMEDIATELY after push!"