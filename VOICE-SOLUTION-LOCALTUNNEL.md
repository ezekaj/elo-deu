# Quick Voice Fix with LocalTunnel

## For Testing/Demo Only
LocalTunnel supports WebRTC better than ngrok.

### Install & Run
```bash
# Install
npm install -g localtunnel

# Run tunnels
lt --port 3005 --subdomain sofia-calendar &
lt --port 7880 --subdomain sofia-livekit &
lt --port 8080 --subdomain sofia-agent &

# URLs will be:
# https://sofia-calendar.loca.lt
# https://sofia-livekit.loca.lt
# https://sofia-agent.loca.lt
```

### Update Config
```javascript
window.CONFIG = {
    API_BASE_URL: 'https://sofia-calendar.loca.lt',
    LIVEKIT_URL: 'wss://sofia-livekit.loca.lt',
    SOFIA_URL: 'https://sofia-agent.loca.lt'
};
```

### Add Password Bypass
LocalTunnel shows a password page. Add to your HTML:
```html
<script>
// Auto-bypass LocalTunnel password
if (window.location.host.includes('loca.lt')) {
    fetch(window.location.href, {
        headers: { 'Bypass-Tunnel-Reminder': 'true' }
    });
}
</script>
```

⚠️ **Note**: Only for testing! URLs change frequently.