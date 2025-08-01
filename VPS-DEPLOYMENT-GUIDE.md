# Deploy to VPS for Full Voice Support

## Recommended VPS Providers
- **Hetzner** (Germany): €4.51/month - Best value
- **DigitalOcean**: $6/month - Easy to use
- **Linode**: $5/month - Good performance
- **Vultr**: $5/month - Global locations

## Quick Deployment Guide

### 1. Get a VPS
```bash
# Example: Hetzner Cloud
# - CX11: 2GB RAM, 20GB SSD, €4.51/month
# - Location: Nuremberg/Frankfurt (low latency)
```

### 2. Initial Setup
```bash
# SSH into your VPS
ssh root@your-vps-ip

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
apt install docker-compose -y

# Install Nginx
apt install nginx certbot python3-certbot-nginx -y
```

### 3. Clone Repository
```bash
cd /opt
git clone https://github.com/ezekaj/elo-deu.git
cd elo-deu
```

### 4. Configure Nginx
Create `/etc/nginx/sites-available/elosofia`:

```nginx
# Main site (GitHub Pages)
server {
    server_name elosofia.site www.elosofia.site;
    
    location / {
        proxy_pass https://ezekaj.github.io/elo-deu/;
        proxy_set_header Host ezekaj.github.io;
    }
}

# Calendar API
server {
    server_name api.elosofia.site;
    
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# LiveKit WebRTC
server {
    server_name voice.elosofia.site;
    
    location / {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 5. Enable Site & SSL
```bash
ln -s /etc/nginx/sites-available/elosofia /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx

# Get SSL certificates
certbot --nginx -d elosofia.site -d www.elosofia.site -d api.elosofia.site -d voice.elosofia.site
```

### 6. Update DNS
Point these to your VPS IP:
- `elosofia.site` → VPS IP
- `api.elosofia.site` → VPS IP  
- `voice.elosofia.site` → VPS IP

### 7. Start Services
```bash
cd /opt/elo-deu
docker-compose up -d
```

### 8. Update Frontend Config
```javascript
window.CONFIG = {
    API_BASE_URL: 'https://api.elosofia.site',
    LIVEKIT_URL: 'wss://voice.elosofia.site',
    WS_URL: 'wss://api.elosofia.site'
};
```

## Cost: ~€5/month
## Result: Full voice support with WebRTC!