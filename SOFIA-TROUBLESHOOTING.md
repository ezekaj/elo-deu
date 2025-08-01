# Sofia Voice Agent Troubleshooting Guide

## Current Status
- **Calendar Server**: Running on port 3005
- **LiveKit**: Running on port 7880
- **ngrok**: Active at https://6ee900d2bd98.ngrok-free.app
- **GitHub Pages**: https://ezekaj.github.io/elo-deu/

## Common Issues and Solutions

### 1. "LiveKitClient is not defined" Error

**Solution Applied**:
- Created `sofia-voice-final.js` with comprehensive SDK loading
- Checks multiple global names (LiveKitClient, livekit, etc.)
- Removes conflicting scripts before loading
- Includes timeout handling

**To verify fix**:
1. Clear browser cache completely
2. Visit https://ezekaj.github.io/elo-deu/
3. Open browser console
4. Click Sofia Agent button
5. Check console for "LiveKit SDK loaded successfully"

### 2. Microphone Permission Issues

**Requirements**:
- HTTPS connection (provided by GitHub Pages)
- Browser microphone permissions enabled

**To fix**:
1. Click the lock icon in browser address bar
2. Set microphone permission to "Allow"
3. Reload the page

### 3. Docker Container Issues

**Current Docker status**:
- Containers are rebuilding (may take 5-10 minutes)
- LiveKit is running in test mode on port 7880

**To check Docker status**:
```bash
docker compose ps
```

**To restart everything**:
```bash
docker compose down
docker compose up -d
```

### 4. Authentication Issues

**Fixed by**:
- Updated .env file with correct LiveKit API secret
- Ensured secret matches across all services
- Added /api/sofia/token endpoint

**Current credentials**:
- API Key: `devkey`
- API Secret: `devsecret_that_is_at_least_32_characters_long`

### 5. Cache Issues

**To force fresh load**:
1. Open browser DevTools (F12)
2. Right-click refresh button
3. Select "Empty Cache and Hard Reload"
4. Or use Incognito/Private mode

### 6. Testing the System

**Test URLs**:
- Calendar: https://ezekaj.github.io/elo-deu/
- LiveKit SDK Test: https://ezekaj.github.io/elo-deu/livekit-sdk-test.html
- Sofia Debug: https://ezekaj.github.io/elo-deu/sofia-debug.html

**Test Steps**:
1. Visit calendar page
2. Check green connection status (top right)
3. Click Sofia Agent button
4. Allow microphone when prompted
5. Speak to test voice input

### 7. Server Logs

**Check calendar server**:
```bash
tail -f /tmp/calendar-restart.log
```

**Check ngrok connections**:
```bash
tail -f /tmp/ngrok-restart.log
```

**Check Docker logs**:
```bash
docker logs elo-deu_livekit_1
docker logs elo-deu_sofia-agent_1
```

## Quick Restart Commands

**Restart calendar server**:
```bash
cd /home/elo/elo-deu/dental-calendar
pkill -f "node server.js"
npm start > /tmp/calendar-restart.log 2>&1 &
```

**Restart LiveKit**:
```bash
docker stop livekit-test
docker rm livekit-test
docker run -d \
  --name livekit-test \
  -p 7880:7880 \
  -p 7881:7881 \
  -e LIVEKIT_KEYS="devkey: devsecret_that_is_at_least_32_characters_long" \
  livekit/livekit-server:latest \
  --dev
```

## Files Updated
1. `/docs/sofia-voice-final.js` - Main Sofia implementation
2. `/docs/index.html` - Updated to use final version
3. `/docs/config.js` - Dynamic configuration
4. `/dental-calendar/.env` - LiveKit credentials
5. `/dental-calendar/server.js` - Added token endpoint

## Next Steps if Still Having Issues
1. Wait for Docker containers to fully rebuild (check with `docker compose ps`)
2. Clear all browser data for the site
3. Try a different browser
4. Check browser console for specific error messages
5. Verify microphone works in browser settings