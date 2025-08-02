#!/bin/bash
# Nginx and SSL setup for elosofia.site

echo "=== Setting up Nginx for elosofia.site ==="

# 1. Install Nginx and Certbot
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

# 2. Create Nginx configuration
cat > /etc/nginx/sites-available/elosofia.site << 'EOF'
server {
    listen 80;
    server_name elosofia.site www.elosofia.site;

    # Main application
    location / {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://localhost:3005;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket for LiveKit
    location /ws {
        proxy_pass http://localhost:7880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# 3. Enable the site
ln -sf /etc/nginx/sites-available/elosofia.site /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 4. Test Nginx configuration
nginx -t

# 5. Restart Nginx
systemctl restart nginx

# 6. Configure firewall
ufw allow 'Nginx Full'
ufw allow 22/tcp
ufw --force enable

echo ""
echo "=== Nginx configured! ==="
echo ""
echo "Your site is now accessible at:"
echo "- http://elosofia.site"
echo ""
echo "To enable HTTPS, run:"
echo "certbot --nginx -d elosofia.site -d www.elosofia.site --non-interactive --agree-tos --email frankzarate77@gmail.com"
echo ""
echo "Or run it interactively:"
echo "certbot --nginx -d elosofia.site -d www.elosofia.site"