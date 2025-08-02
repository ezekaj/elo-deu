#!/bin/bash
# Complete VPS deployment commands after pulling from GitHub

echo "=== VPS Deployment Script ==="
echo "Run these commands on your VPS after git pull"
echo ""

# 1. Stop any existing containers
docker-compose down
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# 2. Use the simple config that works
docker-compose -f docker-compose.simple.yml build
docker-compose -f docker-compose.simple.yml up -d

# 3. Check if services are running
sleep 5
docker ps
echo ""
echo "Testing services..."
curl -I http://localhost:3005/health
curl -I http://localhost:7880/health

# 4. Install and configure Nginx
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

# 5. Configure Nginx for elosofia.site
cat > /etc/nginx/sites-available/elosofia.site << 'EOF'
server {
    listen 80;
    server_name elosofia.site www.elosofia.site;

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

# 6. Enable the site
ln -sf /etc/nginx/sites-available/elosofia.site /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

# 7. Get SSL certificate
certbot --nginx -d elosofia.site -d www.elosofia.site --non-interactive --agree-tos --email frankzarate77@gmail.com

echo ""
echo "=== Deployment Complete! ==="
echo "Your site should be accessible at:"
echo "- http://elosofia.site"
echo "- https://elosofia.site"