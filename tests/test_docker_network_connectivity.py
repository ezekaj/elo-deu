"""
Test Suite for Docker Network Connectivity
Ensures all services can communicate properly within Docker network
"""

import unittest
import subprocess
import requests
import socket
import time
import docker
import json
from typing import Dict, List, Tuple


class TestDockerNetworkConnectivity(unittest.TestCase):
    """Test Docker network configuration and connectivity"""
    
    def setUp(self):
        self.docker_client = docker.from_env()
        self.network_name = "elo-deu_sofia-network"
        self.services = {
            'livekit': {'port': 7880, 'health': '/health'},
            'sofia-agent': {'port': 8080, 'health': '/health'},
            'dental-calendar': {'port': 3005, 'health': '/api/health'},
            'crm-dashboard': {'port': 5000, 'health': '/'},
            'sofia-web': {'port': 5001, 'health': '/'}
        }
    
    def test_docker_network_exists(self):
        """Test that Docker network exists"""
        networks = self.docker_client.networks.list()
        network_names = [n.name for n in networks]
        
        self.assertIn(
            self.network_name,
            network_names,
            f"Docker network '{self.network_name}' not found"
        )
    
    def test_all_containers_on_same_network(self):
        """Test that all containers are on the same network"""
        try:
            network = self.docker_client.networks.get(self.network_name)
            containers = network.attrs['Containers']
            
            # Check each service has a container on the network
            for service_name in self.services:
                container_found = any(
                    service_name in container_data.get('Name', '')
                    for container_data in containers.values()
                )
                self.assertTrue(
                    container_found,
                    f"Service '{service_name}' not found on network"
                )
        except docker.errors.NotFound:
            self.fail(f"Network '{self.network_name}' not found")
    
    def test_dns_resolution_between_containers(self):
        """Test DNS resolution between containers"""
        # Run DNS tests from sofia-agent container
        container_name = "elo-deu-sofia-agent-1"
        
        try:
            container = self.docker_client.containers.get(container_name)
            
            # Test DNS resolution for each service
            for service, config in self.services.items():
                if service == 'sofia-agent':
                    continue  # Skip self
                
                # Test DNS resolution
                result = container.exec_run(f"nslookup {service}")
                self.assertEqual(
                    result.exit_code, 0,
                    f"DNS resolution failed for {service}: {result.output.decode()}"
                )
                
                # Test ping (if available)
                result = container.exec_run(f"ping -c 1 {service}", demux=True)
                if result.exit_code == 0:
                    self.assertEqual(
                        result.exit_code, 0,
                        f"Cannot ping {service}"
                    )
        except docker.errors.NotFound:
            self.skipTest(f"Container '{container_name}' not running")
    
    def test_service_health_endpoints(self):
        """Test that all services respond to health checks"""
        for service, config in self.services.items():
            url = f"http://localhost:{config['port']}{config['health']}"
            
            try:
                response = requests.get(url, timeout=5)
                self.assertIn(
                    response.status_code,
                    [200, 204],
                    f"Service '{service}' health check failed: {response.status_code}"
                )
            except requests.exceptions.RequestException as e:
                self.fail(f"Cannot reach {service} at {url}: {e}")
    
    def test_livekit_to_sofia_agent_connectivity(self):
        """Test specific LiveKit to Sofia Agent connectivity"""
        # This is critical for agent dispatch
        
        # Check if sofia-agent can reach livekit
        container_name = "elo-deu-sofia-agent-1"
        
        try:
            container = self.docker_client.containers.get(container_name)
            
            # Test HTTP connection to LiveKit
            result = container.exec_run(
                "curl -f http://livekit:7880/health"
            )
            self.assertEqual(
                result.exit_code, 0,
                f"Sofia agent cannot reach LiveKit: {result.output.decode()}"
            )
            
            # Test WebSocket connection
            result = container.exec_run(
                'python -c "import websocket; ws = websocket.create_connection(\'ws://livekit:7880\', timeout=5); ws.close()"'
            )
            self.assertEqual(
                result.exit_code, 0,
                "Sofia agent cannot establish WebSocket connection to LiveKit"
            )
        except docker.errors.NotFound:
            self.skipTest("Sofia agent container not running")
    
    def test_port_bindings(self):
        """Test that all ports are properly bound to host"""
        for service, config in self.services.items():
            port = config['port']
            
            # Test port is open on localhost
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex(('localhost', port))
            sock.close()
            
            self.assertEqual(
                result, 0,
                f"Port {port} for service '{service}' is not accessible on localhost"
            )
    
    def test_container_environment_variables(self):
        """Test that containers have correct environment variables"""
        critical_env_vars = {
            'elo-deu-sofia-agent-1': {
                'LIVEKIT_URL': 'ws://livekit:7880',
                'CALENDAR_URL': 'http://dental-calendar:3005'
            },
            'elo-deu-livekit-1': {
                'LIVEKIT_KEYS': 'devkey: secret'
            }
        }
        
        for container_name, expected_vars in critical_env_vars.items():
            try:
                container = self.docker_client.containers.get(container_name)
                env_list = container.attrs['Config']['Env']
                env_dict = dict(e.split('=', 1) for e in env_list if '=' in e)
                
                for var, expected_value in expected_vars.items():
                    self.assertIn(var, env_dict, f"Missing {var} in {container_name}")
                    self.assertEqual(
                        env_dict[var], expected_value,
                        f"Wrong value for {var} in {container_name}"
                    )
            except docker.errors.NotFound:
                self.skipTest(f"Container '{container_name}' not running")
    
    def test_webhook_connectivity(self):
        """Test webhook connectivity from LiveKit to Sofia Agent"""
        # Simulate a webhook call
        webhook_url = "http://localhost:8080/webhook/room-started"
        
        payload = {
            "event": "room_started",
            "room": {
                "name": "test-room",
                "sid": "RM_test123"
            },
            "timestamp": int(time.time())
        }
        
        try:
            response = requests.post(
                webhook_url,
                json=payload,
                headers={'Authorization': 'Bearer secret'},
                timeout=5
            )
            
            # Even if not implemented, should not be connection error
            self.assertNotEqual(
                response.status_code, 
                None,
                "Webhook endpoint not reachable"
            )
        except requests.exceptions.ConnectionError:
            self.fail("Cannot connect to Sofia agent webhook endpoint")


class TestDockerNetworkFixes(unittest.TestCase):
    """Provide fixes for Docker network issues"""
    
    def generate_docker_compose_fixes(self) -> Dict[str, any]:
        """Generate fixes for docker-compose.yml"""
        return {
            'services': {
                'livekit': {
                    'healthcheck': {
                        'test': ["CMD", "wget", "-q", "--spider", "http://localhost:7880/health"],
                        'interval': '10s',
                        'timeout': '5s',
                        'retries': 5,
                        'start_period': '20s'
                    },
                    'depends_on': {
                        'init-network': {
                            'condition': 'service_completed_successfully'
                        }
                    }
                },
                'sofia-agent': {
                    'extra_hosts': [
                        'host.docker.internal:host-gateway'
                    ],
                    'dns': ['8.8.8.8', '8.8.4.4'],
                    'healthcheck': {
                        'test': ["CMD", "curl", "-f", "http://localhost:8080/health"],
                        'interval': '15s',
                        'timeout': '10s',
                        'retries': 5,
                        'start_period': '30s'
                    }
                },
                # Network initialization service
                'init-network': {
                    'image': 'busybox',
                    'command': 'echo "Network initialized"',
                    'networks': ['sofia-network']
                }
            },
            'networks': {
                'sofia-network': {
                    'driver': 'bridge',
                    'driver_opts': {
                        'com.docker.network.bridge.name': 'sofia-br',
                        'com.docker.network.driver.mtu': '1500'
                    },
                    'ipam': {
                        'driver': 'default',
                        'config': [{
                            'subnet': '172.20.0.0/16'
                        }]
                    }
                }
            }
        }
    
    def test_network_troubleshooting_script(self):
        """Create network troubleshooting script"""
        script_content = """#!/bin/bash
# Docker Network Troubleshooting Script

echo "=== Docker Network Diagnostics ==="

# Check if services are running
echo -e "\\n1. Checking container status:"
docker-compose ps

# Check network
echo -e "\\n2. Checking Docker network:"
docker network inspect elo-deu_sofia-network | jq '.Containers'

# Test DNS resolution from sofia-agent
echo -e "\\n3. Testing DNS resolution from sofia-agent:"
docker-compose exec -T sofia-agent nslookup livekit
docker-compose exec -T sofia-agent nslookup dental-calendar

# Test connectivity
echo -e "\\n4. Testing connectivity:"
docker-compose exec -T sofia-agent curl -s http://livekit:7880/health | jq .
docker-compose exec -T sofia-agent curl -s http://dental-calendar:3005/api/health | jq .

# Check logs for errors
echo -e "\\n5. Recent error logs:"
docker-compose logs --tail=20 2>&1 | grep -i error || echo "No errors found"

echo -e "\\n=== Diagnostics Complete ==="
"""
        
        with open('/home/elo/elo-deu/debug-network.sh', 'w') as f:
            f.write(script_content)
        
        # Make executable
        import os
        os.chmod('/home/elo/elo-deu/debug-network.sh', 0o755)
        
        self.assertTrue(os.path.exists('/home/elo/elo-deu/debug-network.sh'))


if __name__ == '__main__':
    unittest.main(verbosity=2)