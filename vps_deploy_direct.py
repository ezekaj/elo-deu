#!/usr/bin/env python3
import paramiko
import time
import sys

def deploy_to_vps():
    hostname = '167.235.67.1'
    username = 'root'
    password = 'Fzconstruction.1'
    
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print("🔌 Connecting to VPS...")
        ssh.connect(hostname, username=username, password=password, timeout=30, look_for_keys=False, allow_agent=False)
        print("✅ Connected successfully!")
        
        # Execute deployment commands
        deployment_script = """
cd /root
git clone https://github.com/FrankZarate/elo-deu.git || echo "Repo exists"
cd /root/elo-deu

cat > docker-compose.yml << 'DOCKEREOF'
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
DOCKEREOF

docker-compose down 2>/dev/null || true
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

export VPS_IP=167.235.67.1
docker-compose up -d --build
"""
        
        print("\n📦 Running deployment...")
        stdin, stdout, stderr = ssh.exec_command(deployment_script, timeout=300)
        
        # Read output in real-time
        for line in stdout:
            print(line.strip())
        
        # Check for errors
        errors = stderr.read().decode()
        if errors and "WARNING" not in errors and "already exists" not in errors:
            print(f"⚠️  {errors}")
        
        print("\n✅ Deployment complete!")
        print("\n🌐 Access Sofia at: http://167.235.67.1:3005/production.html")
        
    except paramiko.AuthenticationException:
        print("❌ Authentication failed. Please check the password.")
        print("   Password should be: Fzconstruction.1")
    except Exception as e:
        print(f"❌ Error: {str(e)}")
    finally:
        ssh.close()

if __name__ == "__main__":
    deploy_to_vps()