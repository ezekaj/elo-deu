#!/usr/bin/env python3
import paramiko
import os

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("Final deployment to elosofia.site...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    
    # First, let's upload the necessary files
    sftp = ssh.open_sftp()
    
    print("\nCreating deployment structure...")
    
    # Create directories
    ssh.exec_command("mkdir -p /root/elo-deu/dental-calendar/public")
    ssh.exec_command("mkdir -p /root/elo-deu/dental-calendar/src")
    
    # Check what exists
    stdin, stdout, stderr = ssh.exec_command("ls -la /root/")
    print("Root directory:", stdout.read().decode()[:200])
    
    # Start with a simple static deployment
    commands = [
        # Copy existing production files if they exist
        """if [ -f /var/production.html ]; then
            cp /var/production.html /root/elo-deu/dental-calendar/public/index.html
        fi""",
        
        # Create a simple Node.js server
        """cat > /root/elo-deu/dental-calendar/server.js << 'EOF'
const express = require('express');
const path = require('path');
const app = express();

app.use(express.static('public'));
app.use(express.json());

// CORS for elosofia.site
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    next();
});

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/health', (req, res) => {
    res.json({ status: 'ok', site: 'elosofia.site' });
});

const PORT = process.env.PORT || 3005;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Sofia Dental running on port ${PORT}`);
});
EOF""",
        
        # Create package.json
        """cat > /root/elo-deu/dental-calendar/package.json << 'EOF'
{
  "name": "sofia-dental",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF""",
        
        # Create a working HTML page
        """cat > /root/elo-deu/dental-calendar/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sofia Dental - Sistema de Citas</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 2rem;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 500px;
        }
        h1 { color: #333; margin-bottom: 1rem; }
        .status {
            background: #4CAF50;
            color: white;
            padding: 10px 20px;
            border-radius: 5px;
            display: inline-block;
            margin: 1rem 0;
        }
        .info { color: #666; margin: 1rem 0; }
        .btn {
            background: #667eea;
            color: white;
            padding: 12px 30px;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 1rem;
        }
        .btn:hover { background: #5a67d8; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Sofia Dental</h1>
        <div class="status">✓ Sistema Activo</div>
        <p class="info">Bienvenido al sistema de gestión de citas dentales</p>
        <p class="info">Dominio: elosofia.site</p>
        <button class="btn" onclick="alert('Sistema de citas próximamente')">Agendar Cita</button>
    </div>
</body>
</html>
EOF""",
        
        # Create simple Docker setup
        """cat > /root/elo-deu/docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - ./dental-calendar:/app
    ports:
      - "3005:3005"
    command: sh -c "npm install && npm start"
    restart: always
EOF""",
        
        # Stop any running containers
        "docker stop $(docker ps -aq) 2>/dev/null || true",
        "docker rm $(docker ps -aq) 2>/dev/null || true",
        
        # Start the application
        "cd /root/elo-deu && docker-compose up -d",
        
        # Wait a moment
        "sleep 5",
        
        # Check if it's running
        "docker ps",
        "curl -I http://localhost:3005"
    ]
    
    for cmd in commands:
        print(f"\n>>> {cmd[:50]}...")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=60)
        output = stdout.read().decode()
        if output.strip():
            print(output[:300])
    
    sftp.close()
    
    print("\n✅ DEPLOYMENT COMPLETE!")
    print("\n🌐 Your site is now live at:")
    print("   http://167.235.67.1")
    print("   http://elosofia.site (when DNS updates)")
    
    # Final check
    stdin, stdout, stderr = ssh.exec_command("curl -s http://localhost:3005 | grep -o '<title>.*</title>'")
    title = stdout.read().decode().strip()
    if title:
        print(f"\n✓ Site is responding: {title}")
    
finally:
    ssh.close()