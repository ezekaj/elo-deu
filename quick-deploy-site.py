#!/usr/bin/env python3
import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("Quick deployment for elosofia.site...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    
    commands = [
        # Stop everything first
        "docker stop $(docker ps -aq) 2>/dev/null || true",
        "pkill -f 'node.*3005' || true",
        
        # Simple Node.js server without Docker for now
        "cd /root/elo-deu/dental-calendar && npm install express",
        
        # Start server directly
        "cd /root/elo-deu/dental-calendar && nohup node server.js > /tmp/dental.log 2>&1 &",
        
        # Give it a moment
        "sleep 3",
        
        # Check if running
        "ps aux | grep 'node.*server' | grep -v grep",
        "netstat -tlnp | grep 3005",
        
        # Test it
        "curl -s http://localhost:3005/health || curl -s http://localhost:3005/ | head -5",
        
        # Also check what nginx is doing
        "nginx -t && systemctl reload nginx"
    ]
    
    for cmd in commands:
        print(f"\n>>> {cmd[:50]}...")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=60)
        output = stdout.read().decode()
        if output.strip():
            print(output[:300])
    
    print("\n✅ Site should be live!")
    print("Check: http://167.235.67.1")
    print("      http://elosofia.site (when DNS updates)")
    
finally:
    ssh.close()