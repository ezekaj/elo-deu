# 🎉 Sofia Deployment Status

## ✅ Services Running

### Local Services (Your Machine)
- **Web Interface**: http://localhost:3005 ✓
- **CRM Dashboard**: http://localhost:5000 ✓
- **LiveKit (Voice)**: ws://localhost:7880 ✓
- **Sofia Agent**: http://localhost:8080 ✓

### Ngrok Tunnels (Secure Public Access)
- **Web Interface**: https://772ec752906e.ngrok-free.app
- **CRM Dashboard**: https://3358fa3712d6.ngrok-free.app
- **LiveKit**: https://9608f5535742.ngrok-free.app

### GitHub Pages
- **URL**: https://elosofia.site
- **Status**: DNS configured, waiting for GitHub Pages to activate
- **Alternate**: https://ezekaj.github.io/elo-deu/

## 🔧 How to Use

### 1. Test Direct Access
Visit: https://772ec752906e.ngrok-free.app

### 2. Configure GitHub Pages (once live)
1. Go to https://elosofia.site (or https://ezekaj.github.io/elo-deu/)
2. Click "⚙️ Configure Server"
3. Enter:
   - API URL: `https://772ec752906e.ngrok-free.app`
   - WebSocket URL: `wss://9608f5535742.ngrok-free.app`
4. Click "Save Configuration"
5. Click "Mit Sofia sprechen" to test

## 📝 Important Notes

- Ngrok URLs change when restarted
- To keep tunnels running: `./start-all-tunnels.sh`
- To stop tunnels: `pkill -f ngrok`
- GitHub Pages may take 10-30 minutes to activate

## 🚀 Quick Commands

```bash
# Start all services
docker-compose up -d

# Start ngrok tunnels
./start-all-tunnels.sh

# Check status
docker-compose ps
curl http://localhost:4040/api/tunnels

# View logs
docker-compose logs -f
tail -f /tmp/ngrok-all.log
```

## 🔗 Direct Test Links

- Test Sofia Web: https://772ec752906e.ngrok-free.app
- Test CRM: https://3358fa3712d6.ngrok-free.app/crm/
- GitHub Alternate: https://ezekaj.github.io/elo-deu/