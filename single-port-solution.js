// Add this to dental-calendar/server.js to proxy LiveKit properly

const httpProxy = require('http-proxy');

// Create a proxy server for LiveKit
const livekitProxy = httpProxy.createProxyServer({
  target: 'http://livekit:7880',
  ws: true,
  changeOrigin: true
});

// Handle LiveKit HTTP requests
app.all('/livekit/*', (req, res) => {
  req.url = req.url.replace('/livekit', '');
  livekitProxy.web(req, res);
});

// Handle LiveKit WebSocket upgrade
server.on('upgrade', (req, socket, head) => {
  if (req.url.startsWith('/livekit')) {
    req.url = req.url.replace('/livekit', '');
    livekitProxy.ws(req, socket, head);
  }
});

// Update config.js to use paths instead of ports:
// LIVEKIT_URL: window.location.protocol.replace('http', 'ws') + '//' + window.location.host + '/livekit'