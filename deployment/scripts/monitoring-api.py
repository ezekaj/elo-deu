#!/usr/bin/env python3
"""
Sofia System Monitoring API
Provides real-time system metrics for the monitoring dashboard
"""

import json
import psutil
import docker
import redis
import subprocess
from datetime import datetime
from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Initialize connections
docker_client = docker.from_env()
redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)

def get_service_status():
    """Check status of all services"""
    services = {}
    
    # Check Docker containers
    try:
        containers = docker_client.containers.list()
        for container in containers:
            services[container.name] = {
                'status': container.status,
                'uptime': container.attrs['State']['StartedAt']
            }
    except Exception as e:
        print(f"Error checking containers: {e}")
    
    # Check system services
    for service in ['nginx', 'ufw', 'fail2ban']:
        try:
            result = subprocess.run(
                ['systemctl', 'is-active', service],
                capture_output=True,
                text=True
            )
            services[service] = {
                'status': 'active' if result.returncode == 0 else 'inactive'
            }
        except:
            services[service] = {'status': 'unknown'}
    
    return services

def get_system_metrics():
    """Get system resource usage"""
    return {
        'cpu': psutil.cpu_percent(interval=1),
        'memory': psutil.virtual_memory().percent,
        'disk': psutil.disk_usage('/').percent,
        'network': {
            'bytes_sent': psutil.net_io_counters().bytes_sent,
            'bytes_recv': psutil.net_io_counters().bytes_recv
        }
    }

def get_webrtc_stats():
    """Get LiveKit/WebRTC statistics"""
    try:
        # This would connect to LiveKit API
        # For now, return mock data
        return {
            'rooms': 5,
            'clients': 12,
            'ports': 45,
            'bandwidth': 25.6
        }
    except:
        return {
            'rooms': 0,
            'clients': 0,
            'ports': 0,
            'bandwidth': 0
        }

def get_security_status():
    """Get security-related information"""
    security = {}
    
    # Check SSL certificate expiry
    try:
        result = subprocess.run(
            ['openssl', 'x509', '-enddate', '-noout', '-in',
             '/etc/letsencrypt/live/elosofia.site/cert.pem'],
            capture_output=True,
            text=True
        )
        security['ssl_expiry'] = result.stdout.strip()
    except:
        security['ssl_expiry'] = 'Unknown'
    
    # Check fail2ban bans
    try:
        result = subprocess.run(
            ['fail2ban-client', 'status'],
            capture_output=True,
            text=True
        )
        # Parse banned IPs count
        security['banned_ips'] = 0  # Would parse actual output
    except:
        security['banned_ips'] = 0
    
    # Check last backup
    try:
        result = subprocess.run(
            ['find', '/backup/sofia', '-name', '*.tar.gz', '-mtime', '-1'],
            capture_output=True,
            text=True
        )
        security['last_backup'] = 'Within 24h' if result.stdout else 'Older than 24h'
    except:
        security['last_backup'] = 'Unknown'
    
    return security

def get_recent_logs():
    """Get recent application logs"""
    logs = []
    
    # Read recent Docker logs
    try:
        containers = docker_client.containers.list()
        for container in containers[:3]:  # Limit to avoid too many logs
            recent_logs = container.logs(tail=5, timestamps=True).decode('utf-8')
            for line in recent_logs.split('\n'):
                if line:
                    logs.append({
                        'timestamp': datetime.now().isoformat(),
                        'service': container.name,
                        'level': 'info',
                        'message': line[:200]  # Truncate long messages
                    })
    except Exception as e:
        logs.append({
            'timestamp': datetime.now().isoformat(),
            'service': 'monitor',
            'level': 'error',
            'message': f'Error reading logs: {str(e)}'
        })
    
    return logs[-20:]  # Return last 20 logs

@app.route('/api/monitor/stats')
def get_stats():
    """Main monitoring endpoint"""
    return jsonify({
        'timestamp': datetime.now().isoformat(),
        'services': get_service_status(),
        'system': get_system_metrics(),
        'webrtc': get_webrtc_stats(),
        'security': get_security_status(),
        'logs': get_recent_logs()
    })

@app.route('/api/monitor/health')
def health_check():
    """Simple health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=9090, debug=False)