#!/bin/bash
# Sofia Dental Calendar - Quick Deploy Script
# Run this on your fresh Ubuntu VPS for automated deployment

set -euo pipefail

echo "🚀 Sofia Dental Calendar - Quick Deploy"
echo "======================================"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root"
   echo "   Run: sudo ./quick-deploy.sh"
   exit 1
fi

# Check Ubuntu version
if ! grep -q "Ubuntu 22.04" /etc/os-release; then
    echo "⚠️  Warning: This script is tested on Ubuntu 22.04 LTS"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get VPS IP automatically
VPS_IP=$(curl -s https://ipinfo.io/ip)
echo "📍 Detected VPS IP: $VPS_IP"
read -p "Is this correct? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    read -p "Enter correct VPS IP: " VPS_IP
fi

# Set deployment directory
DEPLOY_DIR="/opt/sofia-deployment"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Download deployment files
echo "📥 Downloading deployment files..."
if command -v git &> /dev/null; then
    git clone https://github.com/elodisney/sofia-deployment.git . || {
        echo "Git clone failed, downloading as archive..."
        wget -O deployment.tar.gz https://github.com/elodisney/sofia-deployment/archive/main.tar.gz
        tar -xzf deployment.tar.gz --strip-components=1
    }
else
    apt-get update && apt-get install -y git
    git clone https://github.com/elodisney/sofia-deployment.git .
fi

# Generate secure passwords
echo "🔐 Generating secure passwords..."
export VPS_IP="$VPS_IP"
export DOMAIN_NAME="elosofia.site"
export POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
export REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
export JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-50)
export LIVEKIT_WEBHOOK_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
export TURN_USERNAME="sofia"
export TURN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Collect required API keys
echo
echo "🔑 Please provide your API keys:"
echo

read -p "OpenAI API Key (sk-...): " OPENAI_API_KEY
export OPENAI_API_KEY

read -p "Deepgram API Key: " DEEPGRAM_API_KEY
export DEEPGRAM_API_KEY

read -p "LiveKit API Key (optional, press Enter to skip): " LIVEKIT_API_KEY
export LIVEKIT_API_KEY="${LIVEKIT_API_KEY:-devkey}"

read -p "LiveKit API Secret (optional, press Enter to skip): " LIVEKIT_API_SECRET
export LIVEKIT_API_SECRET="${LIVEKIT_API_SECRET:-secret}"

read -p "GitHub Personal Access Token (for private repos): " GITHUB_TOKEN
export GITHUB_TOKEN

# Save credentials
echo "💾 Saving credentials..."
cat > credentials.env << EOF
# Sofia Deployment Credentials
# Generated on: $(date)
# KEEP THIS FILE SECURE!

export VPS_IP="$VPS_IP"
export DOMAIN_NAME="$DOMAIN_NAME"
export POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
export REDIS_PASSWORD="$REDIS_PASSWORD"
export JWT_SECRET="$JWT_SECRET"
export LIVEKIT_API_KEY="$LIVEKIT_API_KEY"
export LIVEKIT_API_SECRET="$LIVEKIT_API_SECRET"
export LIVEKIT_WEBHOOK_KEY="$LIVEKIT_WEBHOOK_KEY"
export OPENAI_API_KEY="$OPENAI_API_KEY"
export DEEPGRAM_API_KEY="$DEEPGRAM_API_KEY"
export TURN_USERNAME="$TURN_USERNAME"
export TURN_PASSWORD="$TURN_PASSWORD"
export GITHUB_TOKEN="$GITHUB_TOKEN"
EOF

chmod 600 credentials.env

# Confirm deployment
echo
echo "📋 Deployment Summary:"
echo "   Domain: $DOMAIN_NAME"
echo "   VPS IP: $VPS_IP"
echo "   Services: Dental Calendar, LiveKit, Sofia Agent, CRM"
echo "   WebRTC: Full support with TURN relay"
echo
read -p "🚀 Ready to deploy? (Y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Run deployment
echo "🏗️  Starting deployment..."
echo "This will take approximately 15-20 minutes."
echo

# Make scripts executable
chmod +x scripts/*.sh

# Run main deployment
./scripts/deploy.sh

# Success message
echo
echo "✅ Deployment Complete!"
echo "========================"
echo
echo "🌐 Your Sofia Dental Calendar is now live at:"
echo "   Main site: https://$DOMAIN_NAME"
echo "   API endpoint: https://api.$DOMAIN_NAME"
echo
echo "📊 Monitoring dashboard: http://$VPS_IP:9090/monitor"
echo
echo "🔐 Credentials saved to: $DEPLOY_DIR/credentials.env"
echo "   ⚠️  IMPORTANT: Keep this file secure!"
echo
echo "📚 Next steps:"
echo "   1. Update DNS records to point to $VPS_IP"
echo "   2. Update your GitHub Pages frontend config"
echo "   3. Test voice features at https://$DOMAIN_NAME"
echo
echo "🆘 Need help? Check:"
echo "   - Logs: docker compose logs -f"
echo "   - Health: /usr/local/bin/sofia-health-check.sh"
echo "   - Guide: $DEPLOY_DIR/DEPLOYMENT_GUIDE.md"