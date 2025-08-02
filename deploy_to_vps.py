#!/usr/bin/env python3
import paramiko
import time

# VPS credentials
hostname = '167.235.67.1'
username = 'root'
password = 'Fzconstruction.1'

print("🚀 Connecting to VPS...")

# Create SSH client
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    # Connect to VPS
    ssh.connect(hostname, username=username, password=password)
    print("✅ Connected to VPS")
    
    # Commands to run
    commands = [
        "cd /root/elo-deu",
        "docker stop $(docker ps -aq) 2>/dev/null || true",
        "docker rm $(docker ps -aq) 2>/dev/null || true",
        "docker network prune -f",
        """docker run -d --name livekit -p 7880:7880 -p 30000-40000:30000-40000/udp -e LIVEKIT_KEYS="devkey: secret" livekit/livekit-server:latest --dev""",
        "sleep 5",
        """cd /root/elo-deu && docker-compose -f docker-compose.production.yml up -d --build"""
    ]
    
    # Execute commands
    for cmd in commands:
        print(f"\n📌 Running: {cmd}")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        
        # Print output
        output = stdout.read().decode()
        if output:
            print(output)
        
        # Print errors
        errors = stderr.read().decode()
        if errors and "WARNING" not in errors:
            print(f"⚠️  {errors}")
        
        time.sleep(2)
    
    print("\n✅ Deployment complete!")
    print("\n🌐 Access your services:")
    print("📅 Calendar: http://167.235.67.1:3005")
    print("📱 Production UI: http://167.235.67.1:3005/production.html")
    print("🏥 Health Check: http://167.235.67.1:8080/health")
    
finally:
    ssh.close()