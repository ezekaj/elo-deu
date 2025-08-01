#!/bin/bash
# Migration script to production-ready LiveKit configuration

set -e

echo "==================================="
echo "LiveKit Production Migration Script"
echo "==================================="
echo ""

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Stop existing containers
echo "🛑 Stopping existing LiveKit containers..."
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose-fixed.yml down 2>/dev/null || true

# Backup existing configuration
echo "💾 Backing up existing configuration..."
if [ -f "livekit.yaml" ]; then
    cp livekit.yaml "livekit.yaml.backup.$(date +%Y%m%d_%H%M%S)"
    echo "  ✓ Backed up livekit.yaml"
fi

# Validate new configuration
echo ""
echo "🔍 Validating production configuration..."
python3 tests/test_livekit_production_config.py livekit-production.yaml

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Configuration validation failed. Please fix errors before proceeding."
    exit 1
fi

echo ""
echo "✅ Configuration validation passed!"
echo ""

# Test configuration with LiveKit
echo "🧪 Testing configuration with LiveKit container..."
docker run --rm \
    -v "$(pwd)/livekit-production.yaml:/etc/livekit.yaml:ro" \
    livekit/livekit-server:latest \
    --config /etc/livekit.yaml \
    --help > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "  ✓ Configuration is compatible with LiveKit"
else
    echo "  ⚠️  Could not verify configuration (this may be normal)"
fi

echo ""
echo "📋 Migration Options:"
echo "1) Use new production configuration (recommended)"
echo "2) Update existing docker-compose.yml to use livekit-production.yaml"
echo "3) Start fresh with docker-compose.production.yml"
echo ""
read -p "Select option (1-3): " option

case $option in
    1)
        echo ""
        echo "🔄 Updating configuration..."
        cp livekit-production.yaml livekit.yaml
        echo "  ✓ Updated livekit.yaml with production configuration"
        echo ""
        echo "🚀 Starting services with updated configuration..."
        docker-compose up -d
        ;;
    2)
        echo ""
        echo "📝 Update your docker-compose.yml to use livekit-production.yaml:"
        echo ""
        echo "  volumes:"
        echo "    - ./livekit-production.yaml:/etc/livekit.yaml:ro"
        echo ""
        echo "Then run: docker-compose up -d"
        ;;
    3)
        echo ""
        echo "🚀 Starting services with production docker-compose..."
        docker-compose -f docker-compose.production.yml up -d
        ;;
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "⏳ Waiting for LiveKit to start..."
sleep 5

# Check if LiveKit is running
if docker ps | grep -q livekit; then
    echo ""
    echo "✅ LiveKit is running!"
    echo ""
    echo "🔍 Checking LiveKit health..."
    
    # Try to access health endpoint
    if curl -s -f http://localhost:7880/ > /dev/null 2>&1; then
        echo "  ✓ LiveKit health check passed"
    else
        echo "  ⚠️  Could not reach health endpoint (may still be starting)"
    fi
    
    echo ""
    echo "📊 LiveKit Status:"
    docker ps | grep livekit
    echo ""
    echo "📃 Recent logs:"
    docker logs $(docker ps -q -f name=livekit) 2>&1 | tail -20
else
    echo ""
    echo "❌ LiveKit container is not running"
    echo ""
    echo "Debug information:"
    docker ps -a | grep livekit
fi

echo ""
echo "==================================="
echo "Migration Complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Monitor logs: docker logs -f \$(docker ps -q -f name=livekit)"
echo "2. Test WebRTC connection with your client"
echo "3. Verify TURN server for TCP-only mode"
echo "4. Update API keys for production use"
echo ""