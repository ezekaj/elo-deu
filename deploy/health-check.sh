#!/bin/bash
# Health Check Script for Sofia Dental Assistant

cd /opt/sofia-dental

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Sofia Dental Assistant - Health Check Report"
echo "============================================"
echo "Timestamp: $(date)"
echo ""

# Function to check service health
check_service() {
    local service_name=$1
    local health_url=$2
    
    if curl -sf $health_url > /dev/null; then
        echo -e "${GREEN}[✓]${NC} $service_name is healthy"
        return 0
    else
        echo -e "${RED}[✗]${NC} $service_name is unhealthy"
        return 1
    fi
}

# Check Docker services
echo "Docker Services Status:"
echo "----------------------"
docker-compose -f docker-compose.production.yml ps

echo ""
echo "Service Health Checks:"
echo "---------------------"

# Check individual services
check_service "Calendar Service" "http://localhost:3005/api/health"
check_service "LiveKit Service" "http://localhost:7880/health"
check_service "CRM Dashboard" "http://localhost:5000/health"

echo ""
echo "System Resources:"
echo "----------------"

# Check CPU usage
echo -n "CPU Usage: "
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'

# Check memory usage
echo -n "Memory Usage: "
free | awk 'NR==2{printf "%.1f%%\n", $3*100/$2}'

# Check disk usage
echo -n "Disk Usage: "
df -h / | awk 'NR==2 {print $5}'

echo ""
echo "Container Resources:"
echo "-------------------"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "Recent Errors (last 50 lines):"
echo "-----------------------------"
docker-compose -f docker-compose.production.yml logs --tail=50 2>&1 | grep -E "(ERROR|WARN|CRITICAL)" || echo "No recent errors found"

echo ""
echo "Active Connections:"
echo "------------------"
echo "HTTP/HTTPS connections: $(netstat -ant | grep -E ':80|:443' | grep ESTABLISHED | wc -l)"
echo "WebSocket connections: $(netstat -ant | grep ':7881' | grep ESTABLISHED | wc -l)"
echo "WebRTC connections: $(netstat -anu | grep -E ':5[0-9]{4}' | wc -l)"

echo ""
echo "Database Status:"
echo "---------------"
if [ -f "data/calendar/dental_calendar.db" ]; then
    db_size=$(du -h data/calendar/dental_calendar.db | cut -f1)
    echo "Database size: $db_size"
    echo "Last modified: $(stat -c %y data/calendar/dental_calendar.db | cut -d' ' -f1,2)"
else
    echo -e "${YELLOW}[!]${NC} Database file not found"
fi

echo ""
echo "SSL Certificate Status:"
echo "----------------------"
if command -v certbot &> /dev/null; then
    sudo certbot certificates 2>/dev/null | grep -E "(Certificate Name|Expiry Date)" || echo "No certificates found"
else
    echo "Certbot not installed"
fi

echo ""
echo "============================================"
echo "Health check completed at $(date)"