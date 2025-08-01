#!/bin/bash

echo "Setting up Cloudflare Tunnel for Sofia Dental Calendar"
echo "====================================================="

# Install cloudflared
echo "Installing cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
rm cloudflared-linux-amd64.deb

# Create config directory
mkdir -p ~/.cloudflared

# Create configuration file
cat > ~/.cloudflared/config.yml << EOF
tunnel: sofia-dental
credentials-file: /home/$USER/.cloudflared/[TUNNEL-ID].json

ingress:
  # Calendar application
  - hostname: sofia-calendar.your-domain.com
    service: http://localhost:3005
  # LiveKit WebSocket
  - hostname: sofia-livekit.your-domain.com
    service: ws://localhost:7880
  # Catch-all rule
  - service: http_status:404
EOF

echo "Next steps:"
echo "1. Run: cloudflared tunnel login"
echo "2. Run: cloudflared tunnel create sofia-dental"
echo "3. Add CNAME records in your DNS:"
echo "   - sofia-calendar.your-domain.com → [tunnel-id].cfargotunnel.com"
echo "   - sofia-livekit.your-domain.com → [tunnel-id].cfargotunnel.com"
echo "4. Run: cloudflared tunnel run sofia-dental"
echo ""
echo "This will give you:"
echo "- https://sofia-calendar.your-domain.com (Calendar)"
echo "- wss://sofia-livekit.your-domain.com (LiveKit WebSocket)"