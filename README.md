# Raspberry Pi Zero 2 W Docker Stack

A complete Docker stack for Raspberry Pi Zero 2 W including web server, ad blocking, mesh VPN, and management tools.

## Services

These are the services suggested, feel free to do as you will.


- **Portainer**: Docker container management UI (healthcheck: HTTPS via `wget`)
- **NGINX**: Web server on port 80 (healthcheck: HTTP via `wget`)
- **FileBrowser**: File manager on port 8080 (healthcheck: HTTP via `wget` on `/health`)
- **Pi-hole**: Network-wide ad blocking (built-in healthcheck: DNS query via `dig`). Uses Quad9 (`9.9.9.9`) as upstream DNS
- **Tailscale**: Mesh VPN (healthcheck: HTTP via `wget` on the built-in `/healthz` endpoint)
- **Watchtower**: Automatic container updates (healthcheck: built-in `--health-check` flag)

All services include healthchecks: `docker compose ps` shows their status as `healthy` or `unhealthy`.

## Prerequisites

### Hardware
- Raspberry Pi Zero 2 W
- MicroSD card (16 GB  at least)
- Power supply and network connection (ethernet if possible)

### Software
- Raspberry Pi OS Lite (recommended)
- Git installed
```bash
sudo apt update && sudo apt install -y git
``` 

### Network
- Your Pi needs a static IP address. You'll need this IP to access the web interfaces and configure DNS.

## Quick Start

### Step 1: Find your Pi's IP

```bash
hostname -I
```


### Step 2: Get the files

On the Pi:

```bash
git clone https://github.com/deistical-deodorize4/pi02w-server-stack.git
cd pi02w-server-stack
```

### Step 3: Configure environment variables

```bash
cp .env.default .env
nano .env
```

**Getting a Tailscale auth key:**
1. Go to https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Make sure **Reusable** is checked if you want to reuse it


### Step 4: Install Docker

```bash
chmod +x install.sh
./install.sh
```

This will:
- Update system packages
- Install Docker and Docker Compose
- Add your user to the `docker` group

> **⚠️ Important**<br>
After the script finishes, **log out and log back in** (restart SSH) so the Docker group permission takes effect.


### Step 5: Start the services

```bash
docker compose up -d
```

Check everything is running:

```bash
docker compose ps
```

## Post-Deployment Setup

### Check Portainer (first-time setup)

Open `http://[YOUR-PI-IP]:9000` in your browser.
1. Create an admin user
2. Select **Docker** as the environment type
3. Connect to the local Docker socket

This is a one-time setup. After that, you can manage all containers from the Portainer UI.

### Check Pi-hole

Open `http://[YOUR-PI-IP]:8081/admin`. Login with password set in `PIHOLE_WEBPASSWORD`.

To verify Pi-hole is working:
1. Check the dashboard for query statistics
2. Go to **Tools > Ping** and ping `google.com` — it should resolve

### Configure Tailscale

If you set a `TS_AUTH_KEY`, Tailscale should already be connected. Verify:

```bash
docker compose logs tailscale
```

You should see `Connected to Tailscale`. Check the machine in your Tailscale admin console at https://login.tailscale.com/admin/machines.

If you left the key blank, authenticate manually:

```bash
docker compose exec tailscale tailscale login
```

### Configure devices to use Pi-hole for ad blocking

Pi-hole listens on **port 5354** (not the default port 53). To use it:

**On a single device**: Set the DNS server to `[YOUR-PI-IP]:5354` in the device's network settings.

**On your router (for whole network)**: Set the DNS server to `[YOUR-PI-IP]:5354` in the router's DHCP/DNS settings. Most routers allow custom DNS but not all support a custom port.


## Default Ports

| Service | Port | Purpose |
|---------|------|---------|
| NGINX | `80` | Web server |
| Pi-hole | `5354` | DNS (mapped from container port 53) |
| Pi-hole | `8081` | Admin web interface |
| Portainer | `9000` | Management UI |
| FileBrowser | `8080` | File manager |

> Pi-hole's DNS is on port 5354 instead of 53 to avoid conflicts with systemd-resolved. Pi-hole uses Quad9 (`9.9.9.9`) as its upstream DNS


## Usage

### Starting and stopping services

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Stop a single service
docker compose stop pihole

# Restart a service
docker compose restart portainer
```

### Viewing logs

```bash
# All services
docker compose logs -f

# Single service
docker compose logs -f pihole
```


### Updating containers

Watchtower automatically updates all containers daily at 4:00 AM.

For manual updates:

```bash
docker compose pull
docker compose up -d
```

## RAM Usage Note

If the Pi feels slow or containers crash:

- Check memory: `free -h`
- If Watchtower isn't needed, stop it: `docker compose stop watchtower`
- Consider disabling services you don't use

## Troubleshooting

### "Permission denied" when running Docker commands

You didn't log out after the install script. Run:

```bash
exec newgrp docker
```

Or just log out and back in.

### Wrong Pi-hole password
If the password in `.env` isn't working:
```bash
docker compose exec pihole pihole setpassword
```
Then log in at `http://[YOUR-PI-IP]:8081/admin`

### Pi-hole not blocking ads

1. Check Pi-hole's DNS settings: `http://[YOUR-PI-IP]:8081/admin/settings.php?tab=dns`
2. Upstream DNS should be Quad9 (`9.9.9.9`)
3. Check the query log: `http://[YOUR-PI-IP]:8081/admin/query_log.php`
4. Ensure your device is using `[YOUR-PI-IP]:5354` as its DNS server

## Security Considerations

1. Change all default passwords in `.env`
2. Portainer and Pi-hole use HTTP by default, consider a reverse proxy with HTTPS
3. Keep your system updated: `sudo apt-get update && sudo apt-get upgrade`
4. **Watchtower** has access to the Docker socket, giving it full control over all containers. This is normal for auto-update tools but means a compromise of the Watchtower container would compromise the whole host. Disable it if you don't need it: `docker compose stop watchtower`
5. **Watchtower** updates containers automatically, be aware that updates could break things. Pin specific image tags in `docker-compose.yml` if you need stability
6. **Tailscale** is more secure than opening ports to the internet. Your Pi is only accessible to devices in your Tailscale network

## Backup

Pi-hole data persists in `./pihole/etc-pihole`. To back it up:

```bash
tar -czf pihole-backup-$(date +%Y%m%d).tar.gz ./pihole
```

Tailscale state is in `./tailscale`, FileBrowser files are in `./files`, and Portainer data is in the `portainer_data` Docker volume. To back up Portainer:

```bash
docker compose run --rm -v portainer_data:/data -v $(pwd):/backup alpine tar -czf /backup/portainer-backup.tar.gz /data
```

## Credits

Based on [mineraleyt/pi2w-docker](https://github.com/mineraleyt/pi2w-docker).

Changes made:
- Removed **MariaDB** and **phpMyAdmin**
- Added **Tailscale** and **FileBrowser**
- Switched **NGINX** to `stable-alpine-slim` for a smaller footprint

