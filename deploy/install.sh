#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo 'Run this installer as root or with sudo.' >&2; exit 1; }
domain="${INVITATION_DOMAIN:-maazwedstoshiba.work.gd}"
[[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ && "$domain" == *.* ]] || { echo 'Invalid domain name.' >&2; exit 1; }
port=80
for tool in nginx systemctl curl ss; do command -v "$tool" >/dev/null || { echo "Required command missing: $tool. No server changes made." >&2; exit 1; }; done
systemctl is-active --quiet nginx || { echo 'Nginx must already be running. No server changes made.' >&2; exit 1; }
nginx -t
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test -f "$source_dir/dist/index.html" && test -f "$source_dir/dist/invitation.js" || { echo 'Invitation files missing.' >&2; exit 1; }
base='/var/www/wedding-invitation'
config='/etc/nginx/conf.d/wedding-invitation.conf'
marker='# Managed by WeddingInvitation deploy/install.sh'
if [[ -e "$config" ]] && ! grep -Fxq "$marker" "$config"; then echo 'A different Nginx config already uses the destination filename. Stopping.' >&2; exit 1; fi
loaded_config="$(nginx -T 2>&1)"
if [[ ! -f "$config" ]] && grep -Eq "server_name[[:space:]][^;]*${domain//./\\.}([[:space:];]|$)" <<< "$loaded_config"; then
  echo "An existing Nginx site already handles $domain. Stopping to preserve it." >&2; exit 1
fi
if [[ -e "$base" || -L "$base" ]]; then
  [[ ! -L "$base" && -d "$base" && -f "$base/.invitation-managed" ]] || { echo 'Deployment directory exists but is not managed by this installer. Stopping.' >&2; exit 1; }
fi
if [[ -e "$base/current" && ! -L "$base/current" ]]; then echo 'current is not a symlink. Stopping.' >&2; exit 1; fi
release="$base/releases/$(date -u +%Y%m%dT%H%M%SZ)-$$"
install -d -m 755 "$release" "$base/backups"
touch "$base/.invitation-managed"
cp -R "$source_dir/dist/." "$release/"
find "$release" -type d -exec chmod 755 {} +
find "$release" -type f -exec chmod 644 {} +
release_id="$(basename "$release")"
printf '%s\n' "$release_id" > "$release/deployment-id.txt"
chmod 644 "$release/deployment-id.txt"
old_target="$(readlink "$base/current" || true)"
backup="$base/backups/nginx-$(date -u +%Y%m%dT%H%M%SZ)-$$.conf"
had_config=false
if [[ -f "$config" ]]; then cp -p "$config" "$backup"; had_config=true; fi
rollback() {
  if [[ "$had_config" == true ]]; then cp -p "$backup" "$config"; else rm -f -- "$config"; fi
  if [[ -n "$old_target" ]]; then ln -s "$old_target" "$base/rollback-$$"; mv -Tf "$base/rollback-$$" "$base/current"; else rm -f -- "$base/current"; fi
  nginx -t && systemctl reload nginx || true
  echo 'Deployment failed; previous configuration restored.' >&2
}
trap rollback ERR
ln -s "$release" "$base/current-$$"
mv -Tf "$base/current-$$" "$base/current"
if [[ -f "$config" ]] && grep -Fq "server_name $domain;" "$config"; then
  echo 'Keeping existing domain configuration, including any HTTPS certificates.'
else
cat > "$config" <<EOF
$marker
server {
    listen $port;
    server_name $domain;
    root $base/current;
    index index.html;
    charset utf-8;
    add_header X-Content-Type-Options nosniff always;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
fi
nginx -t
loaded_config="$(nginx -T 2>&1)"
if ! grep -Fq "# configuration file $config:" <<< "$loaded_config"; then
  echo "Nginx is not including $config. Check the include directives in /etc/nginx/nginx.conf." >&2
  false
fi
systemctl reload nginx
ready=false
for attempt in {1..15}; do
  # A successful reload can return before the new workers start listening.
  # Check the new release identity, not merely an unrelated default site's 200.
  response="$(curl --noproxy '*' --fail --silent --show-error --connect-timeout 2 --max-time 5 --location --resolve "$domain:80:127.0.0.1" --resolve "$domain:443:127.0.0.1" "http://$domain/deployment-id.txt" 2>/dev/null || true)"
  if [[ "$response" == "$release_id" ]]; then ready=true; break; fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  echo 'The new invitation did not become reachable after 15 attempts.' >&2
  ss -ltnH 'sport = :80' >&2
  journalctl -u nginx -n 12 --no-pager >&2 || true
  false
fi
trap - ERR
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
  ufw allow 80/tcp comment 'HTTP websites'
fi
echo "Invitation deployed successfully for $domain."
echo "Server URL: http://$domain"
echo "Release: $release"
