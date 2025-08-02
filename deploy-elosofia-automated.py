#!/usr/bin/env python3
import paramiko
import time

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("======================================")
    print("Deploying to elosofia.site (167.235.67.1)")
    print("======================================")
    print("Connecting to VPS...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    print("Connected successfully!")
    
    # Commands for deployment
    commands = [
        # Update system
        "apt-get update -y",
        
        # Install Docker if needed
        "which docker || (curl -fsSL https://get.docker.com | sh)",
        
        # Install Docker Compose if needed
        'which docker-compose || (curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose)',
        
        # Install nginx if needed
        "which nginx || apt-get install -y nginx certbot python3-certbot-nginx",
        
        # Update repository
        "cd /root && ([ -d elo-deu ] && cd elo-deu && git pull || git clone https://github.com/FrankZarate/elo-deu.git && cd elo-deu)",
        
        # Create nginx config
        """cat > /etc/nginx/sites-available/elosofia.site << 'EOF'
server {
    listen 80;
    server_name elosofia.site www.elosofia.site 167.235.67.1;

    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /ws {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /twirp/ {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF""",
        
        # Enable nginx site
        "ln -sf /etc/nginx/sites-available/elosofia.site /etc/nginx/sites-enabled/",
        "rm -f /etc/nginx/sites-enabled/default",
        "nginx -t",
        "systemctl restart nginx",
        
        # Stop existing containers
        "docker stop $(docker ps -aq) || true",
        "docker rm $(docker ps -aq) || true",
        
        # Start services
        "cd /root/elo-deu && export VPS_IP=167.235.67.1 && docker-compose -f docker-compose.production.yml up -d --build",
        
        # Check status
        "docker ps"
    ]
    
    for cmd in commands:
        print(f"\n>>> Running: {cmd[:80]}...")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=300)
        output = stdout.read().decode()
        error = stderr.read().decode()
        
        if output:
            print(output[:500])  # Limit output
        if error and "WARNING" not in error:
            print(f"Note: {error[:200]}")
    
    print("\n======================================")
    print("Deployment Complete!")
    print("======================================")
    print("\nYour site is now accessible at:")
    print("- http://167.235.67.1 (immediately)")
    print("- http://elosofia.site (after DNS propagates)")
    print("\nOnce DNS propagates, run this on VPS for SSL:")
    print("certbot --nginx -d elosofia.site -d www.elosofia.site")
    
finally:
    ssh.close()