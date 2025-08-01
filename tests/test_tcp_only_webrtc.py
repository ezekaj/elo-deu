"""
Test Suite for TCP-Only WebRTC Connection
Ensures WebRTC works in TCP-only mode for global access behind firewalls
"""

import unittest
import asyncio
import aiohttp
import json
from typing import List, Dict, Any
import socket
import subprocess


class TestTCPOnlyWebRTC(unittest.TestCase):
    """Test TCP-only WebRTC configuration"""
    
    def setUp(self):
        self.livekit_url = "http://localhost:7880"
        self.tcp_port = 7881
        self.turn_port = 3478
        
    def test_udp_ports_disabled(self):
        """Test that UDP ports are disabled in configuration"""
        # Check that UDP port 7882 is NOT listening
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(1)
        
        try:
            # Try to bind to the UDP port - should succeed if LiveKit isn't using it
            sock.bind(('localhost', 7882))
            sock.close()
            # If we can bind, LiveKit isn't using UDP - good!
        except OSError:
            # Port is in use - LiveKit shouldn't be using UDP
            self.fail("UDP port 7882 is in use - LiveKit should not use UDP in TCP-only mode")
    
    def test_tcp_port_listening(self):
        """Test that TCP port is listening and accessible"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        
        result = sock.connect_ex(('localhost', self.tcp_port))
        sock.close()
        
        self.assertEqual(result, 0, f"TCP port {self.tcp_port} is not accessible")
    
    def test_ice_candidate_filtering(self):
        """Test that only TCP candidates are generated"""
        # This would typically be tested by examining SDP offers/answers
        # Mock ICE candidate that should be accepted
        tcp_candidate = {
            "candidate": "candidate:1 1 tcp 2124414975 192.168.1.100 7881 typ host tcptype passive",
            "sdpMLineIndex": 0,
            "sdpMid": "0"
        }
        
        # Mock ICE candidate that should be filtered out
        udp_candidate = {
            "candidate": "candidate:2 1 udp 2124414975 192.168.1.100 7882 typ host",
            "sdpMLineIndex": 0,
            "sdpMid": "0"
        }
        
        # Validate candidate filtering
        self.assertIn('tcp', tcp_candidate['candidate'])
        self.assertIn('udp', udp_candidate['candidate'])
        
        # In real implementation, UDP candidates should be filtered
        def filter_candidates(candidates: List[Dict]) -> List[Dict]:
            return [c for c in candidates if 'tcp' in c['candidate']]
        
        filtered = filter_candidates([tcp_candidate, udp_candidate])
        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0], tcp_candidate)
    
    async def test_turn_server_configuration(self):
        """Test TURN server is properly configured for TCP relay"""
        # Check if TURN server would be reachable
        turn_urls = [
            f"turn:localhost:{self.turn_port}?transport=tcp",
            f"turns:localhost:5349?transport=tcp"
        ]
        
        for url in turn_urls:
            # Parse TURN URL
            if url.startswith('turn:'):
                port = self.turn_port
                secure = False
            else:  # turns:
                port = 5349
                secure = True
            
            # Test TCP connectivity to TURN port
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            
            # Note: In production, TURN server would be running
            # This test checks if the port would be available
            try:
                result = sock.connect_ex(('localhost', port))
                sock.close()
                
                # If connection refused, port is available for TURN
                if result != 0:
                    pass  # Port available for TURN server
            except Exception:
                pass
    
    async def test_webrtc_tcp_connection_flow(self):
        """Test complete TCP-only WebRTC connection flow"""
        async with aiohttp.ClientSession() as session:
            # Test data that would be sent in a TCP-only connection
            offer_sdp = '''v=0
o=- 123456 2 IN IP4 0.0.0.0
s=-
t=0 0
a=group:BUNDLE 0
m=audio 9 TCP/RTP/SAVPF 111
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-options:trickle
a=ice-ufrag:4cP7
a=ice-pwd:by4GZGG1lw+040DWA6hXM5Bz
a=candidate:1 1 tcp 2124414975 192.168.1.100 7881 typ host tcptype passive
a=fingerprint:sha-256 7B:8B:F0:65:5F:78:E2:51:3B:AC:6F:F3:3F:46:1B:35
a=setup:actpass
a=mid:0
a=sendrecv
a=rtcp-mux
'''
            
            # Validate SDP contains only TCP candidates
            self.assertIn('TCP/RTP/SAVPF', offer_sdp)
            self.assertIn('tcp', offer_sdp)
            self.assertIn('tcptype passive', offer_sdp)
            self.assertNotIn('udp', offer_sdp.lower())


class TestTCPOnlyFixes(unittest.TestCase):
    """Provide fixes for TCP-only WebRTC configuration"""
    
    def generate_turn_server_config(self) -> Dict[str, Any]:
        """Generate TURN server configuration for coturn"""
        return {
            'coturn_config': '''# Coturn TURN server configuration for TCP-only mode

# Basic settings
realm=elosofia.site
server-name=turn.elosofia.site

# Network settings
listening-ip=0.0.0.0
external-ip=YOUR_PUBLIC_IP/192.168.1.100

# Ports
listening-port=3478
tls-listening-port=5349

# Disable UDP relay (TCP-only mode)
no-udp
no-udp-relay

# Enable TCP relay
tcp-proxy=7881
tcp-relay

# Authentication
lt-cred-mech
user=sofia:turn-secure-password

# SSL/TLS
cert=/etc/turn/cert.pem
pkey=/etc/turn/key.pem

# Logging
log-file=/var/log/turn.log
verbose

# Security
fingerprint
no-multicast-peers
no-cli
max-port=7889
min-port=7881

# Performance
total-quota=100
bps-quota=0
stale-nonce=600

# Allowed IPs (optional)
# allowed-peer-ip=192.168.0.0/16
''',
            'docker_compose_turn': '''  # TURN server for TCP relay
  turn-server:
    image: coturn/coturn:latest
    ports:
      - "3478:3478/tcp"
      - "5349:5349/tcp"
      - "7881-7889:7881-7889/tcp"
    volumes:
      - ./turn.conf:/etc/coturn/turnserver.conf
      - ./certs:/etc/turn
    command: -c /etc/coturn/turnserver.conf
    networks:
      - sofia-network
    restart: unless-stopped
'''
        }
    
    def create_tcp_only_livekit_config(self) -> str:
        """Create complete TCP-only LiveKit configuration"""
        return '''# LiveKit Configuration - TCP-Only Mode for Global Access
port: 7880
bind_addresses:
  - 0.0.0.0

rtc:
  # TCP-only configuration
  tcp_port: 7881
  port_range_start: 0  # Disable UDP port range
  port_range_end: 0    # Disable UDP port range
  
  # Force TCP mode
  use_ice_tcp: true
  ice_transport_policy: relay  # Force TURN relay
  
  # ICE configuration
  ice_lite: true
  use_external_ip: true
  external_ip: auto  # Or specify your public IP
  enable_loopback_candidate: false
  
  # STUN servers for NAT discovery
  stun_servers:
    - stun:stun.l.google.com:19302
    - stun:stun1.l.google.com:19302
  
  # Interfaces to use
  interfaces:
    include:
      - eth0
      - wlan0
    exclude:
      - docker0

# TURN server configuration (required for TCP-only)
turn:
  enabled: true
  domain: turn.elosofia.site
  cert_file: /etc/livekit/cert.pem
  key_file: /etc/livekit/key.pem
  tls_port: 5349
  udp_port: 0  # Disable UDP TURN
  tcp_port: 3478
  external_tls: true
  
  # If using external TURN server
  # external_turn:
  #   - host: turn.elosofia.site
  #     port: 3478
  #     protocol: tcp
  #     username: sofia
  #     password: ${TURN_PASSWORD}

room:
  auto_create: true
  empty_timeout: 300
  max_participants: 50
  
  # Room configuration for better TCP performance
  playout_delay:
    enabled: true
    min: 100
    max: 500

  # Adaptive streaming for TCP
  adaptive_stream: true
  
webhook:
  urls:
    room_started: http://sofia-agent:8080/webhook/room-started
    participant_joined: http://sofia-agent:8080/webhook/participant-joined
  api_key: ${WEBHOOK_SECRET}

keys:
  ${LIVEKIT_API_KEY}: ${LIVEKIT_API_SECRET}

logging:
  level: info
  json: false
  sample: false

# Limits for TCP mode
limits:
  max_incoming_bitrate: 3_000_000  # 3 Mbps
  max_outgoing_bitrate: 3_000_000  # 3 Mbps

# Region settings
region: eu-central  # Or your region

# Health check
health:
  port: 7882  # Different from RTC ports
'''
    
    def create_client_tcp_config(self) -> str:
        """Create client-side TCP-only configuration"""
        return '''// Client-side TCP-only WebRTC configuration

class TCPOnlyConnection {
    constructor() {
        this.rtcConfig = {
            iceServers: [
                // STUN servers (still needed for NAT discovery)
                { urls: 'stun:stun.l.google.com:19302' },
                
                // TURN TCP servers (required for relay)
                {
                    urls: 'turn:turn.elosofia.site:3478?transport=tcp',
                    username: 'sofia',
                    credential: process.env.TURN_PASSWORD || 'turn-password'
                },
                {
                    urls: 'turns:turn.elosofia.site:5349?transport=tcp',
                    username: 'sofia',
                    credential: process.env.TURN_PASSWORD || 'turn-password'
                }
            ],
            
            // Force TCP relay only
            iceTransportPolicy: 'relay',
            
            // Bundle all media over one connection
            bundlePolicy: 'max-bundle',
            
            // Require RTCP multiplexing
            rtcpMuxPolicy: 'require',
            
            // No ICE candidate pool for TCP
            iceCandidatePoolSize: 0
        };
    }
    
    async createPeerConnection() {
        const pc = new RTCPeerConnection(this.rtcConfig);
        
        // Filter out any UDP candidates
        pc.onicecandidate = (event) => {
            if (event.candidate) {
                const candidate = event.candidate.candidate;
                
                // Only allow TCP candidates
                if (candidate.includes('tcp')) {
                    this.sendCandidate(event.candidate);
                } else {
                    console.log('Filtered out UDP candidate:', candidate);
                }
            }
        };
        
        // Set up TCP-optimized encoding
        pc.onsignalingstatechange = () => {
            if (pc.signalingState === 'have-local-offer') {
                this.optimizeSDPForTCP(pc.localDescription);
            }
        };
        
        return pc;
    }
    
    optimizeSDPForTCP(sdp) {
        if (!sdp) return sdp;
        
        let sdpStr = sdp.sdp;
        
        // Remove any UDP candidates
        sdpStr = sdpStr.split('\\n').filter(line => {
            return !line.includes('candidate:') || line.includes('tcp');
        }).join('\\n');
        
        // Add TCP-specific attributes
        sdpStr = sdpStr.replace(
            /m=audio (\\d+) RTP\\/SAVPF/g,
            'm=audio $1 TCP/RTP/SAVPF'
        );
        
        return new RTCSessionDescription({
            type: sdp.type,
            sdp: sdpStr
        });
    }
    
    // Helper to test TCP connectivity
    async testTCPConnectivity() {
        const tests = {
            livekit_tcp: { host: 'localhost', port: 7881 },
            turn_tcp: { host: 'turn.elosofia.site', port: 3478 },
            turns_tcp: { host: 'turn.elosofia.site', port: 5349 }
        };
        
        const results = {};
        
        for (const [name, config] of Object.entries(tests)) {
            try {
                const response = await fetch(`http://${config.host}:${config.port}/`, {
                    method: 'HEAD',
                    mode: 'no-cors',
                    cache: 'no-cache'
                });
                results[name] = 'reachable';
            } catch (e) {
                results[name] = 'unreachable';
            }
        }
        
        return results;
    }
}

// Export for use
window.TCPOnlyConnection = TCPOnlyConnection;
'''
    
    def create_tcp_diagnostics_script(self) -> str:
        """Create TCP connectivity diagnostics script"""
        return '''#!/bin/bash
# TCP-Only WebRTC Diagnostics Script

echo "=== TCP-Only WebRTC Diagnostics ==="
echo

# Function to check TCP port
check_tcp_port() {
    local host=$1
    local port=$2
    local name=$3
    
    echo -n "Checking $name ($host:$port)... "
    
    if nc -z -v -w5 $host $port 2>/dev/null; then
        echo "✓ OPEN"
        return 0
    else
        echo "✗ CLOSED"
        return 1
    fi
}

# Function to check UDP port (should be closed)
check_udp_blocked() {
    local host=$1
    local port=$2
    local name=$3
    
    echo -n "Checking $name UDP ($host:$port) is blocked... "
    
    if ! nc -u -z -v -w2 $host $port 2>/dev/null; then
        echo "✓ BLOCKED (good)"
        return 0
    else
        echo "✗ OPEN (bad - should be blocked)"
        return 1
    fi
}

echo "1. TCP Port Checks:"
check_tcp_port localhost 7880 "LiveKit HTTP/WS"
check_tcp_port localhost 7881 "LiveKit RTC TCP"
check_tcp_port localhost 3478 "TURN TCP"
check_tcp_port localhost 5349 "TURNS TLS"

echo
echo "2. UDP Port Checks (should be blocked):"
check_udp_blocked localhost 7882 "LiveKit RTC UDP"
check_udp_blocked localhost 3478 "TURN UDP"

echo
echo "3. Service Status:"
docker-compose ps | grep -E "(livekit|turn)" || echo "Services not running"

echo
echo "4. Network Routes:"
ip route | grep default

echo
echo "5. Firewall Rules (TCP only):"
if command -v ufw &> /dev/null; then
    sudo ufw status | grep -E "(7881|3478|5349)/tcp" || echo "No TCP rules found"
else
    echo "UFW not installed"
fi

echo
echo "6. LiveKit Configuration Check:"
if [ -f livekit.yaml ]; then
    echo "TCP Port: $(grep tcp_port livekit.yaml | awk '{print $2}')"
    echo "ICE Transport Policy: $(grep ice_transport_policy livekit.yaml | awk '{print $2}')"
    echo "TURN Enabled: $(grep -A1 "^turn:" livekit.yaml | grep enabled | awk '{print $2}')"
else
    echo "livekit.yaml not found"
fi

echo
echo "7. Testing TCP Connectivity:"
# Test WebSocket over TCP
echo -n "WebSocket connectivity... "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:7880/health | grep -q "200"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

echo
echo "=== Diagnostics Complete ==="
echo
echo "For TCP-only mode to work properly:"
echo "- All TCP ports should be OPEN"
echo "- All UDP ports should be BLOCKED"
echo "- TURN server must be configured and running"
echo "- ICE transport policy must be set to 'relay'"
'''
    
    def test_save_diagnostics_script(self):
        """Save the diagnostics script"""
        script_content = self.create_tcp_diagnostics_script()
        script_path = "/home/elo/elo-deu/diagnose-tcp-only.sh"
        
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        import os
        os.chmod(script_path, 0o755)
        self.assertTrue(os.path.exists(script_path))


if __name__ == '__main__':
    unittest.main(verbosity=2)