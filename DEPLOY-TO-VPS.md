# Deploy Sofia to VPS - Quick Guide

## 🚀 One-Command Deployment

On your fresh Ubuntu 22.04 VPS (Hetzner CX21 recommended):

```bash
wget https://raw.githubusercontent.com/ezekaj/elo-deu/master/deployment/quick-deploy.sh
chmod +x quick-deploy.sh
sudo ./quick-deploy.sh
```

This will:
- ✅ Install all dependencies
- ✅ Set up Docker and services
- ✅ Configure firewall for WebRTC
- ✅ Deploy Sofia with voice features working
- ✅ Set up monitoring and backups

## 📋 Prerequisites

1. **Get a VPS** (€4.51/month)
   ```
   Hetzner Cloud → Create Server → CX21 → Ubuntu 22.04
   ```

2. **Point domain to VPS**
   ```
   api.elosofia.site → YOUR_VPS_IP
   voice.elosofia.site → YOUR_VPS_IP
   ```

3. **Update frontend config**
   Edit `docs/config.js`:
   ```javascript
   VPS_IP: 'YOUR_VPS_IP_HERE'
   ```

## 🎯 What You Get

- ✅ **Voice Features Working** - WebRTC with proper UDP support
- ✅ **All Services Running** - Calendar, Sofia AI, CRM
- ✅ **SSL Certificates** - Automatic with Let's Encrypt
- ✅ **Monitoring Dashboard** - http://YOUR_VPS_IP:9090/monitor
- ✅ **Automated Backups** - Daily at 3 AM

## 🔧 Manual Steps

If quick deploy fails, run these:

```bash
# 1. Update system
apt update && apt upgrade -y

# 2. Install Docker
curl -fsSL https://get.docker.com | sh

# 3. Clone repository
cd /opt
git clone https://github.com/ezekaj/elo-deu.git
cd elo-deu/deployment

# 4. Run deployment
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# 5. Set up firewall
./scripts/setup-firewall.sh
```

## 🧪 Test Voice Features

1. Open https://elosofia.site
2. Click "Sofia Agent" button
3. Allow microphone access
4. Voice should work perfectly!

## 🛠️ Troubleshooting

```bash
# Check services
docker ps

# View logs
docker-compose logs -f

# Test WebRTC
./scripts/troubleshoot-webrtc.sh

# Monitor dashboard
http://YOUR_VPS_IP:9090/monitor
```

## 💰 Total Cost

- Hetzner CX21: €4.51/month
- Domain: ~€10/year
- **Total**: ~€5.50/month

## 📞 Support

Check deployment logs in `/opt/sofia-deployment/logs/`