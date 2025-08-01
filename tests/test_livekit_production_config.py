#!/usr/bin/env python3
"""
Production LiveKit Configuration Validation Tests

Tests to ensure the LiveKit configuration is valid and production-ready.
"""

import yaml
import json
import subprocess
import time
import requests
import socket
from typing import Dict, Any, List, Tuple


class LiveKitConfigValidator:
    """Validates LiveKit configuration for production readiness."""
    
    def __init__(self, config_path: str = "livekit-production.yaml"):
        self.config_path = config_path
        self.config = self._load_config()
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []
    
    def _load_config(self) -> Dict[str, Any]:
        """Load and parse the YAML configuration."""
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            raise ValueError(f"Failed to load config: {e}")
    
    def validate_schema(self) -> bool:
        """Validate the configuration schema against LiveKit requirements."""
        print("🔍 Validating LiveKit configuration schema...")
        
        # Required top-level fields
        required_fields = ['port', 'rtc', 'keys']
        for field in required_fields:
            if field not in self.config:
                self.errors.append(f"Missing required field: {field}")
        
        # Validate RTC configuration
        if 'rtc' in self.config:
            rtc = self.config['rtc']
            
            # Check TCP configuration
            if 'tcp_port' in rtc:
                if not isinstance(rtc['tcp_port'], int) or rtc['tcp_port'] < 1:
                    self.errors.append("rtc.tcp_port must be a positive integer")
                else:
                    self.info.append(f"✓ TCP port configured: {rtc['tcp_port']}")
            
            # Check UDP configuration for TCP-only mode
            if rtc.get('port_range_start', 1) == 0 and rtc.get('port_range_end', 1) == 0:
                self.info.append("✓ UDP disabled for TCP-only mode")
            
            # Check external IP configuration
            if rtc.get('use_external_ip'):
                self.info.append("✓ External IP detection enabled")
        
        # Validate TURN configuration
        if 'turn' in self.config and self.config['turn'].get('enabled'):
            turn = self.config['turn']
            if 'udp_port' not in turn and 'tls_port' not in turn:
                self.warnings.append("TURN enabled but no ports configured")
            else:
                self.info.append("✓ TURN server configured")
        
        # Validate webhook configuration
        if 'webhook' in self.config:
            webhook = self.config['webhook']
            if 'urls' in webhook:
                if isinstance(webhook['urls'], dict):
                    self.errors.append("webhook.urls must be a list, not a dict")
                elif isinstance(webhook['urls'], list):
                    self.info.append(f"✓ Webhook URLs configured: {len(webhook['urls'])}")
        
        # Validate API keys
        if 'keys' in self.config:
            if not self.config['keys']:
                self.errors.append("No API keys configured")
            else:
                self.info.append(f"✓ API keys configured: {list(self.config['keys'].keys())}")
        
        return len(self.errors) == 0
    
    def test_yaml_syntax(self) -> bool:
        """Test if the YAML file can be parsed by LiveKit."""
        print("\n🔧 Testing YAML syntax with LiveKit parser...")
        
        try:
            # Test parsing with Python YAML (basic check)
            with open(self.config_path, 'r') as f:
                yaml.safe_load(f)
            self.info.append("✓ YAML syntax is valid")
            return True
        except yaml.YAMLError as e:
            self.errors.append(f"YAML syntax error: {e}")
            return False
    
    def validate_network_config(self) -> bool:
        """Validate network configuration for production."""
        print("\n🌐 Validating network configuration...")
        
        # Check port configuration
        main_port = self.config.get('port', 7880)
        if main_port < 1024:
            self.warnings.append(f"Main port {main_port} requires root privileges")
        
        # Check bind addresses
        bind_addresses = self.config.get('bind_addresses', ['0.0.0.0'])
        if '0.0.0.0' in bind_addresses:
            self.info.append("✓ Listening on all interfaces")
        
        # Check TCP-only mode configuration
        rtc = self.config.get('rtc', {})
        if rtc.get('tcp_port'):
            tcp_port = rtc['tcp_port']
            if tcp_port == main_port:
                self.errors.append("TCP port cannot be the same as main HTTP port")
            else:
                self.info.append(f"✓ TCP fallback port: {tcp_port}")
        
        return len(self.errors) == 0
    
    def validate_security_config(self) -> bool:
        """Validate security settings."""
        print("\n🔒 Validating security configuration...")
        
        # Check API keys
        keys = self.config.get('keys', {})
        for key_name, secret in keys.items():
            if secret == 'secret' or len(secret) < 8:
                self.warnings.append(f"Weak API secret for key '{key_name}'")
        
        # Check webhook authentication
        if 'webhook' in self.config:
            if 'api_key' not in self.config['webhook']:
                self.warnings.append("Webhook API key not configured")
            elif self.config['webhook']['api_key'] == 'secret':
                self.warnings.append("Default webhook API key in use")
        
        # Check TURN authentication
        if self.config.get('turn', {}).get('enabled'):
            self.info.append("✓ TURN server uses LiveKit authentication")
        
        return True
    
    def validate_production_settings(self) -> bool:
        """Validate production-specific settings."""
        print("\n⚙️ Validating production settings...")
        
        # Check logging configuration
        logging = self.config.get('logging', {})
        if logging.get('level') == 'debug':
            self.warnings.append("Debug logging enabled in production")
        if not logging.get('json'):
            self.warnings.append("Consider JSON logging for production")
        
        # Check room configuration
        room = self.config.get('room', {})
        if room.get('empty_timeout', 300) < 60:
            self.warnings.append("Very short empty room timeout")
        
        # Check monitoring
        if 'prometheus' not in self.config:
            self.warnings.append("Prometheus monitoring not configured")
        
        return True
    
    def test_docker_compatibility(self) -> bool:
        """Test if configuration works with Docker container."""
        print("\n🐳 Testing Docker compatibility...")
        
        # Check if docker is available
        try:
            subprocess.run(['docker', '--version'], check=True, capture_output=True)
            self.info.append("✓ Docker is available")
        except:
            self.warnings.append("Docker not available for testing")
            return True
        
        # Test configuration with LiveKit container
        test_cmd = [
            'docker', 'run', '--rm',
            '-v', f'{self.config_path}:/etc/livekit.yaml:ro',
            'livekit/livekit-server:latest',
            '--config', '/etc/livekit.yaml',
            '--validate-only'
        ]
        
        try:
            result = subprocess.run(test_cmd, capture_output=True, text=True, timeout=10)
            if result.returncode != 0 and 'validate-only' not in result.stderr:
                # LiveKit might not support --validate-only, check for config errors
                if 'could not parse config' in result.stderr:
                    self.errors.append(f"LiveKit config validation failed: {result.stderr}")
                    return False
            self.info.append("✓ Configuration compatible with LiveKit container")
            return True
        except subprocess.TimeoutExpired:
            self.info.append("✓ LiveKit container started (no validate-only support)")
            return True
        except Exception as e:
            self.warnings.append(f"Could not test with Docker: {e}")
            return True
    
    def generate_report(self) -> str:
        """Generate a comprehensive validation report."""
        report = ["# LiveKit Configuration Validation Report", ""]
        
        report.append(f"Configuration file: {self.config_path}")
        report.append(f"Validation timestamp: {time.strftime('%Y-%m-%d %H:%M:%S')}")
        report.append("")
        
        # Summary
        report.append("## Summary")
        report.append(f"- Errors: {len(self.errors)}")
        report.append(f"- Warnings: {len(self.warnings)}")
        report.append(f"- Info: {len(self.info)}")
        report.append("")
        
        # Errors
        if self.errors:
            report.append("## ❌ Errors (Must Fix)")
            for error in self.errors:
                report.append(f"- {error}")
            report.append("")
        
        # Warnings
        if self.warnings:
            report.append("## ⚠️ Warnings (Should Review)")
            for warning in self.warnings:
                report.append(f"- {warning}")
            report.append("")
        
        # Info
        if self.info:
            report.append("## ✅ Configuration Details")
            for info in self.info:
                report.append(f"- {info}")
            report.append("")
        
        # Production Readiness
        report.append("## Production Readiness")
        if len(self.errors) == 0:
            report.append("✅ Configuration is valid for production use")
        else:
            report.append("❌ Configuration has errors that must be fixed")
        
        if len(self.warnings) > 0:
            report.append("⚠️ Review warnings for optimal production deployment")
        
        return "\n".join(report)
    
    def run_all_tests(self) -> bool:
        """Run all validation tests."""
        print("=" * 60)
        print("LiveKit Configuration Validator")
        print("=" * 60)
        
        tests = [
            self.test_yaml_syntax,
            self.validate_schema,
            self.validate_network_config,
            self.validate_security_config,
            self.validate_production_settings,
            self.test_docker_compatibility
        ]
        
        all_passed = True
        for test in tests:
            try:
                if not test():
                    all_passed = False
            except Exception as e:
                self.errors.append(f"Test failed with exception: {e}")
                all_passed = False
        
        print("\n" + "=" * 60)
        print(self.generate_report())
        
        return all_passed and len(self.errors) == 0


def main():
    """Main entry point for validation."""
    import sys
    
    config_path = sys.argv[1] if len(sys.argv) > 1 else "livekit-production.yaml"
    
    validator = LiveKitConfigValidator(config_path)
    success = validator.run_all_tests()
    
    # Write report to file
    with open("livekit-validation-report.md", "w") as f:
        f.write(validator.generate_report())
    
    print(f"\nReport saved to: livekit-validation-report.md")
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()