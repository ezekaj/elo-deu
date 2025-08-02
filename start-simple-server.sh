#!/bin/bash
# Run these commands on your VPS

# Kill the stuck docker-compose process
kill 178835

# Start a simple Python server
cd /root/elo-deu/dental-calendar/public
nohup python3 -m http.server 3005 > /dev/null 2>&1 &

# Or if you prefer Node.js
cd /root/elo-deu/dental-calendar
nohup node server.js > /dev/null 2>&1 &

# Check if it's running
sleep 2
netstat -tlnp | grep 3005