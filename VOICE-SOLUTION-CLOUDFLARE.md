# Enable Voice Features with Cloudflare Tunnel

## Why Cloudflare Tunnel?
- **Free** for personal use
- **Supports WebRTC** (unlike ngrok)
- **Stable URLs** that don't change
- **No port forwarding** needed
- **Built-in SSL** certificates

## Step 1: Install Cloudflared

```bash
# Download and install cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

## Step 2: Authenticate with Cloudflare

```bash
cloudflared tunnel login
# This opens a browser - log in to your Cloudflare account
```

## Step 3: Create Tunnel

```bash
cloudflared tunnel create sofia-dental
# This creates a tunnel and gives you a UUID
```

## Step 4: Create Configuration

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: YOUR-TUNNEL-UUID
credentials-file: /home/elo/.cloudflared/YOUR-TUNNEL-UUID.json

ingress:
  # Calendar API
  - hostname: calendar.elosofia.site
    service: http://localhost:3005
  
  # LiveKit WebRTC
  - hostname: voice.elosofia.site
    service: http://localhost:7880
  
  # Sofia Agent
  - hostname: sofia.elosofia.site
    service: http://localhost:8080
  
  # CRM
  - hostname: crm.elosofia.site
    service: http://localhost:5000
  
  # Catch-all
  - service: http_status:404
```

## Step 5: Add DNS Records

In Cloudflare Dashboard:
1. Go to your domain (elosofia.site)
2. Add CNAME records:
   - `calendar` → `YOUR-TUNNEL-UUID.cfargotunnel.com`
   - `voice` → `YOUR-TUNNEL-UUID.cfargotunnel.com`
   - `sofia` → `YOUR-TUNNEL-UUID.cfargotunnel.com`
   - `crm` → `YOUR-TUNNEL-UUID.cfargotunnel.com`

## Step 6: Run Tunnel

```bash
# Start tunnel
cloudflared tunnel run sofia-dental

# Or as a service
sudo cloudflared service install
sudo systemctl start cloudflared
```

## Step 7: Update Configuration

Update `docs/config.js`:

```javascript
window.CONFIG = {
    API_BASE_URL: isGitHubPages 
        ? 'https://calendar.elosofia.site'
        : 'http://localhost:3005',
    
    LIVEKIT_URL: isGitHubPages
        ? 'wss://voice.elosofia.site'
        : 'ws://localhost:7880',
    
    SOFIA_URL: isGitHubPages
        ? 'https://sofia.elosofia.site'
        : 'http://localhost:8080'
};
```

## Result
✅ Voice features work perfectly through Cloudflare Tunnel
✅ WebRTC media streams properly routed
✅ Stable URLs that never change
✅ Free for personal use