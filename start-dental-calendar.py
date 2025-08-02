#!/usr/bin/env python3
import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("Starting dental-calendar service...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    
    commands = [
        # Check what's in docker-compose.production.yml
        "cd /root/elo-deu && cat docker-compose.production.yml | grep -A5 dental-calendar || echo 'No dental-calendar service found'",
        
        # Check all docker-compose files
        "cd /root/elo-deu && ls -la docker-compose*.yml",
        
        # Use the regular docker-compose.yml if production doesn't have dental-calendar
        "cd /root/elo-deu && cat docker-compose.yml | head -50",
        
        # Start all services with regular docker-compose
        "cd /root/elo-deu && docker-compose down",
        "cd /root/elo-deu && docker-compose up -d --build",
        
        # Wait and check
        "sleep 10",
        "docker ps",
        
        # Check if port 3005 is listening
        "netstat -tlnp | grep 3005 || echo 'Port 3005 not active'",
        
        # Test access
        "curl -I http://localhost:3005 || echo 'Service not responding on 3005'"
    ]
    
    for cmd in commands:
        print(f"\n>>> {cmd[:60]}...")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=120)
        output = stdout.read().decode()
        if output.strip():
            print(output[:600])
    
    print("\n✅ Done! Check http://167.235.67.1:3005")
    
finally:
    ssh.close()