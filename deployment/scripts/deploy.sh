#!/bin/bash
set -euo pipefail

# Sofia Dental Calendar - Main Deployment Script
# This script deploys the complete system on a fresh Ubuntu VPS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOMAIN_NAME="${DOMAIN_NAME:-elosofia.site}"
VPS_IP="${VPS_IP:-}"
DEPLOY_ENV="${DEPLOY_ENV:-production}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# Check required environment variables
check_env() {
    local required_vars=(
        "VPS_IP"
        "POSTGRES_PASSWORD"
        "REDIS_PASSWORD"
        "JWT_SECRET"
        "LIVEKIT_API_KEY"
        "LIVEKIT_API_SECRET"
        "LIVEKIT_WEBHOOK_KEY"
        "OPENAI_API_KEY"
        "DEEPGRAM_API_KEY"
        "TURN_USERNAME"
        "TURN_PASSWORD"
        "GITHUB_TOKEN"
    )
    
    log_info "Checking environment variables..."
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Missing required environment variable: $var"
            exit 1
        fi
    done
    log_info "All required environment variables are set"
}

# Update system
update_system() {
    log_info "Updating system packages..."
    apt-get update
    apt-get upgrade -y
    apt-get install -y \
        curl \
        wget \
        git \
        htop \
        ufw \
        fail2ban \
        certbot \
        python3-certbot-nginx \
        nginx \
        docker.io \
        docker-compose \
        postgresql-client \
        redis-tools \
        jq \
        netcat \
        dnsutils \
        vim
}

# Configure system settings
configure_system() {
    log_info "Configuring system settings..."
    
    # Increase file descriptors
    cat >> /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
EOF
    
    # Optimize network settings for WebRTC
    cat >> /etc/sysctl.conf << EOF
# WebRTC optimization
net.core.rmem_max = 26214400
net.core.rmem_default = 26214400
net.core.wmem_max = 26214400
net.core.wmem_default = 26214400
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# Security
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
    
    sysctl -p
}

# Setup Docker
setup_docker() {
    log_info "Setting up Docker..."
    
    # Add current user to docker group
    usermod -aG docker $SUDO_USER || true
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Install Docker Compose v2
    if ! docker compose version &> /dev/null; then
        log_info "Installing Docker Compose v2..."
        apt-get install -y docker-compose-plugin
    fi
}

# Setup SSL certificates
setup_ssl() {
    log_info "Setting up SSL certificates..."
    
    # Stop nginx temporarily
    systemctl stop nginx || true
    
    # Get certificates
    certbot certonly --standalone \
        -d $DOMAIN_NAME \
        -d www.$DOMAIN_NAME \
        -d api.$DOMAIN_NAME \
        --non-interactive \
        --agree-tos \
        --email admin@$DOMAIN_NAME \
        || log_warn "Certbot failed, continuing anyway (might be using staging certs)"
    
    # Setup auto-renewal
    cat > /etc/systemd/system/certbot-renewal.service << EOF
[Unit]
Description=Certbot Renewal
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --post-hook "systemctl reload nginx"
EOF

    cat > /etc/systemd/system/certbot-renewal.timer << EOF
[Unit]
Description=Run certbot renewal twice daily

[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl enable certbot-renewal.timer
    systemctl start certbot-renewal.timer
}

# Setup Nginx
setup_nginx() {
    log_info "Setting up Nginx..."
    
    # Copy configurations
    cp "$PROJECT_ROOT/configs/nginx.conf" /etc/nginx/nginx.conf
    cp "$PROJECT_ROOT/configs/elosofia.site.conf" /etc/nginx/conf.d/
    
    # Update external IP in config
    sed -i "s/YOUR_VPS_IP/$VPS_IP/g" /etc/nginx/conf.d/elosofia.site.conf
    
    # Test configuration
    nginx -t
    
    # Start Nginx
    systemctl start nginx
    systemctl enable nginx
}

# Clone repositories
clone_repos() {
    log_info "Cloning repositories..."
    
    # Setup deploy key
    mkdir -p /root/.ssh
    echo "$GITHUB_TOKEN" > /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
    ssh-keyscan github.com >> /root/.ssh/known_hosts
    
    # Clone repositories
    cd /opt
    git clone git@github.com:elodisney/dental-calendar.git || log_warn "Failed to clone dental-calendar"
    git clone git@github.com:elodisney/sofia-agent.git || log_warn "Failed to clone sofia-agent"
    git clone git@github.com:elodisney/crm.git || log_warn "Failed to clone crm"
}

# Build and deploy services
deploy_services() {
    log_info "Deploying services..."
    
    cd "$PROJECT_ROOT"
    
    # Create .env file
    cat > .env << EOF
# Domain
DOMAIN_NAME=$DOMAIN_NAME
VPS_PUBLIC_IP=$VPS_IP

# Database
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Redis
REDIS_PASSWORD=$REDIS_PASSWORD

# JWT
JWT_SECRET=$JWT_SECRET

# LiveKit
LIVEKIT_API_KEY=$LIVEKIT_API_KEY
LIVEKIT_API_SECRET=$LIVEKIT_API_SECRET
LIVEKIT_WEBHOOK_KEY=$LIVEKIT_WEBHOOK_KEY

# AI Services
OPENAI_API_KEY=$OPENAI_API_KEY
DEEPGRAM_API_KEY=$DEEPGRAM_API_KEY

# TURN
TURN_USERNAME=$TURN_USERNAME
TURN_PASSWORD=$TURN_PASSWORD
EOF

    # Update TURN config with actual secret
    TURN_SECRET=$(echo -n "$TURN_USERNAME:$DOMAIN_NAME:$TURN_PASSWORD" | sha1sum | awk '{print $1}')
    sed -i "s/TURN_SECRET_WILL_BE_SET/$TURN_SECRET/g" "$PROJECT_ROOT/configs/turnserver.conf"
    sed -i "s/YOUR_VPS_IP/$VPS_IP/g" "$PROJECT_ROOT/configs/turnserver.conf"
    
    # Create database init script
    mkdir -p "$PROJECT_ROOT/scripts"
    cat > "$PROJECT_ROOT/scripts/init-db.sql" << 'EOF'
-- Create databases
CREATE DATABASE IF NOT EXISTS dental_calendar;
CREATE DATABASE IF NOT EXISTS crm;

-- Create users and grant permissions
-- These will be handled by the applications
EOF

    # Link application directories
    ln -sf /opt/dental-calendar "$PROJECT_ROOT/dental-calendar"
    ln -sf /opt/sofia-agent "$PROJECT_ROOT/sofia-agent"
    ln -sf /opt/crm "$PROJECT_ROOT/crm"
    
    # Build and start services
    docker compose build
    docker compose up -d
    
    # Wait for services to start
    log_info "Waiting for services to start..."
    sleep 30
    
    # Check service health
    docker compose ps
}

# Setup monitoring
setup_monitoring() {
    log_info "Setting up monitoring..."
    
    # Install monitoring tools
    apt-get install -y prometheus-node-exporter
    
    # Create monitoring script
    cat > /usr/local/bin/sofia-health-check.sh << 'EOF'
#!/bin/bash
# Health check script for Sofia services

check_service() {
    local service=$1
    local port=$2
    if nc -z localhost $port; then
        echo "✅ $service is running on port $port"
        return 0
    else
        echo "❌ $service is NOT running on port $port"
        return 1
    fi
}

echo "Sofia Dental Calendar - Health Check"
echo "===================================="
echo "Timestamp: $(date)"
echo

# Check services
check_service "Nginx" 80
check_service "Dental Calendar" 3005
check_service "CRM" 5000
check_service "Sofia Agent" 8080
check_service "LiveKit" 7880
check_service "PostgreSQL" 5432
check_service "Redis" 6379

# Check Docker containers
echo -e "\nDocker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check disk usage
echo -e "\nDisk Usage:"
df -h | grep -E '^/dev/|Filesystem'

# Check memory
echo -e "\nMemory Usage:"
free -h

# Check LiveKit WebRTC
echo -e "\nWebRTC Ports:"
ss -tulpn | grep -E ':(50000|60000|7881|3478)'
EOF

    chmod +x /usr/local/bin/sofia-health-check.sh
    
    # Setup cron job for monitoring
    cat > /etc/cron.d/sofia-monitoring << EOF
# Run health check every 5 minutes
*/5 * * * * root /usr/local/bin/sofia-health-check.sh > /var/log/sofia-health.log 2>&1
EOF
}

# Setup backup
setup_backup() {
    log_info "Setting up backup..."
    
    # Create backup script
    cat > /usr/local/bin/sofia-backup.sh << 'EOF'
#!/bin/bash
# Backup script for Sofia services

BACKUP_DIR="/backup/sofia"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/$DATE"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup databases
docker exec postgres pg_dumpall -U postgres > "$BACKUP_PATH/postgres_dump.sql"

# Backup Redis
docker exec redis redis-cli --pass $REDIS_PASSWORD BGSAVE
sleep 5
docker cp redis:/data/dump.rdb "$BACKUP_PATH/redis_dump.rdb"

# Backup configurations
cp -r /opt/deployment/configs "$BACKUP_PATH/"

# Backup docker volumes
docker run --rm -v sofia_postgres_data:/data -v "$BACKUP_PATH":/backup alpine tar czf /backup/postgres_volume.tar.gz -C /data .
docker run --rm -v sofia_redis_data:/data -v "$BACKUP_PATH":/backup alpine tar czf /backup/redis_volume.tar.gz -C /data .

# Compress backup
cd "$BACKUP_DIR"
tar czf "sofia_backup_$DATE.tar.gz" "$DATE"
rm -rf "$DATE"

# Keep only last 7 days of backups
find "$BACKUP_DIR" -name "sofia_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: sofia_backup_$DATE.tar.gz"
EOF

    chmod +x /usr/local/bin/sofia-backup.sh
    
    # Setup daily backup cron
    cat > /etc/cron.d/sofia-backup << EOF
# Run backup daily at 3 AM
0 3 * * * root /usr/local/bin/sofia-backup.sh > /var/log/sofia-backup.log 2>&1
EOF
}

# Setup fail2ban
setup_fail2ban() {
    log_info "Setting up fail2ban..."
    
    # Configure fail2ban for SSH and Nginx
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
port = 80,443
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = 80,443
logpath = /var/log/nginx/access.log

[nginx-badbots]
enabled = true
port = 80,443
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = 80,443
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

    systemctl restart fail2ban
    systemctl enable fail2ban
}

# Main deployment flow
main() {
    log_info "Starting Sofia Dental Calendar deployment..."
    
    # Check environment
    check_env
    
    # Run deployment steps
    update_system
    configure_system
    setup_docker
    setup_ssl
    setup_nginx
    clone_repos
    
    # Setup firewall (run the firewall script)
    "$SCRIPT_DIR/setup-firewall.sh"
    
    # Deploy services
    deploy_services
    
    # Setup monitoring and backup
    setup_monitoring
    setup_backup
    setup_fail2ban
    
    log_info "Deployment complete! 🎉"
    log_info "Running health check..."
    /usr/local/bin/sofia-health-check.sh
    
    echo -e "\n${GREEN}✅ Sofia Dental Calendar is deployed!${NC}"
    echo -e "\n📌 Important URLs:"
    echo "   Main site: https://$DOMAIN_NAME"
    echo "   API endpoint: https://api.$DOMAIN_NAME"
    echo -e "\n📊 Monitoring:"
    echo "   Health check: /usr/local/bin/sofia-health-check.sh"
    echo "   Logs: docker compose logs -f [service-name]"
    echo -e "\n🔐 Security:"
    echo "   Firewall status: ufw status"
    echo "   Fail2ban status: fail2ban-client status"
}

# Run main function
main "$@"