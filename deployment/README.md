# Sofia Dental Calendar - VPS Deployment Package

This package contains everything needed to deploy the Sofia Dental Calendar system on a Hetzner VPS with full WebRTC voice support.

## 🚀 Quick Start

For the fastest deployment on a fresh Ubuntu 22.04 VPS:

```bash
# Download and run quick deploy
wget https://raw.githubusercontent.com/elodisney/sofia-deployment/main/quick-deploy.sh
chmod +x quick-deploy.sh
sudo ./quick-deploy.sh
```

## 📁 Package Contents

```
deployment/
├── docker-compose.yml          # Main orchestration file
├── configs/                    # Service configurations
│   ├── nginx.conf             # Nginx main config
│   ├── elosofia.site.conf     # Site-specific Nginx config
│   ├── livekit.yaml           # LiveKit WebRTC config
│   ├── turnserver.conf        # TURN server config
│   └── monitoring-dashboard.html # Web monitoring interface
├── scripts/                    # Deployment automation
│   ├── deploy.sh              # Main deployment script
│   ├── setup-firewall.sh      # Firewall configuration
│   ├── setup-env.sh           # Environment setup helper
│   ├── troubleshoot-webrtc.sh # WebRTC diagnostics
│   └── monitoring-api.py      # Monitoring API service
├── docs/                       # Documentation
│   └── DEPLOYMENT_GUIDE.md    # Comprehensive guide
├── quick-deploy.sh            # One-command deployment
└── README.md                  # This file
```

## 🔧 Manual Deployment

If you prefer step-by-step control:

1. **Set environment variables**:
   ```bash
   source scripts/setup-env.sh
   ```

2. **Run deployment**:
   ```bash
   sudo ./scripts/deploy.sh
   ```

## 🌐 System Architecture

- **Frontend**: GitHub Pages (elosofia.site)
- **Backend**: Hetzner VPS (api.elosofia.site)
- **Services**: 
  - Dental Calendar API
  - LiveKit WebRTC Server
  - Sofia AI Voice Agent
  - CRM System
  - PostgreSQL Database
  - Redis Cache
  - TURN Relay Server

## 🔒 Security Features

- SSL/TLS encryption (Let's Encrypt)
- Firewall rules (UFW)
- Fail2ban intrusion prevention
- Automated security updates
- Docker network isolation
- Regular automated backups

## 📊 Monitoring

Access the monitoring dashboard after deployment:
- URL: `http://YOUR_VPS_IP:9090/monitor`
- Health checks: `/usr/local/bin/sofia-health-check.sh`
- Logs: `docker compose logs -f [service]`

## 🆘 Troubleshooting

For WebRTC/voice issues:
```bash
./scripts/troubleshoot-webrtc.sh
```

## 📝 Requirements

- **VPS**: Ubuntu 22.04 LTS (2 vCPU, 4GB RAM minimum)
- **Domain**: DNS control for elosofia.site
- **API Keys**: OpenAI, Deepgram, LiveKit (optional)
- **Ports**: 80, 443, 3478, 7880-7881, 50000-60000/udp

## 💰 Cost

- Hetzner CX21 VPS: €4.51/month
- Domain: ~€1/month
- **Total**: ~€5.50/month

## 📚 Documentation

See `DEPLOYMENT_GUIDE.md` for detailed instructions.

## ⚡ Features

✅ One-command deployment  
✅ WebRTC voice calling  
✅ Automatic SSL setup  
✅ Built-in monitoring  
✅ Automated backups  
✅ Production-ready  

---

Built with ❤️ for the Sofia Dental Calendar System