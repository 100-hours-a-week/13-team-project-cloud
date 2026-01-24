# Web Server Scripts

## HTTPS Setup (one-shot)

```bash
sudo CERTBOT_EMAIL=admin@moyeobab.com infra/scripts/ws/setup-https.sh
```

Custom domains:

```bash
sudo CERTBOT_EMAIL=admin@moyeobab.com infra/scripts/ws/setup-https.sh moyeobab.com api.moyeobab.com
```

Options:

- `CERTBOT_EMAIL`: email for Let's Encrypt registration (recommended)
- `CERTBOT_NO_EMAIL=1`: register without email (not recommended)
- `REDIRECT=1`: enable HTTP -> HTTPS redirect
- `STAGING=1`: use Let's Encrypt staging
