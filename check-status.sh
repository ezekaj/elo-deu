#!/bin/bash

echo "🔍 Checking Sofia Dental AI Status"
echo "=================================="
echo ""

# Check tunnels
echo "📡 Cloudflare Tunnels:"
if pgrep -f "cloudflared.*3005" > /dev/null; then
    echo "✅ Calendar API tunnel is running"
else
    echo "❌ Calendar API tunnel is NOT running"
fi

if pgrep -f "cloudflared.*7880" > /dev/null; then
    echo "✅ Voice Service tunnel is running"
else
    echo "❌ Voice Service tunnel is NOT running"
fi

echo ""
echo "🌐 Service URLs:"
echo "Calendar: https://bulgaria-editorials-several-rack.trycloudflare.com"
echo "Voice: https://laboratories-israel-focusing-airport.trycloudflare.com"

echo ""
echo "📂 GitHub Deployment:"
if [ -d "/home/elo/elo-deu/github-deploy/.git" ]; then
    echo "✅ GitHub repository initialized"
    cd /home/elo/elo-deu/github-deploy
    echo "Latest commit: $(git log --oneline -1)"
else
    echo "❌ GitHub repository not found"
fi

echo ""
echo "🚀 Next Steps:"
echo "1. Push to GitHub (see DEPLOY-TO-GITHUB.md)"
echo "2. Enable GitHub Pages in repository settings"
echo "3. Keep backend running with ./keep-running.sh"