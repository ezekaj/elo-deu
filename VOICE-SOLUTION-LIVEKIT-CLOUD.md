# Use LiveKit Cloud for Voice Features

## Why LiveKit Cloud?
- **Managed WebRTC** infrastructure
- **Global TURN servers** included
- **Works with GitHub Pages** directly
- **No server management** needed
- **Free tier**: 50 participant minutes/month

## Setup Steps

### 1. Create LiveKit Cloud Account
1. Go to https://cloud.livekit.io
2. Sign up for free account
3. Create a new project

### 2. Get Credentials
From LiveKit Cloud dashboard:
- **URL**: `wss://your-project.livekit.cloud`
- **API Key**: `APIxxxxxxxxxxxxx`
- **API Secret**: `secret-key-here`

### 3. Update Docker Environment
Edit `.env`:
```bash
LIVEKIT_URL=wss://your-project.livekit.cloud
LIVEKIT_API_KEY=APIxxxxxxxxxxxxx
LIVEKIT_API_SECRET=your-secret-key
```

### 4. Update Frontend Config
```javascript
window.CONFIG = {
    API_BASE_URL: 'https://0ac90f1eb152.ngrok-free.app',
    LIVEKIT_URL: 'wss://your-project.livekit.cloud',
    // Keep other services on ngrok
};
```

### 5. Modify Sofia Agent
The agent connects to LiveKit Cloud instead of local:
```python
worker_options = agents.WorkerOptions(
    entrypoint_fnc=entrypoint,
    ws_url="wss://your-project.livekit.cloud",
    api_key="APIxxxxxxxxxxxxx",
    api_secret="your-secret-key"
)
```

### 6. Remove Local LiveKit Container
```yaml
# Comment out in docker-compose.yml
# livekit:
#   image: livekit/livekit-server:latest
#   ...
```

## Pricing
- **Free**: 50 participant minutes/month
- **Starter**: $50/month for 10,000 minutes
- **Pay as you go**: $0.006/minute

## Pros & Cons
✅ **Pros**:
- Works immediately
- No infrastructure needed
- Global performance
- Professional TURN/STUN servers

❌ **Cons**:
- Monthly cost after free tier
- Dependency on third-party service
- Internet latency vs local