#!/bin/bash

echo "Fixing Sofia connection issue..."

# Option 1: Try to use the existing ngrok tunnel with a different approach
# We'll configure LiveKit to advertise the ngrok URL as its public address

# First, get the current ngrok URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' | sed 's/https/wss/')

if [ -z "$NGROK_URL" ]; then
    echo "❌ ngrok is not running!"
    exit 1
fi

echo "✅ Found ngrok URL: $NGROK_URL"

# Update the LiveKit configuration to use the ngrok URL
cat > /tmp/livekit-external.yaml << EOF
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: false
  # Force all connections through TCP
  enable_ice_lite: false
  force_relay: true
turn:
  enabled: true
  udp_port: 3478
  tls_port: 5349
  external_tls: false
  relay_range_start: 1024
  relay_range_end: 30000
room:
  empty_timeout: 300
  departure_timeout: 20
  max_participants: 50
webhook:
  api_key: secret
  urls:
    - "http://sofia-agent:8080/webhook"
keys:
  devkey: devsecret_that_is_at_least_32_characters_long
logging:
  level: debug
# Important: Set the WebSocket URL to use the ngrok tunnel
rtc:
  node_ip: ecd85b3c3637.ngrok-free.app
  announced_ip: ecd85b3c3637.ngrok-free.app
  bind_addresses:
    - "0.0.0.0"
EOF

echo "✅ Created LiveKit configuration with external URL"

# Option 2: Alternative approach - use environment variables
echo "Setting LiveKit environment variables..."
docker-compose exec -T livekit sh -c "export LIVEKIT_NODE_IP=ecd85b3c3637.ngrok-free.app"

echo "Done! Please restart the services:"
echo "docker-compose restart livekit"