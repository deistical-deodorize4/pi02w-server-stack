# Raspberry Pi Zero 2 W Docker Stack

A complete Docker stack for Raspberry Pi Zero 2 W including web server, ad blocking, DNS resolver, mesh VPN, and management tools.

## Services

- **NGINX**: Web server on port 80
- **Unbound**: Recursive DNS resolver (upstream for Pi-hole)
- **Pi-hole**: Network-wide ad blocking (uses Unbound for DNS)
- **Tailscale**: Mesh VPN
- **Portainer**: Docker container management UI
- **Watchtower**: Automatic container updates (daily at 4 AM)

## Prerequisites

### Hardware
- Raspberry Pi Zero 2 W
- MicroSD card (16 GB or larger recommended)
- Power supply and network connection (WiFi or ethernet)

### Software
- 64-bit OS installed (Debian or Raspberry Pi OS)
- SSH access to the Pi
- Git installed (`sudo apt-get update && sudo apt-get install -y git`)

### Network
- Your Pi needs a **static IP address** on your network (or a DHCP reservation from your router). You'll need this IP to access the web interfaces and configure DNS.

## Quick Start

### Step 1: Find your Pi's IP

Run this on the Pi to see its IP address:

```bash
hostname -I
```

Make a note of it — you'll use it to access Portainer, Pi-hole, and other services. If you want a static IP, configure it in your router's DHCP reservation settings.

### Step 2: Get the files

On the Pi:

```bash
git clone https://github.com/mineraleyt/pi2w-docker.git
cd pi2w-docker
```

(If not using git, copy the files to the Pi via SCP or USB.)

### Step 3: Configure environment variables

```bash
cp .env.example .env
nano .env
```

Set the following:

| Variable | Description |
|----------|-------------|
| `PIHOLE_WEBPASSWORD` | Choose a password for the Pi-hole admin panel |
| `PIHOLE_TZ` | Your timezone (e.g. `Europe/Rome`, `America/New_York`) |
| `TS_AUTH_KEY` | Your Tailscale auth key (leave blank to skip) |

**Getting a Tailscale auth key:**
1. Go to https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Make sure **Reusable** is checked if you want to reuse it
4. Copy the key and paste it as the value for `TS_AUTH_KEY`

Save and exit (`Ctrl+X`, then `Y`, then `Enter`).

### Step 4: Install Docker

```bash
chmod +x install.sh
./install.sh
```

This will:
- Update system packages
- Install Docker and Docker Compose
- Add your user to the `docker` group

**Important**: After the script finishes, **log out and log back in** (or restart SSH) so the Docker group permission takes effect. If you skip this, `docker compose` commands will fail with a permission error.

### Step 5: Start the services

```bash
docker compose up -d
```

Check everything is running:

```bash
docker compose ps
```

All services should show `Up` in the status column.

## Post-Deployment Setup

### Check Portainer (first-time setup)

Open `http://[YOUR-PI-IP]:9000` in your browser. You'll be prompted to:
1. Create an admin user (username and password)
2. Select **Docker** as the environment type
3. Connect to the local Docker socket

This is a one-time setup. After that, you can manage all containers from the Portainer UI.

### Check Pi-hole

Open `http://[YOUR-PI-IP]:8081/admin`. Login with password set in `PIHOLE_WEBPASSWORD`.

To verify Unbound is working as the upstream DNS resolver:
1. Go to **Settings > DNS**
2. Under **Upstream DNS Servers**, you should see `172.20.0.2#53` (custom)
3. Go to **Tools > Ping** and ping `google.com` — it should resolve

To view Pi-hole query statistics, check the dashboard at `http://[YOUR-PI-IP]:8081/admin`.

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

Pi-hole listens on **port 5353** (not the default port 53). To use it:

**On a single device**: Set the DNS server to `[YOUR-PI-IP]:5353` in the device's network settings.

**On your router (for whole network)**: Set the DNS server to `[YOUR-PI-IP]:5353` in the router's DHCP/DNS settings. Most routers allow custom DNS but not all support a custom port — if yours doesn't, you'll need to configure each device individually.

## RAM Usage Note

The Pi Zero 2 W has **512 MB RAM**. After the OS boots, ~200-300 MB is used, leaving ~200-300 MB for containers. If the Pi feels slow or containers crash:

- Check memory: `free -h`
- If Watchtower isn't needed, stop it: `docker compose stop watchtower`
- Consider disabling services you don't use

## Default Ports

| Service | Port | Purpose |
|---------|------|---------|
| NGINX | `80` | Web server |
| Pi-hole | `5353` | DNS (mapped from container port 53) |
| Pi-hole | `8081` | Admin web interface |
| Portainer | `9000` | Management UI |

> Pi-hole's DNS is on port 5353 instead of 53 to avoid conflicts with systemd-resolved. Pi-hole uses Unbound (172.20.0.2) as its upstream resolver for fully self-contained DNS — no Google, Cloudflare, or ISP dependency.

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PIHOLE_WEBPASSWORD` | Yes | — | Pi-hole admin password |
| `PIHOLE_TZ` | No | `Europe/Rome` | Timezone for Pi-hole |
| `TS_AUTH_KEY` | No | — | Tailscale auth key (omit to skip auto-connect) |

### Service Directories

| Directory | Contents |
|-----------|----------|
| `nginx/html` | Web files served by NGINX |
| `nginx/conf.d` | NGINX configuration files |
| `pihole/etc-pihole` | Pi-hole data (blocklists, config, gravity) |
| `pihole/etc-dnsmasq.d` | Pi-hole dnsmasq configuration |
| `tailscale` | Tailscale state (auto-created) |

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
docker compose logs -f unbound
```

Press `Ctrl+C` to stop following logs.

### Updating containers

Watchtower automatically updates all containers daily at 4 AM.

For manual updates:

```bash
docker compose pull
docker compose up -d
```

## Web Interfaces

| Interface | URL | Notes |
|-----------|-----|-------|
| NGINX | `http://[YOUR-PI-IP]` | Default web page |
| Portainer | `http://[YOUR-PI-IP]:9000` | Create admin account on first visit |
| Pi-hole | `http://[YOUR-PI-IP]:8081/admin` | Login with `PIHOLE_WEBPASSWORD` |

## Troubleshooting

### "Permission denied" when running Docker commands

You didn't log out after the install script. Run:

```bash
exec newgrp docker
```

Or just log out and back in.

### Pi-hole won't start / port 5353 in use

Check what's listening on port 5353:

```bash
sudo lsof -i :5353
```

Also check port 53 inside the container isn't conflicting with systemd-resolved:

```bash
sudo lsof -i :53
```

If systemd-resolved is using port 53 (inside the Docker bridge), you may need to disable it:

```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

### Container exits immediately / OOM

The Pi Zero 2W has 512 MB RAM. Check memory usage:

```bash
free -h
docker compose logs [service-name]
```

If a container is killed by OOM, you'll see "Killed" or exit code 137 in the logs. Try stopping unused services (e.g. `watchtower`, `nginx`) to free memory.

### Tailscale not connecting

Check the logs:

```bash
docker compose logs tailscale
```

Make sure the auth key is valid and not expired. Generate a new one at https://login.tailscale.com/admin/settings/keys.

### Pi-hole not blocking ads

1. Check Pi-hole's DNS settings: `http://[YOUR-PI-IP]:8081/admin/settings.php?tab=dns`
2. Upstream should be `172.20.0.2#53` (Unbound)
3. Check the query log: `http://[YOUR-PI-IP]:8081/admin/query_log.php`
4. Ensure your device is using `[YOUR-PI-IP]:5353` as its DNS server

## Security Considerations

1. Change all default passwords in `.env`
2. Use strong, unique passwords
3. Portainer and Pi-hole use HTTP by default — consider a reverse proxy with HTTPS
4. Keep your system updated: `sudo apt-get update && sudo apt-get upgrade`
5. Watchtower updates containers automatically — be aware that updates could break things

## Backup

Pi-hole data persists in `./pihole/etc-pihole`. To back it up:

```bash
tar -czf pihole-backup-$(date +%Y%m%d).tar.gz ./pihole
```

Tailscale state is in `./tailscale` and Portainer data is in the `portainer_data` Docker volume. To back up Portainer:

```bash
docker compose run --rm -v portainer_data:/data -v $(pwd):/backup alpine tar -czf /backup/portainer-backup.tar.gz /data
```
