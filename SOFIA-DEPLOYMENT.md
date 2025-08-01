# Sofia Dental Calendar - Deployment to elosofia.site

## Overview
This document explains how to deploy the Sofia dental calendar system to elosofia.site using GitHub Pages and ngrok for backend connectivity.

## Current Status
- ✅ Docker containers running locally (commit 952e69b)
- ✅ ngrok tunnel active: https://0ac90f1eb152.ngrok-free.app
- ✅ GitHub Pages deployed at: https://elosofia.site
- ✅ Configuration files updated with ngrok URLs
- ⚠️ WebRTC through ngrok has limitations (media streams don't work properly)

## Architecture

```
[elosofia.site] --> [ngrok tunnel] --> [Local Docker containers]
     |                    |                      |
     |                    |                      ├── dental-calendar:3005
     |                    |                      ├── livekit:7880
     |                    |                      ├── sofia-agent:8080
     |                    |                      ├── crm:5000
     |                    |                      └── sofia-web:5002
     |                    |
     └── Static files     └── Proxies requests
         (GitHub Pages)
```

## Quick Start

1. **Start Docker containers:**
   ```bash
   cd /home/elo/elo-deu
   docker-compose up -d
   ```

2. **Start ngrok tunnel:**
   ```bash
   ./start-ngrok.sh
   ```

3. **Update configuration (if ngrok URL changes):**
   - Edit `docs/config.js` with the new ngrok URL
   - Commit and push to GitHub

4. **Access the site:**
   - Open https://elosofia.site
   - Calendar interface loads from GitHub Pages
   - API calls are proxied through ngrok to local containers

## Configuration Files

### docs/config.js
```javascript
window.CONFIG = {
    API_BASE_URL: isGitHubPages 
        ? 'https://YOUR-NGROK-ID.ngrok-free.app'  // Update this
        : 'http://localhost:3005',
    // ... other configs
};
```

### Docker Services
- **dental-calendar**: Main calendar API (port 3005)
- **livekit**: WebRTC server for voice (port 7880)
- **sofia-agent**: AI voice agent (port 8080)
- **crm**: Customer management (port 5000)
- **sofia-web**: Web interface (port 5002)

## Limitations

### WebRTC through ngrok
- ngrok is an HTTP/HTTPS proxy and cannot properly handle WebRTC media streams
- Voice features work locally but not through ngrok tunnel
- Solutions:
  1. Use a proper TURN server for production
  2. Deploy services to a cloud provider with public IPs
  3. Use a WebRTC-compatible tunneling solution

### ngrok Free Tier
- URLs change on restart
- Connection limits apply
- Browser warning page (handled in code)

## Troubleshooting

### "Could not establish pc connection"
This is a WebRTC limitation with ngrok. The signaling works but media streams cannot traverse the HTTP proxy.

### ngrok URL changes
1. Run `./start-ngrok.sh` to get new URL
2. Update `docs/config.js` with new URL
3. Commit and push to GitHub
4. Wait for GitHub Pages to deploy (~1-2 minutes)

### Docker containers not accessible
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs -f [service-name]

# Restart all services
docker-compose restart
```

### GitHub Pages not updating
- Check Actions tab on GitHub for deployment status
- Clear browser cache
- Add version query string to force refresh: `?v=2`

## Production Deployment

For production use, consider:

1. **Cloud Hosting**: Deploy to AWS/GCP/Azure with public IPs
2. **TURN Server**: Set up coturn for WebRTC connectivity
3. **SSL Certificates**: Use Let's Encrypt for HTTPS
4. **Domain Configuration**: Point elosofia.site directly to cloud servers
5. **Database**: Use PostgreSQL instead of SQLite
6. **Monitoring**: Add logging and health checks

## Environment Variables

Create `.env` file with:
```bash
GOOGLE_API_KEY=your-gemini-api-key
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=devsecret_that_is_at_least_32_characters_long
```

## Maintenance

### Update ngrok URL
```bash
# When ngrok restarts and URL changes
./start-ngrok.sh
# Copy new URL from output
# Update docs/config.js
git add docs/config.js
git commit -m "Update ngrok URL"
git push origin master
```

### Update Docker images
```bash
docker-compose pull
docker-compose up -d
```

### View logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f dental-calendar
```

## Contact
For issues or questions about the deployment, check the Docker logs first, then the browser console for JavaScript errors.