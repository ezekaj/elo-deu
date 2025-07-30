#!/bin/bash
# Maintenance Script for Sofia Dental Assistant

cd /opt/sofia-dental

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

# Parse command line arguments
COMMAND=$1

case $COMMAND in
    "restart")
        print_status "Restarting all services..."
        docker-compose -f docker-compose.production.yml restart
        print_success "Services restarted"
        ;;
        
    "stop")
        print_status "Stopping all services..."
        docker-compose -f docker-compose.production.yml down
        print_success "Services stopped"
        ;;
        
    "start")
        print_status "Starting all services..."
        docker-compose -f docker-compose.production.yml up -d
        print_success "Services started"
        ;;
        
    "update")
        print_status "Updating Sofia Dental Assistant..."
        
        # Backup current state
        ./backup.sh
        
        # Pull latest changes
        git pull origin master
        
        # Rebuild and restart services
        docker-compose -f docker-compose.production.yml build
        docker-compose -f docker-compose.production.yml up -d
        
        print_success "Update completed"
        ;;
        
    "logs")
        SERVICE=$2
        if [ -z "$SERVICE" ]; then
            docker-compose -f docker-compose.production.yml logs -f --tail=100
        else
            docker-compose -f docker-compose.production.yml logs -f --tail=100 $SERVICE
        fi
        ;;
        
    "backup")
        print_status "Creating backup..."
        ./backup.sh
        ;;
        
    "clean-logs")
        print_status "Cleaning old logs..."
        find logs/ -name "*.log" -mtime +30 -delete
        print_success "Old logs cleaned"
        ;;
        
    "clean-docker")
        print_status "Cleaning Docker resources..."
        docker system prune -af --volumes
        print_success "Docker resources cleaned"
        ;;
        
    "db-optimize")
        print_status "Optimizing database..."
        docker-compose -f docker-compose.production.yml exec dental-calendar \
            sqlite3 /app/data/dental_calendar.db "VACUUM; ANALYZE;"
        print_success "Database optimized"
        ;;
        
    "ssl-renew")
        print_status "Renewing SSL certificates..."
        sudo certbot renew
        sudo systemctl reload nginx
        print_success "SSL certificates renewed"
        ;;
        
    "status")
        ./health-check.sh
        ;;
        
    "scale")
        SERVICE=$2
        REPLICAS=$3
        if [ -z "$SERVICE" ] || [ -z "$REPLICAS" ]; then
            print_error "Usage: ./maintenance.sh scale <service> <replicas>"
            exit 1
        fi
        print_status "Scaling $SERVICE to $REPLICAS replicas..."
        docker-compose -f docker-compose.production.yml up -d --scale $SERVICE=$REPLICAS
        print_success "Scaling completed"
        ;;
        
    "reset-livekit")
        print_status "Resetting LiveKit service..."
        docker-compose -f docker-compose.production.yml stop livekit
        docker-compose -f docker-compose.production.yml rm -f livekit
        docker-compose -f docker-compose.production.yml up -d livekit
        print_success "LiveKit reset completed"
        ;;
        
    "export-data")
        print_status "Exporting data..."
        EXPORT_DIR="exports/export_$(date +%Y%m%d_%H%M%S)"
        mkdir -p $EXPORT_DIR
        
        # Export database
        docker-compose -f docker-compose.production.yml exec dental-calendar \
            sqlite3 /app/data/dental_calendar.db ".dump" > $EXPORT_DIR/database.sql
        
        # Export appointments as JSON
        docker-compose -f docker-compose.production.yml exec dental-calendar \
            node -e "
            const db = require('better-sqlite3')('/app/data/dental_calendar.db');
            const appointments = db.prepare('SELECT * FROM appointments').all();
            console.log(JSON.stringify(appointments, null, 2));
            " > $EXPORT_DIR/appointments.json
        
        print_success "Data exported to $EXPORT_DIR"
        ;;
        
    "monitor")
        print_status "Starting monitoring mode..."
        watch -n 5 "./health-check.sh"
        ;;
        
    *)
        echo "Sofia Dental Assistant - Maintenance Script"
        echo ""
        echo "Usage: ./maintenance.sh <command> [options]"
        echo ""
        echo "Commands:"
        echo "  start          - Start all services"
        echo "  stop           - Stop all services"
        echo "  restart        - Restart all services"
        echo "  update         - Update to latest version"
        echo "  logs [service] - View logs (optionally for specific service)"
        echo "  backup         - Create backup"
        echo "  status         - Run health check"
        echo "  clean-logs     - Remove logs older than 30 days"
        echo "  clean-docker   - Clean unused Docker resources"
        echo "  db-optimize    - Optimize SQLite database"
        echo "  ssl-renew      - Renew SSL certificates"
        echo "  scale <service> <n> - Scale service to n replicas"
        echo "  reset-livekit  - Reset LiveKit service"
        echo "  export-data    - Export data to JSON/SQL"
        echo "  monitor        - Start monitoring mode"
        echo ""
        echo "Examples:"
        echo "  ./maintenance.sh restart"
        echo "  ./maintenance.sh logs sofia-agent"
        echo "  ./maintenance.sh scale sofia-agent 2"
        ;;
esac