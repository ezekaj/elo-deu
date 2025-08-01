# Sofia Dental Calendar - Complete VPS Deployment Guide

This guide provides step-by-step instructions to deploy the Sofia Dental Calendar system on a Hetzner VPS with full WebRTC voice support.

## Table of Contents

1. [System Overview](#system-overview)
2. [Prerequisites](#prerequisites)
3. [VPS Setup](#vps-setup)
4. [Domain Configuration](#domain-configuration)
5. [Deployment Process](#deployment-process)
6. [Post-Deployment](#post-deployment)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

## System Overview

### Architecture

```
┌─────────────────────┐     ┌──────────────────┐
│   GitHub Pages      │     │   Hetzner VPS    │
│  (Static Frontend)  │────▶│  (Backend APIs)  │
│  elosofia.site      │     │ api.elosofia.site│
└─────────────────────┘     └──────────────────┘
                                     │
                            ┌────────┴────────┐
                            │                 │
                      ┌─────▼─────┐    ┌─────▼─────┐
                      │  LiveKit  │    │   APIs    │
                      │  WebRTC   │    │ Calendar  │
                      │  Server   │    │   CRM     │
                      └───────────┘    └───────────┘
```

### Services

- **Dental Calendar** (Port 3005): Main appointment system
- **LiveKit** (Port 7880 + UDP 50000-60000): WebRTC voice/video
- **Sofia Agent** (Port 8080): AI voice assistant
- **CRM** (Port 5000): Customer relationship management
- **PostgreSQL**: Primary database
- **Redis**: Cache and session storage
- **TURN Server**: WebRTC relay for NAT traversal

## Prerequisites

### Required Accounts

1. **Hetzner Cloud Account**
   - Sign up at: https://www.hetzner.com/cloud
   - Add payment method
   - Generate API token (optional for automation)

2. **Domain Name**
   - Domain: elosofia.site
   - Access to DNS management

3. **API Keys**
   ```bash
   # Required API Keys:
   - OpenAI API Key (GPT-4 access)
   - Deepgram API Key (speech recognition)
   - LiveKit Cloud Account (optional, can self-host)
   - GitHub Personal Access Token
   ```

### Local Requirements

- SSH client
- Git
- Basic command line knowledge

## VPS Setup

### Step 1: Create Hetzner VPS

1. **Log into Hetzner Cloud Console**
2. **Create New Server**:
   - Location: Nuremberg or Falkenstein (low latency)
   - Image: Ubuntu 22.04 LTS
   - Type: CX21 (2 vCPU, 4GB RAM, 40GB SSD)
   - Additional features:
     - ✓ IPv4
     - ✓ IPv6
     - ✓ Backups (recommended)
   - SSH Key: Add your public key
   - Name: sofia-prod

3. **Note the IP address**: e.g., 123.456.789.0

### Step 2: Initial Server Configuration

```bash
# Connect to your VPS
ssh root@YOUR_VPS_IP

# Create deployment directory
mkdir -p /opt/deployment
cd /opt/deployment

# Download deployment package
git clone https://github.com/elodisney/sofia-deployment.git .
# OR use wget/curl to download the deployment files
```

### Step 3: Set Environment Variables

```bash
# Copy environment template
cp scripts/setup-env.sh .env.local
nano .env.local

# Set all required variables:
export VPS_IP="YOUR_VPS_IP"
export POSTGRES_PASSWORD="generate-strong-password"
export REDIS_PASSWORD="generate-strong-password"
export JWT_SECRET="generate-long-random-string"
export LIVEKIT_API_KEY="your-livekit-key"
export LIVEKIT_API_SECRET="your-livekit-secret"
export OPENAI_API_KEY="sk-..."
export DEEPGRAM_API_KEY="..."
export TURN_USERNAME="sofia"
export TURN_PASSWORD="generate-strong-password"
export GITHUB_TOKEN="ghp_..."

# Source the environment
source .env.local
```

## Domain Configuration

### Step 1: DNS Settings

Add these DNS records to your domain:

```
Type  | Name | Value           | TTL
------|------|-----------------|-----
A     | @    | YOUR_VPS_IP     | 300
A     | www  | YOUR_VPS_IP     | 300
A     | api  | YOUR_VPS_IP     | 300
AAAA  | @    | YOUR_VPS_IPv6   | 300
AAAA  | www  | YOUR_VPS_IPv6   | 300
AAAA  | api  | YOUR_VPS_IPv6   | 300
```

### Step 2: Wait for DNS Propagation

```bash
# Test DNS resolution
dig +short elosofia.site
dig +short api.elosofia.site

# Should return your VPS IP
```

## Deployment Process

### Step 1: Run Main Deployment

```bash
cd /opt/deployment
sudo ./scripts/deploy.sh
```

This script will:
1. Update system packages
2. Install Docker and dependencies
3. Configure firewall rules
4. Setup SSL certificates
5. Deploy all services
6. Configure monitoring

**Expected duration**: 15-20 minutes

### Step 2: Verify Services

```bash
# Check all services are running
docker compose ps

# Expected output:
NAME                STATUS              PORTS
dental-calendar     running             127.0.0.1:3005->3005/tcp
livekit             running             0.0.0.0:7880->7880/tcp, 50000-60000/udp
sofia-agent         running             127.0.0.1:8080->8080/tcp
crm                 running             127.0.0.1:5000->5000/tcp
postgres            running             127.0.0.1:5432->5432/tcp
redis               running             127.0.0.1:6379->6379/tcp
coturn              running             0.0.0.0:3478->3478/tcp+udp
```

### Step 3: Test Endpoints

```bash
# Test main site (should redirect to GitHub Pages)
curl -I https://elosofia.site

# Test API endpoint
curl https://api.elosofia.site/calendar/health

# Test WebSocket connectivity
curl -i -N -H "Connection: Upgrade" \
     -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Version: 13" \
     -H "Sec-WebSocket-Key: test" \
     https://api.elosofia.site/livekit
```

## Post-Deployment

### Step 1: Configure GitHub Pages

1. Update your GitHub Pages repository settings:
   ```javascript
   // In your frontend config
   const API_BASE_URL = 'https://api.elosofia.site';
   const LIVEKIT_URL = 'wss://api.elosofia.site/livekit';
   ```

2. Commit and push changes

### Step 2: Initialize Database

```bash
# Run database migrations
docker exec dental-calendar npm run migrate

# Create admin user
docker exec -it dental-calendar npm run create-admin
```

### Step 3: Test Voice Features

1. Open https://elosofia.site
2. Navigate to voice assistant
3. Grant microphone permissions
4. Test voice interaction

**Troubleshooting WebRTC**:
```bash
# Check TURN server
docker logs coturn

# Test TURN connectivity
docker exec coturn turnadmin -k -u sofia -r elosofia.site

# Check UDP ports
ss -tulpn | grep -E ':(50000|60000)'
```

### Step 4: Setup Monitoring

```bash
# Install monitoring dashboard
cp configs/monitoring-dashboard.html /var/www/html/monitor.html

# Start monitoring API
python3 scripts/monitoring-api.py &

# Access dashboard at: http://YOUR_VPS_IP/monitor.html
```

## Troubleshooting

### Common Issues

#### 1. WebRTC Connection Fails

```bash
# Check firewall
sudo ufw status verbose

# Verify UDP ports are open
sudo netstat -tulpn | grep -E '50000|60000'

# Test STUN/TURN
docker exec livekit livekit-cli test-turn \
  --host api.elosofia.site \
  --username sofia \
  --password $TURN_PASSWORD
```

#### 2. SSL Certificate Issues

```bash
# Renew certificates manually
certbot renew --force-renewal

# Check certificate
openssl x509 -in /etc/letsencrypt/live/elosofia.site/cert.pem -text -noout
```

#### 3. Service Won't Start

```bash
# Check logs
docker compose logs [service-name]

# Restart specific service
docker compose restart [service-name]

# Check resource usage
htop
df -h
```

#### 4. Database Connection Issues

```bash
# Test PostgreSQL connection
docker exec -it postgres psql -U postgres

# Check Redis
docker exec -it redis redis-cli ping
```

### Debug Commands

```bash
# Full system health check
/usr/local/bin/sofia-health-check.sh

# Watch real-time logs
docker compose logs -f

# Check nginx access logs
tail -f /var/log/nginx/access.log

# Monitor WebRTC connections
docker exec livekit livekit-cli list-rooms
```

## Maintenance

### Daily Tasks

- Monitor system health via dashboard
- Check backup completion
- Review error logs

### Weekly Tasks

```bash
# Update system packages
apt update && apt upgrade -y

# Restart services (during maintenance window)
docker compose restart

# Clean old logs
docker system prune -a --volumes
```

### Monthly Tasks

```bash
# Full system backup
/usr/local/bin/sofia-backup.sh

# Security audit
lynis audit system

# Update Docker images
docker compose pull
docker compose up -d
```

### Backup and Recovery

**Backup locations**:
- Database dumps: `/backup/sofia/`
- Configuration: `/opt/deployment/configs/`
- Docker volumes: Included in backups

**Restore process**:
```bash
# Stop services
docker compose down

# Restore from backup
tar -xzf /backup/sofia/sofia_backup_[DATE].tar.gz
docker compose up -d
```

## Security Best Practices

1. **Regular Updates**
   ```bash
   # Enable automatic security updates
   apt install unattended-upgrades
   dpkg-reconfigure -plow unattended-upgrades
   ```

2. **Monitor Access**
   ```bash
   # Check failed login attempts
   fail2ban-client status sshd
   
   # Review auth logs
   tail -f /var/log/auth.log
   ```

3. **Firewall Rules**
   - Only open required ports
   - Use fail2ban for rate limiting
   - Regular security audits

4. **Backup Encryption**
   ```bash
   # Encrypt backups
   gpg --symmetric --cipher-algo AES256 backup.tar.gz
   ```

## Support and Resources

- **System Logs**: `/var/log/sofia/`
- **Docker Logs**: `docker compose logs [service]`
- **Health Check**: `/usr/local/bin/sofia-health-check.sh`
- **Monitoring**: `https://YOUR_VPS_IP/monitor.html`

## Cost Breakdown

- **Hetzner CX21**: €4.51/month
- **Domain**: ~€12/year
- **Total**: ~€5.50/month

## Conclusion

Your Sofia Dental Calendar system is now deployed with:
- ✅ Full WebRTC voice support
- ✅ SSL/TLS encryption
- ✅ Automated backups
- ✅ Security hardening
- ✅ Monitoring and alerts
- ✅ High availability setup

The system is production-ready and configured for optimal performance.