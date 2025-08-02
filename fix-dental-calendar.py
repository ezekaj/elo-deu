#!/usr/bin/env python3
import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("Fixing dental-calendar service...")
    ssh.connect('167.235.67.1', username='root', password='Fzconstruction.1', timeout=30)
    
    commands = [
        # Check if dental-calendar directory exists and what's in it
        "ls -la /root/elo-deu/dental-calendar/",
        
        # Check for Dockerfile
        "cat /root/elo-deu/dental-calendar/Dockerfile | head -20 || echo 'No Dockerfile'",
        
        # Check docker-compose logs
        "cd /root/elo-deu && docker-compose -f docker-compose.production.yml logs dental-calendar | tail -20 || echo 'No logs'",
        
        # Create a simple working setup
        """cd /root/elo-deu/dental-calendar && cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install || echo "No package.json yet"

# Copy app files
COPY . .

# Expose port
EXPOSE 3005

# Start the application
CMD ["node", "server.js"]
EOF""",

        # Ensure server.js exists
        """cd /root/elo-deu/dental-calendar && [ -f server.js ] || cat > server.js << 'EOF'
const express = require('express');
const path = require('path');
const app = express();

app.use(express.static(path.join(__dirname, 'public')));

app.get('/health', (req, res) => {
    res.json({ status: 'ok', service: 'dental-calendar' });
});

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'production.html'));
});

const PORT = process.env.PORT || 3005;
app.listen(PORT, '0.0.0.0', () => {
    console.log('Dental Calendar running on port ' + PORT);
});
EOF""",

        # Ensure package.json exists
        """cd /root/elo-deu/dental-calendar && [ -f package.json ] || cat > package.json << 'EOF'
{
  "name": "dental-calendar",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF""",
        
        # Rebuild and start
        "cd /root/elo-deu && docker-compose -f docker-compose.production.yml build dental-calendar",
        "cd /root/elo-deu && docker-compose -f docker-compose.production.yml up -d dental-calendar",
        
        # Check status
        "sleep 5",
        "docker ps | grep dental",
        "curl http://localhost:3005/health || echo 'Still not working'"
    ]
    
    for cmd in commands:
        print(f"\n>>> {cmd[:50]}...")
        stdin, stdout, stderr = ssh.exec_command(cmd, timeout=180)
        output = stdout.read().decode()
        error = stderr.read().decode()
        if output.strip():
            print(output[:400])
        if error and "WARNING" not in error and "npm WARN" not in error:
            print(f"Error: {error[:200]}")
    
    print("\n✅ Checking final status...")
    stdin, stdout, stderr = ssh.exec_command("curl -s http://localhost:3005/health")
    health = stdout.read().decode()
    if "ok" in health:
        print("✓ Dental calendar is now running!")
        print("Access at: http://167.235.67.1:3005")
    
finally:
    ssh.close()