# Self-Hosting Solutions for Sofia Dental Calendar

## Option 1: Use Your Own VPS/Cloud Server (Recommended)
Deploy everything on a public server (AWS, DigitalOcean, Hetzner, etc.)

### Requirements:
- VPS with public IP address
- Open ports: 3005, 7880, 7881
- Docker and Docker Compose installed

### Steps:
```bash
# 1. Clone your repository on the VPS
git clone [your-repo] elo-deu
cd elo-deu

# 2. Update configuration with your domain/IP
# Edit docs/config.js to use your server's IP or domain

# 3. Run Docker Compose
docker-compose up -d

# 4. Access at http://your-server-ip:3005
```

## Option 2: Use Cloudflare Tunnel (Free Alternative to ngrok)
Cloudflare Tunnel provides free tunneling with better WebSocket support

### Installation:
```bash
# Install cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Login to Cloudflare
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create sofia-dental

# Run multiple services
cloudflared tunnel run --url http://localhost:3005 sofia-dental
# In another terminal:
cloudflared tunnel run --url ws://localhost:7880 sofia-livekit
```

## Option 3: Use Tailscale (Private Network)
If you only need access for specific users, Tailscale creates a private network

### Setup:
```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
sudo tailscale up

# Share your services
sudo tailscale serve 3005
sudo tailscale serve 7880
```

## Option 4: Port Forwarding with Dynamic DNS
If you have control over your router

### Steps:
1. Set up port forwarding:
   - Forward external port 3005 → internal 3005
   - Forward external port 7880 → internal 7880
   - Forward external port 7881 → internal 7881

2. Use dynamic DNS service (DuckDNS, No-IP)
3. Update config.js with your DNS name

## Option 5: Nginx Reverse Proxy with Let's Encrypt
Professional solution with HTTPS

### nginx.conf:
```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    location /ws {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## Option 6: Modified Architecture for Single Port
Modify the application to run everything through one port

### Changes needed:
1. Proxy LiveKit through the main app
2. Use path-based routing
3. All services on port 3005

Would you like me to implement this?