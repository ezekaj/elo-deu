#!/usr/bin/env python3
import paramiko
import time

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("Connecting to VPS...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    print("Connected!")
    
    # Simple commands to get started
    commands = [
        "cd /root/elo-deu && pwd",
        "docker ps",
        "export VPS_IP=167.235.67.1 && docker-compose -f docker-compose.production.yml up -d"
    ]
    
    for cmd in commands:
        print(f"\nRunning: {cmd}")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=60)
        print(stdout.read().decode())
        err = stderr.read().decode()
        if err:
            print(f"Error: {err}")
    
    print("\nDeployment started!")
    print("Access: http://167.235.67.1:3005/production.html")
    
finally:
    ssh.close()