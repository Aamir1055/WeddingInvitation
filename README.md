# Maaz Khan & Taushiba Khan — Walima Invitation

A responsive floral invitation with an animated opening, Urdu and English invitation letters, a couple illustration, scratch-to-reveal date, countdown, and calendar download.

**Walima:** Monday, 16 November 2026, 8:00 AM–5:00 PM IST.  
**Venue:** Gaus Pur, Mahul, Azamgarh, Uttar Pradesh, India.  
**Host:** Muhammad Ashfaq Khan.

## Preview

Open `dist/index.html` in a browser. No build or dependencies are needed. Images and video are included; Google Fonts loads online with local font fallbacks.

## Personalization

Names, dates and venue are configured in `dist/invitation.js`. Text and fallback names are in `dist/index.html`; appearance is in `dist/style.css`. Save files as UTF-8.

## Ubuntu server deployment

The installer expects an existing, running Nginx installation. It creates a separate virtual host for **maazwedstoshiba.work.gd** on port 80 and leaves other sites untouched. DNS must point to `136.244.85.226`. If UFW is active, it permits HTTP. A different domain can be supplied through `INVITATION_DOMAIN`.

From the authenticated server terminal:

```bash
git clone https://github.com/Aamir1055/WeddingInvitation.git /root/WeddingInvitation
cd /root/WeddingInvitation
bash deploy/install.sh
```

Once the script reports success, visit `http://maazwedstoshiba.work.gd`. Then enable HTTPS:

```bash
bash deploy/https.sh
```

This installs Certbot if needed and prompts for an email address and certificate service terms acceptance. The secure URL is `https://maazwedstoshiba.work.gd`. A provider-level firewall must permit ports 80 and 443. Subsequent invitation deployments preserve the domain's HTTPS configuration.

For subsequent updates:

```bash
cd /root/WeddingInvitation
git pull --ff-only
bash deploy/install.sh
```

The installer creates versioned releases in `/var/www/wedding-invitation/releases`, switches a `current` symlink, tests that its config is actually loaded, then reloads Nginx. It retries the local domain readiness check up to 15 times and verifies the release identity before declaring success. It keeps previous releases and restores the previous config and symlink if validation, reload, or readiness fails. It never deletes other websites or changes their configuration.

## Assets

The opening video and floral backgrounds come from the user-supplied Royal Grace reference. The couple illustration was generated for this invitation; see `ARTWORK.md`. Music is a locally synthesized instrumental loop. No guest responses or personal credentials are collected.
