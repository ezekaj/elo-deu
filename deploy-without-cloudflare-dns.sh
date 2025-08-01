#!/bin/bash

echo "======================================"
echo "Deploy to elosofia.site (External DNS)"
echo "======================================"
echo ""
echo "Since elosofia.site uses external DNS (not Cloudflare),"
echo "we have a few options:"
echo ""
echo "1) Use subdomain with different provider"
echo "2) Transfer domain to Cloudflare (recommended)"
echo "3) Use alternative tunneling service"
echo "4) Deploy to a VPS with public IP"
echo ""
read -p "Choose option (1-4): " choice

case $choice in
    1)
        echo ""
        echo "Option 1: Subdomain with different provider"
        echo "=========================================="
        echo ""
        echo "You can use a free subdomain service like:"
        echo "- subdomain.freedns.org"
        echo "- duckdns.org"
        echo "- no-ip.com"
        echo ""
        echo "Or use the temporary Cloudflare URLs we already have:"
        echo "- https://impacts-approximate-florist-cartridges.trycloudflare.com"
        echo ""
        ;;
        
    2)
        echo ""
        echo "Option 2: Transfer to Cloudflare"
        echo "================================"
        echo ""
        echo "1. Create a free Cloudflare account at cloudflare.com"
        echo "2. Add elosofia.site to your account"
        echo "3. Update nameservers at your registrar to:"
        echo "   - Cloudflare nameserver 1"
        echo "   - Cloudflare nameserver 2"
        echo "4. Wait for DNS propagation (5-30 minutes)"
        echo "5. Run ./quick-deploy-elosofia.sh again"
        echo ""
        echo "Benefits:"
        echo "- Free SSL certificates"
        echo "- Free tunnels"
        echo "- DDoS protection"
        echo "- Fast global CDN"
        ;;
        
    3)
        echo ""
        echo "Option 3: Alternative tunnel with current DNS"
        echo "============================================="
        
        # Install bore.pub (alternative to ngrok/cloudflare)
        echo "Installing bore.pub tunnel..."
        if [ ! -f /usr/local/bin/bore ]; then
            wget https://github.com/ekzhang/bore/releases/download/v0.5.0/bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz
            tar -xf bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz
            sudo mv bore /usr/local/bin/
            rm bore-v0.5.0-x86_64-unknown-linux-musl.tar.gz
        fi
        
        echo ""
        echo "Starting services with bore.pub..."
        
        # Start tunnels
        bore local 3005 --to bore.pub &
        BORE1=$!
        sleep 2
        
        bore local 7880 --to bore.pub &
        BORE2=$!
        sleep 2
        
        echo ""
        echo "Your temporary URLs:"
        echo "Check the output above for bore.pub URLs"
        echo ""
        echo "To stop: kill $BORE1 $BORE2"
        ;;
        
    4)
        echo ""
        echo "Option 4: VPS Deployment"
        echo "======================="
        echo ""
        echo "1. Get a VPS from:"
        echo "   - DigitalOcean ($6/month)"
        echo "   - Hetzner (€4/month)"
        echo "   - Linode ($5/month)"
        echo ""
        echo "2. Point elosofia.site DNS A record to VPS IP"
        echo ""
        echo "3. Run on VPS:"
        cat > vps-deploy.sh << 'EOF'
#!/bin/bash
# Run this on your VPS

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone repository
git clone [your-repo-url] /opt/elo-deu
cd /opt/elo-deu

# Install Caddy (auto-SSL web server)
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# Configure Caddy
cat > /etc/caddy/Caddyfile << 'CADDY'
elosofia.site, calendar.elosofia.site {
    reverse_proxy localhost:3005
}

voice.elosofia.site {
    reverse_proxy localhost:7880
}

api.elosofia.site {
    reverse_proxy localhost:3005
}

crm.elosofia.site {
    reverse_proxy localhost:5000
}
CADDY

# Start services
docker-compose up -d
sudo systemctl restart caddy
EOF
        echo ""
        echo "VPS deployment script saved to: vps-deploy.sh"
        ;;
esac

echo ""
echo "======================================"
echo "Current Status"
echo "======================================"
echo ""
echo "Your domain elosofia.site is currently using external DNS."
echo "The easiest solution is Option 2 (Transfer to Cloudflare)."
echo ""
echo "For now, you can use the temporary URLs from earlier:"
echo "- Calendar: https://impacts-approximate-florist-cartridges.trycloudflare.com"
echo "- Voice: wss://maximum-topic-malawi-ltd.trycloudflare.com"