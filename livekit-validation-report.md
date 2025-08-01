# LiveKit Configuration Validation Report

Configuration file: livekit-production.yaml
Validation timestamp: 2025-08-01 11:20:41

## Summary
- Errors: 0
- Warnings: 4
- Info: 12

## ⚠️ Warnings (Should Review)
- Weak API secret for key 'devkey'
- Default webhook API key in use
- Consider JSON logging for production
- Prometheus monitoring not configured

## ✅ Configuration Details
- ✓ YAML syntax is valid
- ✓ TCP port configured: 7881
- ✓ UDP disabled for TCP-only mode
- ✓ External IP detection enabled
- ✓ TURN server configured
- ✓ Webhook URLs configured: 1
- ✓ API keys configured: ['devkey']
- ✓ Listening on all interfaces
- ✓ TCP fallback port: 7881
- ✓ TURN server uses LiveKit authentication
- ✓ Docker is available
- ✓ Configuration compatible with LiveKit container

## Production Readiness
✅ Configuration is valid for production use
⚠️ Review warnings for optimal production deployment