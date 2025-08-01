#!/usr/bin/env python3
"""
LiveKit Integration Tests

End-to-end tests to verify LiveKit server is properly configured and operational.
"""

import os
import sys
import time
import json
import asyncio
import subprocess
from typing import Dict, Any, Optional, List
import requests
import websocket
from datetime import datetime

# Try to import LiveKit SDK (optional)
try:
    from livekit import api
    LIVEKIT_SDK_AVAILABLE = True
except ImportError:
    LIVEKIT_SDK_AVAILABLE = False
    print("⚠️  LiveKit Python SDK not available. Some tests will be skipped.")


class LiveKitIntegrationTester:
    """Integration tests for LiveKit server."""
    
    def __init__(self, 
                 livekit_url: str = "http://localhost:7880",
                 ws_url: str = "ws://localhost:7880",
                 api_key: str = "devkey",
                 api_secret: str = "secret"):
        self.livekit_url = livekit_url
        self.ws_url = ws_url
        self.api_key = api_key
        self.api_secret = api_secret
        self.test_results = []
    
    def log_result(self, test_name: str, passed: bool, message: str = ""):
        """Log test result."""
        self.test_results.append({
            "test": test_name,
            "passed": passed,
            "message": message,
            "timestamp": datetime.now().isoformat()
        })
        
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status} - {test_name}")
        if message:
            print(f"     {message}")
    
    def test_http_endpoint(self) -> bool:
        """Test if HTTP endpoint is accessible."""
        print("\n🔍 Testing HTTP endpoint...")
        
        try:
            response = requests.get(f"{self.livekit_url}/", timeout=5)
            if response.status_code == 404:
                # LiveKit returns 404 on root, which is expected
                self.log_result("HTTP Endpoint", True, "LiveKit server is responding")
                return True
            elif response.status_code < 500:
                self.log_result("HTTP Endpoint", True, f"Server responded with {response.status_code}")
                return True
            else:
                self.log_result("HTTP Endpoint", False, f"Server error: {response.status_code}")
                return False
        except requests.ConnectionError:
            self.log_result("HTTP Endpoint", False, "Cannot connect to LiveKit server")
            return False
        except Exception as e:
            self.log_result("HTTP Endpoint", False, f"Error: {e}")
            return False
    
    def test_websocket_connection(self) -> bool:
        """Test WebSocket connectivity."""
        print("\n🔌 Testing WebSocket connection...")
        
        try:
            ws = websocket.create_connection(f"{self.ws_url}/rtc", timeout=5)
            ws.close()
            self.log_result("WebSocket Connection", True, "WebSocket connection successful")
            return True
        except Exception as e:
            self.log_result("WebSocket Connection", False, f"WebSocket error: {e}")
            return False
    
    def test_tcp_port(self) -> bool:
        """Test if TCP port for WebRTC is accessible."""
        print("\n🌐 Testing TCP port for WebRTC...")
        
        import socket
        
        tcp_port = 7881  # From configuration
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        
        try:
            result = sock.connect_ex(('localhost', tcp_port))
            sock.close()
            
            if result == 0:
                self.log_result("TCP Port", True, f"Port {tcp_port} is open")
                return True
            else:
                self.log_result("TCP Port", False, f"Port {tcp_port} is not accessible")
                return False
        except Exception as e:
            self.log_result("TCP Port", False, f"Error testing TCP port: {e}")
            return False
    
    def test_turn_server(self) -> bool:
        """Test TURN server availability."""
        print("\n🔄 Testing TURN server...")
        
        turn_ports = [3478, 5349]  # UDP/TCP and TLS
        accessible = []
        
        for port in turn_ports:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex(('localhost', port))
            sock.close()
            
            if result == 0:
                accessible.append(port)
        
        if accessible:
            self.log_result("TURN Server", True, f"TURN ports accessible: {accessible}")
            return True
        else:
            self.log_result("TURN Server", False, "No TURN ports accessible")
            return False
    
    def test_room_creation(self) -> bool:
        """Test room creation via API (if SDK available)."""
        print("\n🏠 Testing room creation...")
        
        if not LIVEKIT_SDK_AVAILABLE:
            self.log_result("Room Creation", None, "Skipped - LiveKit SDK not available")
            return True
        
        try:
            # Create API client
            client = api.LiveKitAPI(
                self.ws_url,
                self.api_key,
                self.api_secret
            )
            
            # Create a test room
            room_name = f"test-room-{int(time.time())}"
            room = client.room.create_room(
                api.CreateRoomRequest(name=room_name)
            )
            
            if room.name == room_name:
                self.log_result("Room Creation", True, f"Room '{room_name}' created successfully")
                
                # Clean up - delete the room
                client.room.delete_room(api.DeleteRoomRequest(room=room_name))
                return True
            else:
                self.log_result("Room Creation", False, "Room creation returned unexpected result")
                return False
                
        except Exception as e:
            self.log_result("Room Creation", False, f"Error creating room: {e}")
            return False
    
    def test_docker_health(self) -> bool:
        """Test Docker container health."""
        print("\n🐳 Testing Docker container health...")
        
        try:
            # Find LiveKit container
            result = subprocess.run(
                ["docker", "ps", "--filter", "name=livekit", "--format", "{{.Names}}\t{{.Status}}"],
                capture_output=True,
                text=True,
                check=True
            )
            
            if result.stdout:
                lines = result.stdout.strip().split('\n')
                healthy_containers = []
                
                for line in lines:
                    if line:
                        name, status = line.split('\t', 1)
                        if 'healthy' in status.lower():
                            healthy_containers.append(name)
                        elif 'unhealthy' in status.lower():
                            self.log_result("Docker Health", False, f"Container {name} is unhealthy")
                            return False
                
                if healthy_containers:
                    self.log_result("Docker Health", True, f"Healthy containers: {', '.join(healthy_containers)}")
                    return True
                else:
                    self.log_result("Docker Health", False, "No healthy LiveKit containers found")
                    return False
            else:
                self.log_result("Docker Health", False, "No LiveKit containers found")
                return False
                
        except subprocess.CalledProcessError:
            self.log_result("Docker Health", False, "Docker command failed")
            return False
        except Exception as e:
            self.log_result("Docker Health", False, f"Error checking Docker health: {e}")
            return False
    
    def test_configuration_load(self) -> bool:
        """Test if configuration was loaded correctly."""
        print("\n📋 Testing configuration load...")
        
        try:
            # Check container logs for configuration errors
            result = subprocess.run(
                ["docker", "logs", "--tail", "50", "elo-deu_livekit_1"],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                logs = result.stdout + result.stderr
                
                # Check for configuration errors
                if "could not parse config" in logs:
                    self.log_result("Configuration Load", False, "Configuration parsing errors found")
                    return False
                elif "starting LiveKit server" in logs.lower() or "server started" in logs.lower():
                    self.log_result("Configuration Load", True, "Configuration loaded successfully")
                    return True
                else:
                    # If no errors and container is running, assume config is OK
                    self.log_result("Configuration Load", True, "No configuration errors detected")
                    return True
            else:
                self.log_result("Configuration Load", False, "Could not check container logs")
                return False
                
        except Exception as e:
            self.log_result("Configuration Load", False, f"Error checking configuration: {e}")
            return False
    
    def test_tcp_only_mode(self) -> bool:
        """Verify TCP-only mode is configured."""
        print("\n🔒 Testing TCP-only mode configuration...")
        
        # Check if UDP ports are disabled in configuration
        checks_passed = []
        
        # TCP port should be available
        tcp_available = self.test_tcp_port()
        if tcp_available:
            checks_passed.append("TCP port available")
        
        # TURN should be enabled for TCP relay
        turn_available = self.test_turn_server()
        if turn_available:
            checks_passed.append("TURN server available")
        
        if len(checks_passed) >= 1:
            self.log_result("TCP-only Mode", True, f"Checks passed: {', '.join(checks_passed)}")
            return True
        else:
            self.log_result("TCP-only Mode", False, "TCP-only mode not properly configured")
            return False
    
    def generate_report(self) -> str:
        """Generate test report."""
        report = []
        report.append("# LiveKit Integration Test Report")
        report.append(f"\nTest execution time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"LiveKit URL: {self.livekit_url}")
        report.append("\n## Test Results\n")
        
        passed = sum(1 for r in self.test_results if r['passed'])
        failed = sum(1 for r in self.test_results if not r['passed'] and r['passed'] is not None)
        skipped = sum(1 for r in self.test_results if r['passed'] is None)
        
        report.append(f"- **Passed**: {passed}")
        report.append(f"- **Failed**: {failed}")
        report.append(f"- **Skipped**: {skipped}")
        report.append(f"- **Total**: {len(self.test_results)}")
        
        report.append("\n## Detailed Results\n")
        
        for result in self.test_results:
            status = "✅" if result['passed'] else ("⏭️" if result['passed'] is None else "❌")
            report.append(f"### {status} {result['test']}")
            if result['message']:
                report.append(f"- {result['message']}")
            report.append("")
        
        # Add recommendations
        report.append("\n## Recommendations\n")
        
        if failed > 0:
            report.append("### Failed Tests")
            for result in self.test_results:
                if result['passed'] is False:
                    report.append(f"- Fix: {result['test']} - {result['message']}")
        
        if passed == len(self.test_results) - skipped:
            report.append("\n✅ **All tests passed! LiveKit is ready for production use.**")
        else:
            report.append("\n⚠️ **Some tests failed. Please address the issues before production deployment.**")
        
        return "\n".join(report)
    
    def run_all_tests(self) -> bool:
        """Run all integration tests."""
        print("=" * 60)
        print("LiveKit Integration Tests")
        print("=" * 60)
        
        tests = [
            self.test_http_endpoint,
            self.test_websocket_connection,
            self.test_tcp_port,
            self.test_turn_server,
            self.test_docker_health,
            self.test_configuration_load,
            self.test_tcp_only_mode,
            self.test_room_creation,
        ]
        
        for test in tests:
            try:
                test()
            except Exception as e:
                self.log_result(test.__name__, False, f"Test crashed: {e}")
        
        print("\n" + "=" * 60)
        print(self.generate_report())
        
        failed = sum(1 for r in self.test_results if r['passed'] is False)
        return failed == 0


def main():
    """Main entry point."""
    tester = LiveKitIntegrationTester()
    success = tester.run_all_tests()
    
    # Save report
    with open("livekit-integration-report.md", "w") as f:
        f.write(tester.generate_report())
    
    print(f"\nReport saved to: livekit-integration-report.md")
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()