#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run as root or with sudo.' >&2; exit 1; }
domain="${INVITATION_DOMAIN:-maazwedstoshiba.work.gd}"
[[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ && "$domain" == *.* ]] || { echo 'Invalid domain.' >&2; exit 1; }
config='/etc/nginx/conf.d/wedding-invitation.conf'
base='/var/www/wedding-invitation'
marker='# Managed by WeddingInvitation deploy/install.sh'
grep -Fxq "$marker" "$config" && grep -Fq "server_name $domain;" "$config" || { echo 'Run deploy/install.sh successfully first.' >&2; exit 1; }
test -f "$base/current/deployment-id.txt" || { echo 'Wedding release is missing.' >&2; exit 1; }
if ! command -v certbot >/dev/null; then
  echo 'Certbot is not installed. Install only certbot, then rerun this script. No Nginx packages or plugins are needed.' >&2
  exit 1
fi
# Webroot validation does not edit Nginx or select any other application's site.
# Certbot prompts the operator for email and terms acceptance if needed.
certbot certonly --webroot -w "$base/current" --cert-name "$domain" -d "$domain"
test -s "/etc/letsencrypt/live/$domain/fullchain.pem"
test -s "/etc/letsencrypt/live/$domain/privkey.pem"
backup="$base/backups/https-$(date -u +%Y%m%dT%H%M%SZ)-$$.conf"
cp -p "$config" "$backup"
rollback() {
  cp -p "$backup" "$config"
  nginx -t && systemctl reload nginx || true
  echo 'HTTPS setup failed; only the wedding configuration was restored.' >&2
}
trap rollback ERR
cat > "$config" <<EOF
$marker
server {
    listen 80;
    server_name $domain;
    root $base/current;
    location /.well-known/acme-challenge/ { try_files \$uri =404; }
    location / { return 301 https://$domain\$request_uri; }
}
server {
    listen 443 ssl;
    server_name $domain;
    root $base/current;
    index index.html;
    charset utf-8;
    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    add_header X-Content-Type-Options nosniff always;
    location / { try_files \$uri \$uri/ =404; }
}
EOF
nginx -t
systemctl reload nginx
ready=false
for attempt in {1..15}; do
  response="$(curl --noproxy '*' --fail --silent --show-error --connect-timeout 2 --max-time 5 --resolve "$domain:443:127.0.0.1" "https://$domain/deployment-id.txt" 2>/dev/null || true)"
  if [[ "$response" == "$(cat "$base/current/deployment-id.txt")" ]]; then ready=true; break; fi
  sleep 1
done
[[ "$ready" == true ]] || { echo 'HTTPS certificate or release validation failed.' >&2; false; }
trap - ERR
install -d -m 755 /etc/letsencrypt/renewal-hooks/deploy
hook='/etc/letsencrypt/renewal-hooks/deploy/wedding-invitation-reload.sh'
if [[ -e "$hook" ]] && ! grep -Fq '# WeddingInvitation certificate reload' "$hook"; then
  echo 'Existing renewal hook left unchanged; arrange Nginx reload after renewal.' >&2
else
  cat > "$hook" <<EOF
#!/bin/sh
# WeddingInvitation certificate reload
case " \$RENEWED_DOMAINS " in
  *" $domain "*) nginx -t && systemctl reload nginx ;;
esac
EOF
  chmod 755 "$hook"
fi
echo "HTTPS enabled: https://$domain"
