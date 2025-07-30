#!/bin/bash
# Initial Server Setup Script for Sofia Dental Assistant
# Run this on a fresh Ubuntu 20.04+ server

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_status "Starting initial server setup..."

# Create deployment user
print_status "Creating deployment user..."
if ! id -u sofia >/dev/null 2>&1; then
    useradd -m -s /bin/bash sofia
    usermod -aG sudo sofia
    print_success "User 'sofia' created"
else
    print_success "User 'sofia' already exists"
fi

# Set up SSH key for deployment user
print_status "Setting up SSH access..."
mkdir -p /home/sofia/.ssh
chmod 700 /home/sofia/.ssh
touch /home/sofia/.ssh/authorized_keys
chmod 600 /home/sofia/.ssh/authorized_keys
chown -R sofia:sofia /home/sofia/.ssh

# System updates
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    iotop \
    nethogs \
    fail2ban \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Configure fail2ban
print_status "Configuring fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Create fail2ban SSH jail
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

systemctl restart fail2ban
print_success "Fail2ban configured"

# Configure system limits
print_status "Configuring system limits..."
cat >> /etc/security/limits.conf << 'EOF'

# Sofia Dental Assistant limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Configure sysctl for better network performance
cat > /etc/sysctl.d/99-sofia.conf << 'EOF'
# Network optimizations for Sofia
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_fastopen = 3
EOF

sysctl -p /etc/sysctl.d/99-sofia.conf
print_success "System limits configured"

# Set up log rotation
print_status "Configuring log rotation..."
cat > /etc/logrotate.d/sofia << 'EOF'
/opt/sofia-dental/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 sofia sofia
}
EOF

print_success "Log rotation configured"

# Create deployment directories
print_status "Creating deployment directories..."
mkdir -p /opt/sofia-dental
chown sofia:sofia /opt/sofia-dental

# Set up automatic security updates
print_status "Configuring automatic security updates..."
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Configure timezone
print_status "Setting timezone..."
timedatectl set-timezone Europe/Berlin

# Create systemd service for Sofia
print_status "Creating systemd service..."
cat > /etc/systemd/system/sofia-dental.service << 'EOF'
[Unit]
Description=Sofia Dental Assistant
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=sofia
WorkingDirectory=/opt/sofia-dental
ExecStart=/usr/bin/docker-compose -f docker-compose.production.yml up
ExecStop=/usr/bin/docker-compose -f docker-compose.production.yml down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
print_success "Systemd service created"

# Create backup script
print_status "Creating backup script..."
cat > /opt/sofia-dental/backup.sh << 'EOF'
#!/bin/bash
# Backup script for Sofia Dental Assistant

BACKUP_DIR="/opt/sofia-dental/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/sofia_backup_$DATE.tar.gz"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Stop services
docker-compose -f /opt/sofia-dental/docker-compose.production.yml down

# Create backup
tar -czf $BACKUP_FILE \
    /opt/sofia-dental/data \
    /opt/sofia-dental/.env \
    /opt/sofia-dental/docker-compose.production.yml

# Start services
docker-compose -f /opt/sofia-dental/docker-compose.production.yml up -d

# Keep only last 7 backups
find $BACKUP_DIR -name "sofia_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_FILE"
EOF

chmod +x /opt/sofia-dental/backup.sh
chown sofia:sofia /opt/sofia-dental/backup.sh

# Add backup cron job
echo "0 2 * * * sofia /opt/sofia-dental/backup.sh >> /opt/sofia-dental/logs/backup.log 2>&1" | tee -a /etc/crontab

print_success "Backup system configured"

# Create monitoring script
print_status "Creating monitoring script..."
cat > /opt/sofia-dental/monitor.sh << 'EOF'
#!/bin/bash
# Health monitoring script for Sofia

# Check if services are running
if ! docker-compose -f /opt/sofia-dental/docker-compose.production.yml ps | grep -q "Up"; then
    echo "Services are down! Attempting restart..."
    docker-compose -f /opt/sofia-dental/docker-compose.production.yml up -d
fi

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "Warning: Disk usage is at ${DISK_USAGE}%"
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ $MEM_USAGE -gt 80 ]; then
    echo "Warning: Memory usage is at ${MEM_USAGE}%"
fi
EOF

chmod +x /opt/sofia-dental/monitor.sh
chown sofia:sofia /opt/sofia-dental/monitor.sh

# Add monitoring cron job
echo "*/5 * * * * sofia /opt/sofia-dental/monitor.sh >> /opt/sofia-dental/logs/monitor.log 2>&1" | tee -a /etc/crontab

print_success "Monitoring configured"

# Final summary
echo ""
print_success "Server setup complete!"
echo ""
echo "Next steps:"
echo "1. Add your SSH public key to: /home/sofia/.ssh/authorized_keys"
echo "2. Switch to sofia user: su - sofia"
echo "3. Download and run the deployment script:"
echo "   wget https://raw.githubusercontent.com/ezekaj/elo-deu/master/deploy/deploy-sofia.sh"
echo "   chmod +x deploy-sofia.sh"
echo "   ./deploy-sofia.sh your-domain.com"
echo ""
echo "Security notes:"
echo "- Change the default password for 'sofia' user"
echo "- Configure SSH to disable root login and password authentication"
echo "- Review and adjust firewall rules as needed"
echo ""
print_status "Rebooting in 10 seconds to apply all changes..."
sleep 10
reboot