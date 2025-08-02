#!/usr/bin/env python3
import paramiko
import time

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("🚀 Setting up VPS...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    print("✅ Connected to VPS")
    
    commands = [
        # Clone repository
        "cd /root && git clone https://github.com/FrankZarate/elo-deu.git",
        
        # Navigate to project
        "cd /root/elo-deu && ls -la",
        
        # Copy production docker-compose
        "cd /root/elo-deu && cat > docker-compose.yml << 'EOF'\n" + open('/home/elo/elo-deu/docker-compose.production.yml').read() + "\nEOF",
        
        # Set environment and deploy
        "cd /root/elo-deu && export VPS_IP=167.235.67.1 && docker-compose up -d --build"
    ]
    
    for cmd in commands:
        print(f"\n📌 Running: {cmd[:50]}...")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=180)
        output = stdout.read().decode()
        if output:
            print(output)
        err = stderr.read().decode()
        if err and "already exists" not in err:
            print(f"Info: {err}")
        time.sleep(2)
    
    print("\n✅ Setup complete!")
    print("\n🌐 Your services:")
    print("📱 Sofia App: http://167.235.67.1:3005/production.html")
    print("🏥 Health: http://167.235.67.1:8080/health")
    
finally:
    ssh.close()