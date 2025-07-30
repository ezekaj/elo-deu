# Sofia Dental Assistant - Deployment Guide

This directory contains all scripts and configurations needed to deploy Sofia Dental Assistant on a production server.

## 🚀 Quick Start

For the fastest deployment, use the quick-start script:

```bash
wget https://raw.githubusercontent.com/ezekaj/elo-deu/master/deploy/quick-start.sh
chmod +x quick-start.sh
./quick-start.sh your-domain.com
```

## 📋 Requirements

- Ubuntu 20.04+ server
- Minimum 4GB RAM, 2 CPU cores
- Public IP address or domain name
- Root or sudo access
- Open ports: 80, 443, 7880, 7881, 50000-60000/udp

## 🛠️ Deployment Scripts

### 1. **server-setup.sh**
Initial server configuration script. Run this first on a fresh server:
```bash
sudo ./server-setup.sh
```

This script:
- Creates deployment user
- Installs system dependencies
- Configures security (fail2ban, firewall)
- Sets up automatic backups
- Configures monitoring

### 2. **deploy-sofia.sh**
Main deployment script. Run after server setup:
```bash
./deploy-sofia.sh your-domain.com
```

This script:
- Installs Docker and dependencies
- Configures firewall rules
- Sets up SSL certificates
- Deploys all Sofia services
- Configures Nginx reverse proxy

### 3. **maintenance.sh**
Daily maintenance and management:
```bash
./maintenance.sh status       # Health check
./maintenance.sh restart      # Restart services
./maintenance.sh update       # Update to latest version
./maintenance.sh backup       # Create backup
./maintenance.sh logs         # View logs
```

### 4. **health-check.sh**
Comprehensive health monitoring:
```bash
./health-check.sh
```

Shows:
- Service status
- Resource usage
- Active connections
- Recent errors
- SSL certificate status

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Web Browser   │────▶│  Nginx (443)    │
└─────────────────┘     └────────┬────────┘
                                 │
        ┌────────────────────────┼────────────────────┐
        │                        │                    │
        ▼                        ▼                    ▼
┌───────────────┐     ┌──────────────────┐  ┌─────────────┐
│Calendar (3005)│     │LiveKit (7880/81) │  │CRM (5000)   │
└───────┬───────┘     └────────┬─────────┘  └─────────────┘
        │                      │
        │              ┌───────▼────────┐
        └─────────────▶│  Sofia Agent   │
                       └────────────────┘
```

## 🔒 Security Considerations

1. **Change default LiveKit keys** in production
2. **Enable SSL** for all public endpoints
3. **Restrict firewall** to necessary ports only
4. **Regular updates**: Run system updates weekly
5. **Backup regularly**: Daily automated backups configured

## 📊 Monitoring

Optional monitoring stack available:
```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

Access monitoring dashboards:
- Prometheus: http://your-domain:9090
- Grafana: http://your-domain:3000/grafana
- Default Grafana password: `sofia_admin_2024`

## 🔧 Configuration Files

- `livekit-production.yaml` - LiveKit server configuration
- `docker-compose.monitoring.yml` - Monitoring stack
- `monitoring/` - Prometheus, Loki, and Grafana configs

## 📝 Environment Variables

Key environment variables in `.env`:
```bash
LIVEKIT_URL=ws://livekit:7880
LIVEKIT_API_KEY=devkey              # Change in production!
LIVEKIT_API_SECRET=secret           # Change in production!
GOOGLE_API_KEY=AIzaSy...            # Your Google API key
PUBLIC_URL=https://your-domain.com
```

## 🚨 Troubleshooting

### Sofia doesn't respond to voice
```bash
./maintenance.sh logs sofia-agent
./maintenance.sh reset-livekit
```

### Calendar doesn't load
```bash
./maintenance.sh logs dental-calendar
./maintenance.sh restart
```

### High resource usage
```bash
./health-check.sh
./maintenance.sh clean-docker
```

### SSL certificate issues
```bash
sudo certbot certificates
./maintenance.sh ssl-renew
```

## 📞 Support

For issues or questions:
1. Check logs: `./maintenance.sh logs`
2. Run health check: `./health-check.sh`
3. Review troubleshooting section
4. Open issue on GitHub

## 🔄 Updates

To update Sofia to the latest version:
```bash
cd /opt/sofia-dental
./maintenance.sh update
```

This will:
1. Create a backup
2. Pull latest code
3. Rebuild services
4. Restart with new version

## 🎯 Best Practices

1. **Monitor regularly**: Set up alerts for service health
2. **Backup before updates**: Always backup before major changes
3. **Test in staging**: Test updates in staging environment first
4. **Document changes**: Keep deployment log of all changes
5. **Security audits**: Regular security reviews

---

Happy deploying! 🚀 Sofia is ready to transform your dental practice.