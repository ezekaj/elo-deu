#!/bin/bash
# Manual deployment commands for elosofia.site
# SSH to your VPS first: ssh root@167.235.67.1
# Then run these commands:

echo "=== Manual Deployment for elosofia.site ==="

# 1. Navigate to the project
cd /root/elo-deu

# 2. Make sure production.html exists
if [ -f dental-calendar/public/production.html ]; then
    echo "✓ production.html found"
else
    echo "Creating simple production.html..."
    mkdir -p dental-calendar/public
    cat > dental-calendar/public/production.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sofia Dental - Elosofia.site</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            margin: 0;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            text-align: center;
            max-width: 600px;
        }
        h1 { color: #333; }
        .status { 
            background: #4CAF50; 
            color: white; 
            padding: 10px 20px; 
            border-radius: 5px; 
            display: inline-block;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🦷 Sofia Dental</h1>
        <div class="status">✓ Sistema Activo en elosofia.site</div>
        <p>Sistema de gestión de citas dentales</p>
        <p>Próximamente: Asistente de voz integrado</p>
    </div>
</body>
</html>
EOF
fi

# 3. Start a simple HTTP server
echo "Starting web server on port 3005..."
cd dental-calendar/public
pkill -f "python3 -m http.server 3005" || true
nohup python3 -m http.server 3005 > /tmp/server.log 2>&1 &

# 4. Wait and check
sleep 2
if curl -s http://localhost:3005 > /dev/null; then
    echo "✓ Server running on port 3005"
else
    echo "✗ Server failed to start"
fi

# 5. Check nginx
echo "Checking nginx..."
nginx -t && systemctl reload nginx

echo ""
echo "=== Deployment Complete ==="
echo "Access your site at:"
echo "- http://167.235.67.1"
echo "- http://elosofia.site (when DNS propagates)"
echo ""
echo "To check logs: tail -f /tmp/server.log"