#!/bin/bash
# Nginx and SSL setup for elosofia.site
# Run this AFTER Docker containers are running

echo "=== STEP 1: Install Nginx ==="
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

echo "=== STEP 2: Create Nginx configuration ==="
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

    # Health check endpoints
    location /health {
        proxy_pass http://localhost:3005/health;
    }
}
EOF

echo "=== STEP 3: Enable the site ==="
ln -sf /etc/nginx/sites-available/elosofia.site /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "=== STEP 4: Test and reload Nginx ==="
nginx -t
systemctl restart nginx

echo "=== STEP 5: Configure firewall ==="
ufw allow 'Nginx Full'
ufw allow 22/tcp
ufw allow 7880/tcp
ufw allow 3005/tcp
ufw --force enable

echo "=== STEP 6: Get SSL certificate ==="
certbot --nginx -d elosofia.site -d www.elosofia.site --non-interactive --agree-tos --email frankzarate77@gmail.com

echo ""
echo "=== Nginx and SSL setup complete! ==="
echo "Your site should now be accessible at:"
echo "- http://elosofia.site"
echo "- https://elosofia.site"