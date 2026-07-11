# Emby Nginx Reverse Proxy

A single-file, repeatable installer for an Emby Nginx reverse proxy. It supports regular Emby deployments, split frontend/streaming origins, automatic HTTPS, existing certificates, and HTTP-only setups.

The installer validates all input, writes the configuration atomically, runs `nginx -t`, and restores the previous configuration if validation or reload fails. Automatic certificates use Certbot's Nginx plugin, so Nginx does not need to be stopped.

The pre-2.0 implementation is retained under `old/` for reference only and is no longer part of the installation flow.

## Quick start

Download the script first so it can be inspected before execution:

```bash
curl -fsSLo install.sh https://raw.githubusercontent.com/aquasofts/emby/main/install.sh
chmod +x install.sh
./install.sh
```

Non-interactive example:

```bash
./install.sh \
  --domain media.example.com \
  --upstream http://127.0.0.1:8096 \
  --tls auto \
  --email admin@example.com \
  --yes
```

Preview the generated Nginx configuration without changing the system:

```bash
./install.sh \
  --domain media.example.com \
  --upstream http://127.0.0.1:8096 \
  --tls off \
  --dry-run
```

## TLS modes

- `--tls auto`: install/use Certbot, obtain a certificate through Nginx, and configure renewal. DNS must point to the server and public ports 80/443 must be reachable.
- `--tls manual`: use an existing certificate with `--cert /path/fullchain.pem` and `--key /path/privkey.pem`.
- `--tls off`: listen on HTTP port 80 only, useful behind a CDN/load balancer or on a private network.

Automatic dependency installation explicitly supports Debian 12, Ubuntu 22.04, and newer releases. On other distributions, install Nginx and Certbot first.

## Split streaming origin

```bash
./install.sh \
  --domain media.example.com \
  --upstream https://api-origin.example.com \
  --stream-domain stream.example.com \
  --stream-upstream https://stream-origin.example.com \
  --tls auto \
  --email admin@example.com \
  --yes
```

The public stream hostname is substituted in textual responses from the main origin, while media proxying remains unbuffered. In manual TLS mode, `--stream-cert` and `--stream-key` can select a separate certificate; otherwise the main certificate is reused.

## Update and uninstall

Re-run the installer with the desired arguments to update the setup safely.

```bash
./install.sh --uninstall
```

Uninstall removes only the `emby-proxy` Nginx configuration. It does not remove Nginx, Certbot, certificates, or unrelated sites.

Run `./install.sh --help` for every option.

## Tests

```bash
bash -n install.sh tests/test.sh
bash tests/test.sh
```

The tests use dry-run mode and never touch the system Nginx installation.
