#!/bin/bash
# Simple VPS deployment command for Sofia
# Run this on your VPS after SSH login

# Quick deployment - just copy and paste this command on your VPS:
curl -fsSL https://raw.githubusercontent.com/ezekaj/elo-deu/master/deployment/quick-deploy.sh | sudo bash -s -- \
  --vps-ip $(curl -s https://ipinfo.io/ip) \
  --google-api-key "AIzaSyCGXSa68qIQNtp8WEH_zYFF3UjIHS4EW2M" \
  --domain "elosofia.site"