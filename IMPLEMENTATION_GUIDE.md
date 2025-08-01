# Sofia Dental AI - Complete Fix Implementation Guide

## Overview
This guide provides comprehensive instructions to fix all connection issues in the Sofia Dental AI system, implementing TCP-only mode for global accessibility.

## Issues Identified and Fixed

### 1. **LiveKit Configuration Issues**
- ✅ Added TURN server configuration for TCP relay
- ✅ Set ICE transport policy to 'relay' for TCP-only mode
- ✅ Added STUN servers for ICE negotiation
- ✅ Configured external IP handling
- ✅ Disabled UDP ports (port_range_start/end = 0)

### 2. **Docker Network Resolution**
- ✅ Added health check endpoints to all services
- ✅ Configured proper service dependencies
- ✅ Set up named network with custom bridge
- ✅ Added TURN server container for TCP relay

### 3. **Frontend Signal Flow**
- ✅ LiveKit token endpoint already exists at `/api/livekit-token`
- ✅ Added proper error handling and logging
- ✅ Configured WebSocket URLs for service communication

### 4. **TCP-Only Mode Implementation**
- ✅ Disabled all UDP ports in LiveKit
- ✅ Added TURN server for TCP relay
- ✅ Configured ICE transport policy as 'relay'
- ✅ Set up TCP-only WebRTC connection

## Implementation Steps

### Step 1: Apply All Fixes Automatically
```bash
# Run the quick fix script
./apply-sofia-fixes.sh
```

### Step 2: Manual Implementation (if needed)

#### Update LiveKit Configuration
```bash
# The complete configuration is already in livekit.yaml
# Key changes:
# - TURN server enabled
# - UDP disabled (port_range_start/end = 0)
# - ICE transport policy set to 'relay'
# - STUN servers configured
```

#### Update Docker Compose
```bash
# Use the fixed docker-compose.yml which includes:
# - TURN server service
# - Health checks for all services
# - Proper service dependencies
# - TCP-only port mappings
```

#### Sofia Agent Updates
The agent.py now includes:
- Health check server on port 8080
- Webhook endpoints for LiveKit events
- Proper connection status tracking

### Step 3: Verify Installation

#### Check Service Health
```bash
# LiveKit health
curl http://localhost:7880/health

# Sofia agent health
curl http://localhost:8080/health

# Calendar health
curl http://localhost:3005/health
```

#### Test Token Generation
```bash
curl -X POST http://localhost:3005/api/livekit-token \
  -H 'Content-Type: application/json' \
  -d '{"identity":"test-user","room":"test-room"}'
```

#### Check Docker Network
```bash
# Test network connectivity between services
docker exec elo-deu-sofia-agent-1 ping -c 1 livekit
docker exec elo-deu-sofia-agent-1 curl http://livekit:7880/health
```

### Step 4: Test WebRTC Connection

1. Open http://localhost:3005 in your browser
2. Click "Mit Sofia sprechen" to start voice chat
3. Allow microphone permissions
4. Verify that:
   - Connection establishes without "Internal error"
   - Audio works in both directions
   - Connection uses TCP (check browser WebRTC stats)

## Troubleshooting

### Connection Issues
```bash
# Check all logs
docker-compose logs -f

# Check specific service
docker-compose logs -f livekit
docker-compose logs -f sofia-agent
docker-compose logs -f turn-server
```

### Network Issues
```bash
# Inspect network
docker network inspect elo-deu_sofia-network

# Test DNS resolution
docker exec elo-deu-sofia-agent-1 nslookup livekit
```

### TURN Server Issues
```bash
# Check TURN server logs
docker-compose logs turn-server

# Test TURN connectivity
nc -v localhost 3478
```

## Configuration Details

### LiveKit Configuration (livekit.yaml)
- **Port**: 7880 (HTTP/WebSocket)
- **TCP Port**: 7881 (WebRTC over TCP)
- **UDP**: Disabled (port_range = 0)
- **ICE Policy**: relay (forces TURN usage)
- **TURN**: Enabled with TCP relay

### TURN Server Configuration
- **Port**: 3478 (TCP)
- **TLS Port**: 5349 (TCP)
- **Username**: sofia
- **Password**: turn-password-123
- **UDP**: Disabled (NO_UDP=1)

### Network Configuration
- **Network Name**: sofia-network
- **Bridge Name**: sofia-br
- **Service Names**: livekit, sofia-agent, dental-calendar, turn-server

## Production Deployment

For production deployment:

1. **Update External IP**:
   ```yaml
   rtc:
     external_ip: "YOUR_PUBLIC_IP"  # Replace 'auto' with actual IP
   ```

2. **Configure TURN Domain**:
   ```yaml
   turn:
     domain: "your-domain.com"  # Replace 'localhost'
   ```

3. **Use Proper SSL/TLS**:
   - Enable TLS on TURN server
   - Use wss:// for WebSocket connections
   - Configure proper certificates

4. **Security Hardening**:
   - Change default passwords
   - Use environment variables for secrets
   - Enable firewall rules for TCP ports only

## Validation Checklist

- [ ] All services show "healthy" status
- [ ] Sofia agent health endpoint responds
- [ ] Token generation works
- [ ] Network connectivity between services
- [ ] WebRTC connection establishes
- [ ] Audio works bidirectionally
- [ ] No UDP traffic (TCP-only mode)
- [ ] TURN server relays traffic

## Quick Commands Reference

```bash
# Start everything
docker-compose up -d

# Stop everything
docker-compose down

# View logs
docker-compose logs -f

# Restart a service
docker-compose restart sofia-agent

# Check service status
docker-compose ps

# Test health endpoints
./check-health.sh
```

## Support

If issues persist after following this guide:
1. Check the test results: `python -m pytest tests/test_complete_sofia_fixes.py -v`
2. Review logs for errors: `docker-compose logs -f`
3. Verify network configuration: `docker network ls`
4. Test TURN server separately: `turnutils_uclient -T -p 3478 localhost`