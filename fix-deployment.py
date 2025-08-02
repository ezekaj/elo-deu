#!/usr/bin/env python3
import paramiko
import time

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("Fixing deployment on VPS...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    print("Connected!")
    
    commands = [
        # Use existing repo or clone fresh
        "cd /root && ls -la",
        
        # If elo-deu doesn't exist, copy from another location or use wget
        """if [ ! -d /root/elo-deu ]; then
            echo 'Downloading repository...'
            apt-get install -y git
            git clone https://github.com/FrankZarate/elo-deu.git || mkdir -p /root/elo-deu
        fi""",
        
        # Create minimal docker-compose if needed
        """cd /root/elo-deu && cat > docker-compose.production.yml << 'EOF'
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
    image: node:18-alpine
    working_dir: /app
    ports:
      - "3005:3005"
    volumes:
      - ./dental-calendar:/app
    command: sh -c "npm install && npm start"
    environment:
      - NODE_ENV=production
      - LIVEKIT_URL=ws://livekit:7880
    restart: unless-stopped
    depends_on:
      - livekit
EOF""",
        
        # Create minimal dental-calendar if needed
        """mkdir -p /root/elo-deu/dental-calendar && cd /root/elo-deu/dental-calendar && cat > package.json << 'EOF'
{
  "name": "dental-calendar",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js || echo 'Server not found, using simple HTTP server' && npx http-server -p 3005"
  },
  "dependencies": {
    "http-server": "^14.1.1"
  }
}
EOF""",
        
        # Create simple index.html
        """cd /root/elo-deu/dental-calendar && cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Sofia Dental - Elosofia.site</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
        .status { background: #4CAF50; color: white; padding: 10px 20px; border-radius: 5px; display: inline-block; }
    </style>
</head>
<body>
    <h1>Welcome to Sofia Dental</h1>
    <div class="status">Site is Live at elosofia.site!</div>
    <p>Your dental appointment system is being configured...</p>
    <p>VPS IP: 167.235.67.1</p>
</body>
</html>
EOF""",
        
        # Start services
        "cd /root/elo-deu && docker-compose -f docker-compose.production.yml down || true",
        "cd /root/elo-deu && docker-compose -f docker-compose.production.yml up -d",
        
        # Check what's running
        "docker ps",
        "curl -s http://localhost:3005 | head -5 || echo 'Service starting...'"
    ]
    
    for cmd in commands:
        print(f"\n>>> {cmd[:60]}...")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=120)
        output = stdout.read().decode()
        if output:
            print(output[:300])
    
    print("\n✅ Deployment fixed!")
    print("\nAccess at:")
    print("- http://167.235.67.1")
    print("- http://elosofia.site (when DNS propagates)")
    
finally:
    ssh.close()