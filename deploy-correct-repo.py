#!/usr/bin/env python3
import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("Deploying elosofia.site with correct repository...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    
    commands = [
        # Remove old repo if exists
        "rm -rf /root/elo-deu",
        
        # Clone the correct repository
        "cd /root && git clone https://github.com/ezekaj/elo-deu.git",
        
        # Go to the directory
        "cd /root/elo-deu && ls -la",
        
        # Build and start with existing docker-compose
        "cd /root/elo-deu && docker-compose -f docker-compose.production.yml down || true",
        "cd /root/elo-deu && docker-compose -f docker-compose.production.yml up -d --build",
        
        # Check status
        "docker ps",
        
        # Test the site
        "sleep 5 && curl -I http://localhost:3005"
    ]
    
    for cmd in commands:
        print(f"\n>>> {cmd}")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=120)
        output = stdout.read().decode()
        error = stderr.read().decode()
        
        if output:
            print(output[:500])
        if error and "WARNING" not in error:
            print(f"Note: {error[:200]}")
    
    print("\n✅ Deployment complete!")
    print("Access at: http://167.235.67.1")
    print("          http://elosofia.site (after DNS)")
    
finally:
    ssh.close()