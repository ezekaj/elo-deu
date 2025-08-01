#!/bin/bash
# Environment setup script for Sofia deployment

cat << 'EOF'
# Sofia Dental Calendar - Environment Setup

Please set the following environment variables before running the deployment:

export VPS_IP="YOUR_VPS_IP_ADDRESS"
export DOMAIN_NAME="elosofia.site"

# Database passwords (generate strong passwords)
export POSTGRES_PASSWORD="$(openssl rand -base64 32)"
export REDIS_PASSWORD="$(openssl rand -base64 32)"

# Security tokens
export JWT_SECRET="$(openssl rand -base64 64)"

# LiveKit credentials (get from https://cloud.livekit.io)
export LIVEKIT_API_KEY="your_livekit_api_key"
export LIVEKIT_API_SECRET="your_livekit_api_secret"
export LIVEKIT_WEBHOOK_KEY="$(openssl rand -base64 32)"

# AI service keys
export OPENAI_API_KEY="your_openai_api_key"
export DEEPGRAM_API_KEY="your_deepgram_api_key"

# TURN server credentials
export TURN_USERNAME="sofia"
export TURN_PASSWORD="$(openssl rand -base64 32)"

# GitHub deploy token (with repo access)
export GITHUB_TOKEN="your_github_personal_access_token"

# To generate random passwords automatically:
# source <(curl -s https://raw.githubusercontent.com/elodisney/sofia-deploy/main/generate-passwords.sh)

# Save these values securely!
EOF

# Optionally generate passwords
if [[ "$1" == "--generate" ]]; then
    echo -e "\n# Auto-generated values:"
    echo "export POSTGRES_PASSWORD=\"$(openssl rand -base64 32)\""
    echo "export REDIS_PASSWORD=\"$(openssl rand -base64 32)\""
    echo "export JWT_SECRET=\"$(openssl rand -base64 64)\""
    echo "export LIVEKIT_WEBHOOK_KEY=\"$(openssl rand -base64 32)\""
    echo "export TURN_PASSWORD=\"$(openssl rand -base64 32)\""
fi