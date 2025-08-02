#!/usr/bin/env python3
import subprocess
import os

# Write the deployment script
deploy_script = """#!/bin/bash
cd /root
git clone https://github.com/FrankZarate/elo-deu.git 2>/dev/null || echo "Repo exists"
cd /root/elo-deu

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  livekit:
    image: livekit/livekit-server:latest
    ports:
      - "7880:7880"
      - "30000-40000:30000-40000/udp"
    environment:
      - LIVEKIT_KEYS=devkey: secret
    command: --dev
    restart: unless-stopped

  dental-calendar:
    build: ./dental-calendar
    ports:
      - "3005:3005"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://167.235.67.1:7880
      - VPS_IP=167.235.67.1
    restart: unless-stopped

  sofia-agent:
    build:
      context: .
      dockerfile: Dockerfile.sofia
    ports:
      - "8080:8080"
    environment:
      - LIVEKIT_URL=ws://livekit:7880
      - GOOGLE_API_KEY=AIzaSyCGXSa68qIQNtp8WEH_zYFF3UjIHS4EW2M
    restart: unless-stopped
EOF

# Deploy
docker-compose down 2>/dev/null || true
export VPS_IP=167.235.67.1
docker-compose up -d --build

echo "Deployment complete!"
echo "Access: http://167.235.67.1:3005/production.html"
"""

# Save script locally
with open('/tmp/deploy_vps.sh', 'w') as f:
    f.write(deploy_script)

print("🚀 Deploying to VPS...")
print("\nPlease run these commands manually:")
print("\n1. First, copy the script to VPS:")
print(f"   scp /tmp/deploy_vps.sh root@167.235.67.1:/root/")
print("\n2. Then SSH to VPS and run:")
print("   ssh root@167.235.67.1")
print("   chmod +x /root/deploy_vps.sh")
print("   /root/deploy_vps.sh")
print("\n3. Access Sofia at: http://167.235.67.1:3005/production.html")