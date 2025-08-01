# Sofia Dental AI - Test-Driven Fix Implementation Plan

## Executive Summary

The Sofia Dental AI system is experiencing critical connection failures due to:
1. **LiveKit configuration errors** - Missing TURN server config and TCP-only settings
2. **Docker network issues** - Services cannot resolve each other's hostnames
3. **Missing API endpoints** - Calendar server lacks WebRTC token generation
4. **Frontend signaling errors** - "Internal error" when establishing connections

## Current State Analysis

### 🔴 FAILING: LiveKit Configuration
```yaml
# Current livekit.yaml is missing:
- TURN server configuration (required for TCP mode)
- ICE transport policy setting
- STUN servers
- External IP configuration
- UDP port disabling
```

### 🔴 FAILING: Docker Network
```
Error: "Cannot connect to host livekit:7880 ssl:default [Temporary failure in name resolution]"
- Sofia agent container cannot resolve 'livekit' hostname
- Services are not on the same Docker network
- Missing health check endpoints
```

### 🔴 FAILING: API Endpoints
```
Error: "could not establish signal error: Internal error"
- /api/livekit-token endpoint not implemented
- Token generation failing
- WebSocket connection cannot be established
```

### 🔴 FAILING: TCP-Only Mode
```
- UDP ports still enabled (should be disabled)
- No TURN server running for TCP relay
- Client not configured for TCP-only transport
```

## Implementation Steps

### Phase 1: Fix LiveKit Configuration (Priority: CRITICAL)

**1.1 Apply Complete Configuration**
```bash
# Test command to verify issue:
python -m pytest tests/test_complete_sofia_fixes.py::TestSofiaSystemIssues::test_livekit_config_missing_fields -v

# Fix:
cp livekit-complete.yaml livekit.yaml

# Verify fix:
docker-compose restart livekit
docker-compose logs livekit | grep -i error
```

**1.2 Key Configuration Changes**
- Add TURN server config for TCP relay
- Set `ice_transport_policy: relay` for TCP-only
- Disable UDP ports (set range to 0)
- Add STUN servers for NAT discovery

### Phase 2: Fix Docker Networking (Priority: CRITICAL)

**2.1 Update Docker Compose**
```bash
# Test command:
python -m pytest tests/test_complete_sofia_fixes.py::TestSofiaSystemIssues::test_sofia_agent_cannot_resolve_livekit -v

# Fix:
docker-compose down
docker-compose -f docker-compose-fixed.yml up -d

# Verify:
docker exec elo-deu-sofia-agent-1 ping -c 1 livekit
```

**2.2 Add Health Endpoints**
- Implement /health endpoint in agent.py
- Add webhook endpoints for room events
- Configure proper health checks in docker-compose

### Phase 3: Implement Missing APIs (Priority: HIGH)

**3.1 Add Token Endpoint to Calendar Server**
```javascript
// Test command:
curl -X POST http://localhost:3005/api/livekit-token \
  -H "Content-Type: application/json" \
  -d '{"identity": "test", "room": "test-room"}'

// Expected: {"token": "...", "url": "ws://localhost:7880"}
```

**3.2 Update Frontend Connection**
- Use new token endpoint
- Configure TCP-only WebRTC
- Handle connection errors gracefully

### Phase 4: Enable TCP-Only Mode (Priority: HIGH)

**4.1 Start TURN Server**
```bash
# Add TURN server to docker-compose
docker-compose up -d turn-server

# Test TURN connectivity:
nc -zv localhost 3478
```

**4.2 Configure Client for TCP**
- Set `iceTransportPolicy: 'relay'`
- Configure TURN servers in RTCPeerConnection
- Filter out UDP candidates

## Test Validation Plan

### Unit Tests (Run First)
```bash
# Run all failing tests to see current state:
python -m pytest tests/test_complete_sofia_fixes.py::TestSofiaSystemIssues -v

# Expected: All tests should FAIL initially
```

### Integration Tests (After Each Fix)
```bash
# After LiveKit config fix:
python -m pytest tests/test_livekit_configuration.py -v

# After Docker network fix:
python -m pytest tests/test_docker_network_connectivity.py -v

# After API implementation:
python -m pytest tests/test_frontend_backend_signal_flow.py -v

# After TCP-only setup:
python -m pytest tests/test_tcp_only_webrtc.py -v
```

### End-to-End Test
```bash
# Final validation:
python -m pytest tests/test_sofia_agent_connection.py -v
```

## Quick Fix Option

For immediate results, run:
```bash
# Apply all fixes at once:
./apply-sofia-fixes.sh

# This will:
# 1. Update LiveKit config
# 2. Restart all services with fixes
# 3. Run health checks
# 4. Display status
```

## Success Criteria

✅ **LiveKit**: Health check returns 200 OK
✅ **Sofia Agent**: Can resolve and connect to LiveKit
✅ **Calendar API**: Token endpoint returns valid JWT
✅ **Frontend**: Establishes WebRTC connection without errors
✅ **TCP Mode**: Works behind restrictive firewalls

## Monitoring & Validation

### Real-time Logs
```bash
# Watch all services:
docker-compose logs -f

# Watch specific service:
docker-compose logs -f sofia-agent
```

### Connection Test
```bash
# Test complete flow:
curl -X POST http://localhost:3005/api/sofia/connect \
  -H "Content-Type: application/json" \
  -d '{"participantName": "Test User", "roomName": "test-room"}'
```

### Network Diagnostics
```bash
# Run diagnostics:
./diagnose-tcp-only.sh
```

## Rollback Plan

If issues occur:
```bash
# Restore original config:
cp livekit.yaml.backup livekit.yaml

# Use original docker-compose:
docker-compose down
docker-compose up -d
```

## Timeline

- **Phase 1**: 15 minutes (LiveKit config)
- **Phase 2**: 20 minutes (Docker networking)
- **Phase 3**: 30 minutes (API implementation)
- **Phase 4**: 15 minutes (TCP-only setup)
- **Testing**: 20 minutes

**Total**: ~1.5-2 hours for complete implementation

## Next Steps

1. Run failing tests to confirm issues
2. Apply Phase 1 fixes (most critical)
3. Test and verify each phase
4. Run complete test suite
5. Deploy to production