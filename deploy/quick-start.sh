#!/bin/bash
# Quick Start Script - Deploy Sofia in 5 minutes

set -e

echo "🚀 Sofia Dental Assistant - Quick Deployment"
echo "==========================================="
echo ""

# Check if domain provided
if [ -z "$1" ]; then
    echo "Usage: ./quick-start.sh <domain-or-ip>"
    echo "Example: ./quick-start.sh sofia.example.com"
    echo "Example: ./quick-start.sh 192.168.1.100"
    exit 1
fi

DOMAIN=$1

echo "📋 Pre-flight checks..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ Please run as non-root user with sudo access"
   exit 1
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Installing..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed"
else
    echo "✅ Docker found"
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Installing..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
else
    echo "✅ Docker Compose found"
fi

echo ""
echo "🔧 Deploying Sofia to $DOMAIN..."
echo ""

# Download and run deployment script
wget -O deploy-sofia.sh https://raw.githubusercontent.com/ezekaj/elo-deu/master/deploy/deploy-sofia.sh
chmod +x deploy-sofia.sh

# Run deployment
./deploy-sofia.sh $DOMAIN

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "Access Sofia at:"
if [[ $DOMAIN =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "  → http://$DOMAIN"
else
    echo "  → https://$DOMAIN"
fi
echo ""
echo "Test voice assistant:"
echo "  1. Click 'Sofia Agent' button"
echo "  2. Allow microphone access"
echo "  3. Speak in German"
echo ""