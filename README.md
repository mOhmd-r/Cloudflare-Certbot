# Certbot with Cloudflare DNS

Issue and automatically renew Let's Encrypt certificates with the official
`certbot-dns-cloudflare` plugin on Ubuntu or Debian.

## Security and operational model

- Uses a restricted Cloudflare API Token, never a Global API Key.
- Never accepts the token as a command-line argument or visible prompt.
- Stores credentials at `/etc/letsencrypt/cloudflare/credentials.ini` with
  owner `root:root` and mode `0600`.
- Rejects symlinked or group/world-readable credential sources.
- Uses the distro-managed `/usr/bin/certbot` and matching plugin, avoiding an
  isolated virtualenv that the system renewal timer cannot reproduce.
- Lets the official plugin discover Cloudflare zones; no fragile root-domain
  parsing is performed.
- Uses explicit domain arguments and validates DNS syntax before invoking
  Certbot.

Cloudflare recommends a token with `Zone:DNS:Edit` for only the zones that need
certificates. Anyone who can read the token or cause Certbot to use it can
complete DNS challenges for those zones, so keep its scope minimal.

## Requirements

- Ubuntu 24.04 LTS or a compatible Debian/Ubuntu release
- root access
- `certbot` and `python3-certbot-dns-cloudflare` from the same apt environment

The script can install the signed distribution packages:

```bash
sudo ./certbot-cloudflare.sh \
  --install-dependencies \
  --email sre@example.com \
  -d example.com \
  -d '*.example.com'
```

Alternatively install them yourself:

```bash
sudo apt-get update
sudo apt-get install --yes --no-install-recommends \
  ca-certificates certbot python3-certbot-dns-cloudflare
```

Do not mix apt, snap, and pip Certbot installations. This project intentionally
uses `/usr/bin/certbot` so issuance and the distro renewal timer run the same
executable and plugin set.

## Cloudflare token

Create an API Token in Cloudflare with:

```text
Permission: Zone / DNS / Edit
Resources:  Include / Specific zone / <required-zone>
```

On first use, the script prompts for the token without terminal echo. You can
instead create a protected file:

```bash
sudo install -o root -g root -m 0600 /dev/null /root/cloudflare.ini
sudoedit /root/cloudflare.ini
```

Contents:

```ini
dns_cloudflare_api_token = replace-with-restricted-token
```

Import it:

```bash
sudo ./certbot-cloudflare.sh \
  --email sre@example.com \
  --credentials-file /root/cloudflare.ini \
  -d app.example.co.uk
```

The source file must be root-owned and inaccessible to group and others. The
script normalizes the installed copy to one token setting and mode `0600`.

## Wildcard certificate

Quote wildcard identifiers so the shell cannot expand them:

```bash
sudo ./certbot-cloudflare.sh \
  --email sre@example.com \
  -d example.com \
  -d '*.example.com'
```

The default propagation wait is 60 seconds. Override it when required:

```bash
sudo ./certbot-cloudflare.sh \
  --email sre@example.com \
  --propagation-seconds 120 \
  -d example.com
```

## Renewal

Certbot records the absolute credentials path in the renewal configuration.
Test the complete renewal path immediately after issuance:

```bash
sudo /usr/bin/certbot renew --dry-run
```

Confirm the distro timer:

```bash
systemctl list-timers --all | grep certbot
systemctl status certbot.timer
```

Do not delete `/etc/letsencrypt/cloudflare/credentials.ini` while certificates
depend on it.

## Staging

Use Let's Encrypt staging during repeated tests:

```bash
sudo ./certbot-cloudflare.sh \
  --staging \
  --email sre@example.com \
  -d example.com
```

Staging certificates are not trusted by browsers.

## Development

```bash
bash -n certbot-cloudflare.sh tests/run.sh
shellcheck -x certbot-cloudflare.sh tests/run.sh
bash tests/run.sh
```

## License

MIT. See [LICENSE](LICENSE).
