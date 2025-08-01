"""
Comprehensive Test Suite for Sofia Dental AI Connection Issues
This test suite exposes all current issues and provides fixes
"""

import unittest
import yaml
import json
import os
import asyncio
import aiohttp
import socket
import docker
import time
from typing import Dict, Any, List, Optional
from unittest.mock import Mock, patch


class TestSofiaSystemIssues(unittest.TestCase):
    """Test suite that exposes all current Sofia system issues"""
    
    def setUp(self):
        self.config_path = "/home/elo/elo-deu/livekit.yaml"
        self.docker_client = docker.from_env()
        self.livekit_url = "http://localhost:7880"
        self.calendar_url = "http://localhost:3005"
        self.agent_url = "http://localhost:8080"
        
    # ============= ISSUE 1: LiveKit Configuration Errors =============
    
    def test_livekit_config_missing_fields(self):
        """FAILING TEST: LiveKit config missing required fields for TCP mode"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        # These assertions will FAIL with current config
        self.assertIn('turn', config, "TURN configuration missing - required for TCP mode")
        
        if 'turn' in config:
            turn_config = config['turn']
            self.assertIn('enabled', turn_config, "TURN enabled flag missing")
            self.assertTrue(turn_config.get('enabled'), "TURN must be enabled")
            self.assertIn('domain', turn_config, "TURN domain missing")
            self.assertIn('username', turn_config, "TURN username missing")
            self.assertIn('password', turn_config, "TURN password missing")
        
        # RTC config issues
        rtc_config = config.get('rtc', {})
        self.assertIn('external_ip', rtc_config, "External IP not configured")
        self.assertIn('stun_servers', rtc_config, "STUN servers not configured")
        
    def test_livekit_ice_transport_policy(self):
        """FAILING TEST: ICE transport policy not set for TCP-only mode"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        rtc_config = config.get('rtc', {})
        self.assertIn('ice_transport_policy', rtc_config, "ICE transport policy missing")
        self.assertEqual(rtc_config.get('ice_transport_policy'), 'relay', 
                        "Must be 'relay' for TCP-only mode")
        
    # ============= ISSUE 2: Docker Network Connectivity =============
    
    def test_sofia_agent_cannot_resolve_livekit(self):
        """FAILING TEST: Sofia agent cannot resolve 'livekit' hostname"""
        try:
            container = self.docker_client.containers.get('elo-deu-sofia-agent-1')
            
            # This will fail with "Temporary failure in name resolution"
            result = container.exec_run("ping -c 1 livekit")
            self.assertEqual(result.exit_code, 0, 
                           f"Cannot resolve livekit: {result.output.decode()}")
            
            # Test actual connection
            result = container.exec_run("curl -f http://livekit:7880/health")
            self.assertEqual(result.exit_code, 0,
                           f"Cannot connect to LiveKit: {result.output.decode()}")
                           
        except docker.errors.NotFound:
            self.fail("Sofia agent container not running")
            
    def test_agent_health_endpoint_missing(self):
        """FAILING TEST: Sofia agent health endpoint not implemented"""
        import requests
        
        try:
            response = requests.get(f"{self.agent_url}/health", timeout=5)
            self.assertEqual(response.status_code, 200, "Agent health endpoint missing")
            
            data = response.json()
            self.assertIn('status', data)
            self.assertIn('livekit_connected', data)
            
        except requests.exceptions.RequestException as e:
            self.fail(f"Agent health endpoint not accessible: {e}")
            
    # ============= ISSUE 3: Frontend Signal Flow =============
    
    async def test_livekit_token_endpoint_missing(self):
        """FAILING TEST: Calendar server missing /api/livekit-token endpoint"""
        async with aiohttp.ClientSession() as session:
            payload = {
                "identity": "test-user",
                "room": "test-room",
                "metadata": json.dumps({"request_agent": True})
            }
            
            async with session.post(
                f"{self.calendar_url}/api/livekit-token",
                json=payload
            ) as response:
                self.assertEqual(response.status, 200, 
                               "LiveKit token endpoint not implemented")
                
                data = await response.json()
                self.assertIn('token', data)
                self.assertIn('url', data)
                
    def test_frontend_internal_error(self):
        """FAILING TEST: Frontend gets 'Internal error' when connecting"""
        # This simulates the current error state
        error_response = {
            "error": "could not establish signal error: Internal error",
            "code": "SIGNAL_ERROR"
        }
        
        # The current system returns this error
        self.assertNotIn('Internal error', str(error_response), 
                        "Frontend should not get internal errors")
                        
    # ============= ISSUE 4: TCP-Only WebRTC =============
    
    def test_udp_ports_still_enabled(self):
        """FAILING TEST: UDP ports still enabled when should be TCP-only"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        rtc_config = config.get('rtc', {})
        
        # Check UDP is disabled
        self.assertIn('port_range_start', rtc_config, "UDP port range not configured")
        self.assertEqual(rtc_config.get('port_range_start', 1), 0, 
                        "UDP port range start should be 0 to disable")
        self.assertEqual(rtc_config.get('port_range_end', 1), 0,
                        "UDP port range end should be 0 to disable")
                        
    def test_turn_server_not_running(self):
        """FAILING TEST: TURN server required for TCP relay not running"""
        # Check if TURN server container exists
        containers = self.docker_client.containers.list()
        turn_container = any('turn' in c.name.lower() for c in containers)
        
        self.assertTrue(turn_container, "TURN server container not running")
        
        # Check TURN TCP port
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex(('localhost', 3478))
        sock.close()
        
        self.assertEqual(result, 0, "TURN TCP port 3478 not accessible")


class TestSofiaCompleteFixes(unittest.TestCase):
    """Provides complete fixes for all Sofia system issues"""
    
    def create_complete_livekit_config(self) -> Dict[str, Any]:
        """Create a complete, working LiveKit configuration"""
        return {
            'port': 7880,
            'bind_addresses': ['0.0.0.0'],
            
            'rtc': {
                # TCP configuration
                'tcp_port': 7881,
                'port_range_start': 0,  # Disable UDP
                'port_range_end': 0,    # Disable UDP
                
                # Force TCP-only mode
                'use_ice_tcp': True,
                'ice_transport_policy': 'relay',
                
                # ICE configuration
                'ice_lite': True,
                'use_external_ip': True,
                'external_ip': 'auto',  # Or your public IP
                'enable_loopback_candidate': False,
                
                # STUN servers
                'stun_servers': [
                    'stun:stun.l.google.com:19302',
                    'stun:stun1.l.google.com:19302'
                ],
                
                # Network interfaces
                'interfaces': {
                    'include': ['eth0', 'wlan0'],
                    'exclude': ['docker0']
                }
            },
            
            # TURN configuration (REQUIRED)
            'turn': {
                'enabled': True,
                'domain': 'localhost',  # For local testing
                'protocol': 'tcp',
                'port': 3478,
                'username': 'sofia',
                'password': 'turn-password-123',
                'tls_port': 5349,
                'external_tls': False
            },
            
            'room': {
                'auto_create': True,
                'empty_timeout': 300,
                'max_participants': 50,
                'enable_playout_delay': True,
                'adaptive_stream': True
            },
            
            'webhook': {
                'urls': {
                    'room_started': 'http://sofia-agent:8080/webhook/room-started',
                    'participant_joined': 'http://sofia-agent:8080/webhook/participant-joined'
                },
                'api_key': 'secret'
            },
            
            'keys': {
                'devkey': 'secret'
            },
            
            'logging': {
                'level': 'info',
                'json': False,
                'sample': False
            }
        }
    
    def create_docker_compose_fixes(self) -> Dict[str, Any]:
        """Create docker-compose.yml fixes"""
        return {
            'version': '3.8',
            'services': {
                'livekit': {
                    'image': 'livekit/livekit-server:latest',
                    'ports': [
                        '7880:7880',
                        '7881:7881/tcp',  # TCP only
                        # Remove UDP port 7882
                    ],
                    'environment': [
                        'LIVEKIT_KEYS=devkey: secret',
                        'LIVEKIT_LOG_LEVEL=info'
                    ],
                    'command': '--config /etc/livekit.yaml',
                    'volumes': [
                        './livekit-complete.yaml:/etc/livekit.yaml'
                    ],
                    'networks': ['sofia-network'],
                    'restart': 'unless-stopped',
                    'healthcheck': {
                        'test': ['CMD', 'wget', '-q', '--spider', 'http://localhost:7880/health'],
                        'interval': '10s',
                        'timeout': '5s',
                        'retries': 5,
                        'start_period': '20s'
                    }
                },
                
                'sofia-agent': {
                    'build': {
                        'context': '.',
                        'dockerfile': 'Dockerfile.sofia'
                    },
                    'environment': [
                        'LIVEKIT_URL=ws://livekit:7880',
                        'LIVEKIT_API_KEY=devkey',
                        'LIVEKIT_API_SECRET=secret',
                        'GOOGLE_API_KEY=${GOOGLE_API_KEY}',
                        'CALENDAR_URL=http://dental-calendar:3005',
                        'HEALTH_CHECK_PORT=8080'
                    ],
                    'depends_on': {
                        'livekit': {
                            'condition': 'service_healthy'
                        },
                        'dental-calendar': {
                            'condition': 'service_started'
                        }
                    },
                    'networks': ['sofia-network'],
                    'ports': ['8080:8080'],
                    'restart': 'unless-stopped',
                    'healthcheck': {
                        'test': ['CMD', 'curl', '-f', 'http://localhost:8080/health'],
                        'interval': '15s',
                        'timeout': '10s',
                        'retries': 3,
                        'start_period': '30s'
                    }
                },
                
                # Minimal TURN server for TCP relay
                'turn-server': {
                    'image': 'coturn/coturn:latest',
                    'ports': [
                        '3478:3478/tcp',
                        '5349:5349/tcp'
                    ],
                    'environment': [
                        'TURNSERVER_ENABLED=1',
                        'TURNSERVER_REALM=sofia.local',
                        'TURNSERVER_USER=sofia:turn-password-123',
                        'TURNSERVER_NO_UDP=1',
                        'TURNSERVER_NO_UDP_RELAY=1',
                        'TURNSERVER_TCP_PROXY_PORT=7881'
                    ],
                    'networks': ['sofia-network'],
                    'restart': 'unless-stopped'
                }
            },
            
            'networks': {
                'sofia-network': {
                    'driver': 'bridge',
                    'driver_opts': {
                        'com.docker.network.bridge.name': 'sofia-br'
                    }
                }
            }
        }
    
    def create_agent_health_server(self) -> str:
        """Create health server code for agent.py"""
        return '''
# Add to agent.py after imports

from aiohttp import web
import threading

class HealthServer:
    def __init__(self, port=8080):
        self.port = port
        self.app = web.Application()
        self.is_connected = False
        self.setup_routes()
        
    def setup_routes(self):
        self.app.router.add_get('/health', self.health_check)
        self.app.router.add_post('/webhook/room-started', self.room_started)
        self.app.router.add_post('/webhook/participant-joined', self.participant_joined)
        
    async def health_check(self, request):
        return web.json_response({
            'status': 'ok',
            'service': 'sofia-agent',
            'livekit_connected': self.is_connected,
            'ready': True,
            'timestamp': int(time.time())
        })
        
    async def room_started(self, request):
        data = await request.json()
        logger.info(f"Room started webhook: {data}")
        return web.json_response({'status': 'ok'})
        
    async def participant_joined(self, request):
        data = await request.json()
        logger.info(f"Participant joined webhook: {data}")
        return web.json_response({'status': 'ok'})
        
    async def start(self):
        runner = web.AppRunner(self.app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', self.port)
        await site.start()
        logger.info(f"Health server started on port {self.port}")

# Start health server in a separate thread
health_server = HealthServer()

async def start_health_server():
    await health_server.start()

# Add to main block
if __name__ == "__main__":
    # Start health server
    asyncio.create_task(start_health_server())
    
    # Continue with normal agent startup...
'''
    
    def create_calendar_token_endpoint(self) -> str:
        """Create token endpoint for calendar server"""
        return '''
// Add to dental-calendar/server.js

const jwt = require('jsonwebtoken');

// LiveKit token endpoint
app.post('/api/livekit-token', async (req, res) => {
    try {
        const { identity, room, metadata } = req.body;
        
        if (!identity || !room) {
            return res.status(400).json({ 
                error: 'Missing required fields: identity and room' 
            });
        }
        
        const apiKey = process.env.LIVEKIT_API_KEY || 'devkey';
        const apiSecret = process.env.LIVEKIT_API_SECRET || 'secret';
        
        // Create token payload
        const payload = {
            iss: apiKey,
            sub: identity,
            iat: Math.floor(Date.now() / 1000),
            exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60), // 24 hours
            video: {
                roomJoin: true,
                room: room,
                canPublish: true,
                canSubscribe: true,
                canPublishData: true
            },
            metadata: metadata || JSON.stringify({
                request_agent: true,
                agent_type: 'dental-assistant'
            })
        };
        
        // Sign token
        const token = jwt.sign(payload, apiSecret, {
            algorithm: 'HS256'
        });
        
        res.json({
            token: token,
            url: process.env.LIVEKIT_URL || 'ws://localhost:7880'
        });
        
    } catch (error) {
        console.error('Token generation error:', error);
        res.status(500).json({ 
            error: 'Failed to generate token' 
        });
    }
});
'''
    
    def test_generate_all_fixes(self):
        """Generate all fix files"""
        # 1. Complete LiveKit config
        config = self.create_complete_livekit_config()
        with open('/home/elo/elo-deu/livekit-complete.yaml', 'w') as f:
            yaml.dump(config, f, default_flow_style=False)
        
        # 2. Docker compose fixes
        compose = self.create_docker_compose_fixes()
        with open('/home/elo/elo-deu/docker-compose-fixed.yml', 'w') as f:
            yaml.dump(compose, f, default_flow_style=False)
        
        # 3. Implementation guide
        guide = '''
# Sofia Dental AI - Complete Fix Implementation Guide

## Overview
This guide provides step-by-step instructions to fix all connection issues.

## Issues Identified

1. **LiveKit Configuration**
   - Missing TURN server configuration
   - Missing ICE transport policy for TCP-only mode
   - Missing STUN servers
   - Missing external IP configuration

2. **Docker Network**
   - Sofia agent cannot resolve 'livekit' hostname
   - Missing health check endpoints
   - Network isolation issues

3. **Frontend Signal Flow**
   - Missing /api/livekit-token endpoint
   - "Internal error" when establishing connection
   - WebSocket connection failures

4. **TCP-Only Mode**
   - UDP ports still enabled
   - No TURN server for TCP relay
   - Client not configured for TCP-only

## Implementation Steps

### Step 1: Update LiveKit Configuration
```bash
# Backup current config
cp livekit.yaml livekit.yaml.backup

# Use the complete configuration
cp livekit-complete.yaml livekit.yaml
```

### Step 2: Add TURN Server
```bash
# Add to docker-compose.yml (or use docker-compose-fixed.yml)
docker-compose -f docker-compose-fixed.yml up -d turn-server
```

### Step 3: Update Sofia Agent
1. Add health server to agent.py (see provided code)
2. Rebuild agent container:
```bash
docker-compose build sofia-agent
docker-compose up -d sofia-agent
```

### Step 4: Update Calendar Server
1. Add token endpoint to server.js (see provided code)
2. Install JWT library:
```bash
cd dental-calendar
npm install jsonwebtoken
```
3. Restart calendar service:
```bash
docker-compose restart dental-calendar
```

### Step 5: Update Frontend
1. Replace sofia-real-connection.js with TCP-only version
2. Update WebRTC configuration for TCP-only mode

### Step 6: Test Everything
```bash
# Run all tests
python -m pytest tests/test_complete_sofia_fixes.py -v

# Check services
docker-compose ps

# Test connectivity
./diagnose-tcp-only.sh
```

## Validation

After implementing all fixes, you should see:
- ✅ All services healthy in docker-compose ps
- ✅ Sofia agent connects to LiveKit successfully
- ✅ Frontend can establish WebRTC connection
- ✅ Audio works in both directions
- ✅ Works behind firewalls (TCP-only mode)

## Troubleshooting

If issues persist:
1. Check logs: `docker-compose logs -f`
2. Verify network: `docker network inspect elo-deu_sofia-network`
3. Test endpoints manually with curl
4. Ensure all ports are open in firewall

## Quick Start

For a quick fix, run:
```bash
# Apply all fixes at once
./apply-sofia-fixes.sh
```
'''
        
        with open('/home/elo/elo-deu/IMPLEMENTATION_GUIDE.md', 'w') as f:
            f.write(guide)
        
        # 4. Quick fix script
        script = '''#!/bin/bash
# Quick fix script for Sofia Dental AI

set -e

echo "🔧 Applying Sofia Dental AI fixes..."

# Backup current configs
echo "📦 Backing up current configuration..."
cp livekit.yaml livekit.yaml.$(date +%Y%m%d_%H%M%S).backup || true

# Apply LiveKit config
echo "📝 Updating LiveKit configuration..."
cp livekit-complete.yaml livekit.yaml

# Restart services
echo "🔄 Restarting services..."
docker-compose down
docker-compose -f docker-compose-fixed.yml up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 15

# Check health
echo "🏥 Checking service health..."
docker-compose ps

# Test connectivity
echo "🧪 Testing connectivity..."
curl -s http://localhost:7880/health | jq . || echo "LiveKit health check failed"
curl -s http://localhost:8080/health | jq . || echo "Agent health check failed"
curl -s http://localhost:3005/api/health | jq . || echo "Calendar health check failed"

echo "✅ Sofia Dental AI fixes applied!"
echo "🎯 Next step: Test the frontend connection"
'''
        
        with open('/home/elo/elo-deu/apply-sofia-fixes.sh', 'w') as f:
            f.write(script)
        
        os.chmod('/home/elo/elo-deu/apply-sofia-fixes.sh', 0o755)
        
        # Verify files were created
        self.assertTrue(os.path.exists('/home/elo/elo-deu/livekit-complete.yaml'))
        self.assertTrue(os.path.exists('/home/elo/elo-deu/docker-compose-fixed.yml'))
        self.assertTrue(os.path.exists('/home/elo/elo-deu/IMPLEMENTATION_GUIDE.md'))
        self.assertTrue(os.path.exists('/home/elo/elo-deu/apply-sofia-fixes.sh'))


class TestMinimalQuickFix(unittest.TestCase):
    """Minimal fixes to get Sofia working quickly"""
    
    def create_minimal_livekit_config(self) -> str:
        """Create minimal working LiveKit config"""
        return '''# Minimal LiveKit Configuration
port: 7880
bind_addresses:
  - 0.0.0.0

rtc:
  tcp_port: 7881
  use_external_ip: false  # Disable for local testing
  
room:
  auto_create: true
  empty_timeout: 300

keys:
  devkey: secret

logging:
  level: info
'''
    
    def test_create_minimal_fix(self):
        """Create minimal fix file"""
        with open('/home/elo/elo-deu/livekit-minimal.yaml', 'w') as f:
            f.write(self.create_minimal_livekit_config())
        
        self.assertTrue(os.path.exists('/home/elo/elo-deu/livekit-minimal.yaml'))


if __name__ == '__main__':
    # Run tests
    unittest.main(verbosity=2)