"""
Test Suite for LiveKit Configuration Validation
Tests ensure LiveKit server is properly configured for global TCP-only access
"""

import unittest
import yaml
import os
import asyncio
import aiohttp
from typing import Dict, Any
import socket
import json


class TestLiveKitConfiguration(unittest.TestCase):
    """Test cases for LiveKit server configuration"""
    
    def setUp(self):
        self.config_path = "/home/elo/elo-deu/livekit.yaml"
        self.livekit_url = "http://localhost:7880"
        self.livekit_ws_url = "ws://localhost:7880"
        
    def test_config_file_exists(self):
        """Test that LiveKit configuration file exists"""
        self.assertTrue(
            os.path.exists(self.config_path),
            f"LiveKit config file not found at {self.config_path}"
        )
    
    def test_tcp_only_configuration(self):
        """Test that LiveKit is configured for TCP-only mode"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        # Check RTC configuration
        self.assertIn('rtc', config, "RTC configuration missing")
        rtc_config = config['rtc']
        
        # TCP port must be configured
        self.assertIn('tcp_port', rtc_config, "TCP port not configured")
        self.assertEqual(rtc_config['tcp_port'], 7881, "TCP port should be 7881")
        
        # ICE configuration for TCP-only
        self.assertTrue(rtc_config.get('ice_lite', False), "ICE lite mode should be enabled")
        self.assertTrue(rtc_config.get('use_external_ip', False), "External IP usage should be enabled")
        
        # Check for TURN server configuration (REQUIRED for TCP-only)
        self.assertIn('turn', config, "TURN server configuration missing for TCP-only mode")
        turn_config = config['turn']
        self.assertIn('enabled', turn_config, "TURN enabled flag missing")
        self.assertTrue(turn_config['enabled'], "TURN must be enabled for TCP-only mode")
        
    def test_external_ip_configuration(self):
        """Test that external IP is properly configured for global access"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        rtc_config = config.get('rtc', {})
        
        # Should have external IP configuration
        self.assertIn('external_ip', rtc_config, "External IP not configured")
        external_ip = rtc_config['external_ip']
        
        # Validate it's a real IP or domain
        self.assertTrue(
            self._is_valid_ip(external_ip) or self._is_valid_domain(external_ip),
            f"External IP '{external_ip}' is not valid"
        )
    
    def test_stun_server_configuration(self):
        """Test STUN server configuration for NAT traversal"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        rtc_config = config.get('rtc', {})
        self.assertIn('stun_servers', rtc_config, "STUN servers not configured")
        
        stun_servers = rtc_config['stun_servers']
        self.assertIsInstance(stun_servers, list, "STUN servers should be a list")
        self.assertGreater(len(stun_servers), 0, "At least one STUN server required")
        
        # Validate STUN server format
        for server in stun_servers:
            self.assertTrue(
                server.startswith('stun:'),
                f"STUN server '{server}' should start with 'stun:'"
            )
    
    def test_turn_server_configuration(self):
        """Test TURN server configuration for TCP relay"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        self.assertIn('turn', config, "TURN configuration missing")
        turn_config = config['turn']
        
        # Required TURN settings
        required_fields = ['enabled', 'domain', 'protocol', 'port', 'username', 'password']
        for field in required_fields:
            self.assertIn(field, turn_config, f"TURN {field} not configured")
        
        # Protocol must be TCP for TCP-only mode
        self.assertEqual(turn_config['protocol'], 'tcp', "TURN protocol must be TCP")
        
    def test_webhook_configuration(self):
        """Test webhook configuration for agent dispatch"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        self.assertIn('webhook', config, "Webhook configuration missing")
        webhook = config['webhook']
        
        self.assertIn('urls', webhook, "Webhook URLs not configured")
        urls = webhook['urls']
        
        # Should have room started webhook for agent dispatch
        self.assertIn('room_started', urls, "Room started webhook missing")
        self.assertTrue(
            urls['room_started'].startswith('http'),
            "Room started webhook should be a valid URL"
        )
    
    def test_room_configuration(self):
        """Test room configuration settings"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        self.assertIn('room', config, "Room configuration missing")
        room_config = config['room']
        
        # Auto-create must be enabled
        self.assertTrue(room_config.get('auto_create', False), "Room auto-create should be enabled")
        
        # Check timeouts
        self.assertIn('empty_timeout', room_config, "Empty timeout not configured")
        self.assertGreaterEqual(room_config['empty_timeout'], 300, "Empty timeout too short")
    
    def test_logging_configuration(self):
        """Test logging configuration for debugging"""
        with open(self.config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        self.assertIn('logging', config, "Logging configuration missing")
        logging = config['logging']
        
        # For debugging, should be at least info level
        self.assertIn('level', logging, "Log level not configured")
        self.assertIn(
            logging['level'], 
            ['debug', 'info'], 
            "Log level should be debug or info for troubleshooting"
        )
    
    async def test_livekit_health_endpoint(self):
        """Test LiveKit health check endpoint"""
        async with aiohttp.ClientSession() as session:
            try:
                async with session.get(f"{self.livekit_url}/health") as response:
                    self.assertEqual(response.status, 200, "LiveKit health check failed")
                    data = await response.json()
                    self.assertIn('status', data, "Health response missing status")
                    self.assertEqual(data['status'], 'ok', "LiveKit not healthy")
            except aiohttp.ClientError as e:
                self.fail(f"Could not connect to LiveKit: {e}")
    
    async def test_livekit_tcp_port_open(self):
        """Test that LiveKit TCP port is accessible"""
        tcp_port = 7881
        
        # Test TCP port is open
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        
        result = sock.connect_ex(('localhost', tcp_port))
        sock.close()
        
        self.assertEqual(result, 0, f"LiveKit TCP port {tcp_port} is not accessible")
    
    def _is_valid_ip(self, ip: str) -> bool:
        """Check if string is a valid IP address"""
        try:
            socket.inet_aton(ip)
            return True
        except socket.error:
            return False
    
    def _is_valid_domain(self, domain: str) -> bool:
        """Check if string is a valid domain"""
        import re
        pattern = re.compile(
            r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$'
        )
        return bool(pattern.match(domain))


class TestLiveKitConfigurationFixes(unittest.TestCase):
    """Test cases that provide fixes for configuration issues"""
    
    def generate_fixed_config(self) -> Dict[str, Any]:
        """Generate a fixed LiveKit configuration for TCP-only global access"""
        return {
            'port': 7880,
            'bind_addresses': ['0.0.0.0'],
            
            'rtc': {
                'tcp_port': 7881,
                'ice_lite': True,
                'use_external_ip': True,
                'external_ip': 'auto',  # Or specify actual external IP
                'enable_loopback_candidate': False,
                
                # Force TCP-only mode
                'udp_port_range': None,  # Disable UDP ports
                'use_ice_tcp': True,
                
                # STUN servers for NAT discovery
                'stun_servers': [
                    'stun:stun.l.google.com:19302',
                    'stun:stun1.l.google.com:19302'
                ],
                
                # Aggressive ICE gathering for faster connection
                'ice_transport_policy': 'relay',  # Force TURN relay for TCP
            },
            
            # TURN server configuration for TCP relay
            'turn': {
                'enabled': True,
                'domain': 'turn.elosofia.site',  # Or use a public TURN server
                'protocol': 'tcp',
                'port': 3478,
                'username': 'sofia',
                'password': 'secure-turn-password',
                'tls_port': 5349,
                'external_tls': True
            },
            
            'room': {
                'auto_create': True,
                'empty_timeout': 300,
                'max_participants': 50
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
                'json': False
            }
        }
    
    def test_write_fixed_config(self):
        """Test writing the fixed configuration"""
        fixed_config = self.generate_fixed_config()
        
        # Write to a test file
        test_config_path = "/home/elo/elo-deu/livekit-fixed.yaml"
        with open(test_config_path, 'w') as f:
            yaml.dump(fixed_config, f, default_flow_style=False)
        
        # Verify it was written correctly
        with open(test_config_path, 'r') as f:
            loaded = yaml.safe_load(f)
        
        self.assertEqual(loaded['rtc']['tcp_port'], 7881)
        self.assertTrue(loaded['rtc']['ice_lite'])
        self.assertTrue(loaded['turn']['enabled'])


if __name__ == '__main__':
    # Run async tests
    async def run_async_tests():
        suite = unittest.TestLoader().loadTestsFromTestCase(TestLiveKitConfiguration)
        for test in suite:
            if test._testMethodName.startswith('test_livekit_'):
                await getattr(test, test._testMethodName)()
    
    # Run sync tests
    unittest.main(verbosity=2)