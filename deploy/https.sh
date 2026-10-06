#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root or with sudo.' >&2; exit 1; }
domain="${INVITATION_DOMAIN:-maazwedstoshiba.work.gd}"
[[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ && "$domain" == *.* ]] || { echo 'Invalid domain.' >&2; exit 1; }
grep -Fq "server_name $domain;" /etc/nginx/conf.d/wedding-invitation.conf || { echo 'Run deploy/install.sh successfully first.' >&2; exit 1; }
if ! command -v certbot >/dev/null; then
  apt-get update
  apt-get install -y certbot python3-certbot-nginx
elif ! certbot plugins 2>/dev/null | grep -q nginx; then
  echo 'Install the Certbot nginx plugin for your existing Certbot installation, then rerun this script.' >&2
  exit 1
fi
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then ufw allow 443/tcp comment 'HTTPS websites'; fi
# Certbot asks the operator for email and terms acceptance when needed.
certbot --nginx -d "$domain" --redirect
nginx -t
curl --fail --silent --show-error --retry 5 --retry-connrefused --retry-delay 1 "https://$domain/deployment-id.txt"
echo
echo "HTTPS enabled: https://$domain"
