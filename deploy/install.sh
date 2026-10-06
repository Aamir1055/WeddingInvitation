#!/usr/bin/env bash
set -Eeuo pipefail

[[ $EUID -eq 0 ]] || { echo 'Run this installer as root or with sudo.' >&2; exit 1; }
port="${INVITATION_PORT:-8088}"
[[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1024 && port <= 65535)) || { echo 'Use a port from 1024 to 65535.' >&2; exit 1; }
for tool in nginx systemctl curl ss; do command -v "$tool" >/dev/null || { echo "Required command missing: $tool. No server changes made." >&2; exit 1; }; done
systemctl is-active --quiet nginx || { echo 'Nginx must already be running. No server changes made.' >&2; exit 1; }
nginx -t
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test -f "$source_dir/dist/index.html" && test -f "$source_dir/dist/invitation.js" || { echo 'Invitation files missing.' >&2; exit 1; }
base='/var/www/wedding-invitation'
config='/etc/nginx/conf.d/wedding-invitation.conf'
marker='# Managed by WeddingInvitation deploy/install.sh'
if [[ -e "$config" ]] && ! grep -Fxq "$marker" "$config"; then echo 'A different Nginx config already uses the destination filename. Stopping.' >&2; exit 1; fi
if ss -ltnH "sport = :$port" | grep -q .; then
  if [[ ! -f "$config" ]] || ! grep -Fq "listen $port;" "$config"; then echo "Port $port is already in use. Set INVITATION_PORT to a free port." >&2; exit 1; fi
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
cat > "$config" <<EOF
$marker
server {
    listen $port;
    server_name _;
    root $base/current;
    index index.html;
    charset utf-8;
    add_header X-Content-Type-Options nosniff always;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
nginx -t
systemctl reload nginx
curl --fail --silent --show-error "http://127.0.0.1:$port/" -o /dev/null
trap - ERR
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
  ufw allow "$port/tcp" comment 'Wedding invitation'
fi
echo "Invitation deployed successfully on port $port."
echo "Server URL: http://136.244.85.226:$port"
echo "Release: $release"
