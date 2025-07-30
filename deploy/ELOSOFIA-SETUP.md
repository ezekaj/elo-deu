# 🚀 Quick Setup Guide for elosofia.site

## Step 1: Install Cloudflare Tunnel
```bash
# Download and install
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
rm cloudflared-linux-amd64.deb
```

## Step 2: Login to Cloudflare
```bash
cloudflared tunnel login
```
This will open a browser - login with your Cloudflare account (create free account if needed)

## Step 3: Create Tunnel
```bash
cloudflared tunnel create elosofia
```

## Step 4: Get Your Tunnel ID
```bash
cloudflared tunnel list
```
Copy the ID (looks like: a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6)

## Step 5: Add DNS Records in Namecheap

1. Go to: https://ap.www.namecheap.com/domains/domaincontrolpanel/elosofia.site/advancedns

2. Add these CNAME records:
   ```
   Type: CNAME    Host: @      Value: [YOUR-TUNNEL-ID].cfargotunnel.com
   Type: CNAME    Host: www    Value: [YOUR-TUNNEL-ID].cfargotunnel.com
   Type: CNAME    Host: ws     Value: [YOUR-TUNNEL-ID].cfargotunnel.com
   Type: CNAME    Host: crm    Value: [YOUR-TUNNEL-ID].cfargotunnel.com
   ```

## Step 6: Create Tunnel Config
```bash
mkdir -p ~/.cloudflared
nano ~/.cloudflared/config.yml
```

Paste this (replace YOUR-TUNNEL-ID):
```yaml
tunnel: elosofia
credentials-file: /home/elo/.cloudflared/YOUR-TUNNEL-ID.json

ingress:
  - hostname: elosofia.site
    service: http://localhost:3005
  - hostname: www.elosofia.site
    service: http://localhost:3005
  - hostname: ws.elosofia.site
    service: ws://localhost:7880
  - hostname: crm.elosofia.site
    service: http://localhost:5000
  - service: http_status:404
```

## Step 7: Update Sofia Frontend
```bash
cd /home/elo/elo-deu
sed -i 's|ws://localhost:7880|wss://ws.elosofia.site|g' dental-calendar/public/sofia-real-connection.js
sed -i 's|http://localhost:3005|https://elosofia.site|g' dental-calendar/public/sofia-real-connection.js
```

## Step 8: Start Everything
```bash
# Start Sofia services
cd /home/elo/elo-deu
docker-compose up -d

# Start Cloudflare tunnel
cloudflared tunnel run elosofia
```

## Step 9: Make it Permanent
In a new terminal:
```bash
# Install as service
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

## 🎉 Done!
Your Sofia assistant is now live at:
- Main App: https://elosofia.site
- CRM: https://crm.elosofia.site

## 🔧 Troubleshooting
- Check services: `docker-compose ps`
- Check tunnel: `sudo systemctl status cloudflared`
- View logs: `docker-compose logs -f`