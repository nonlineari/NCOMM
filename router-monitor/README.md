# NCOMM Router Monitor
Everything for this stack lives under `router-monitor/`.

## What it does
- Scans `10.0.10.0/24` with `nmap`
- Compares observed MAC addresses against the trusted list in `monitor_config.json`
- Logs unknown devices as intruder alerts
- Stores scan history in SQLite
- Serves a local JSON API for Grafana
- Opens a local Grafana dashboard with current devices, intruders, alerts, and device history

## Files
- `ncomm_monitor.py` — scanner + SQLite + local API
- `monitor_config.json` — network and whitelist config
- `grafana/` — datasource provisioning, dashboard provisioning, and dashboard JSON
- `start_router_monitor_stack.sh` — starts monitor + Grafana
- `stop_router_monitor_stack.sh` — stops both processes

## Deployment Process

### 1. Install runtime dependencies

macOS (Homebrew):

```bash
brew install nmap grafana
grafana cli --homepath /opt/homebrew/opt/grafana/share/grafana --pluginsDir /opt/homebrew/var/lib/grafana/plugins plugins install yesoreyeram-infinity-datasource
```

Linux / WSL:

```bash
sudo apt-get update
sudo apt-get install -y nmap grafana
grafana cli plugins install yesoreyeram-infinity-datasource
```

If your Linux install uses the legacy CLI binary instead:

```bash
grafana-cli plugins install yesoreyeram-infinity-datasource
```

### 2. Review the monitor configuration

Edit `monitor_config.json` and confirm:
- `network.subnet` matches the network you want to scan
- `network.gateway` matches the router IP
- `known_devices` contains only trusted MAC addresses
- `scan.interval_seconds` is appropriate for how often you want the monitor to sweep

### 3. Launch the stack

```bash
./router-monitor/start_router_monitor_stack.sh
```

This starts:
- the Python monitor + local JSON API on `127.0.0.1:8199`
- Grafana on `127.0.0.1:3000`

### 4. Verify deployment

Check the dashboard:

`http://127.0.0.1:3000/d/ncomm-router-security/ncomm-router-security-monitor`

Check the APIs:

```bash
curl http://127.0.0.1:8199/health
curl http://127.0.0.1:8199/api/summary
curl http://127.0.0.1:3000/api/health
```

Check logs:
- `logs/monitor.stdout.log`
- `logs/grafana.stdout.log`

### 5. Operate the monitor

- Unknown devices appear in the `Intruders Seen` and `Alert Feed` panels
- `Current Devices` shows devices from the latest completed scan
- `Known vs Unknown Devices Over Time` charts scan history

If you are not on the monitored subnet, the system can still be healthy while returning `0` hosts.

### 6. Stop the deployment

```bash
./router-monitor/stop_router_monitor_stack.sh
```

## Start
```bash
./router-monitor/start_router_monitor_stack.sh
```

## Stop
```bash
./router-monitor/stop_router_monitor_stack.sh
```

## Dashboard
The launcher prints the local URL. By default:

`http://127.0.0.1:3000/d/ncomm-router-security/ncomm-router-security-monitor`

Grafana is bound to `127.0.0.1` only and anonymous view mode is enabled for the local dashboard.

## Notes
- The monitor API listens on `127.0.0.1:8199` through the launcher.
- If you are not running as root, the monitor automatically drops `nmap -O` and still continues scanning.
- Current trusted MAC addresses are set in `monitor_config.json`.

## Linux and WSL
The launcher auto-detects common Grafana layouts on:
- macOS Homebrew
- Linux package installs
- WSL Linux distros

### Expected Linux paths
- Grafana home: `/usr/share/grafana`
- Grafana config: `/etc/grafana/grafana.ini`
- Grafana plugins: `/var/lib/grafana/plugins`

### Expected macOS Homebrew paths
- Grafana home: `/opt/homebrew/opt/grafana/share/grafana`
- Grafana config: `/opt/homebrew/etc/grafana/grafana.ini`
- Grafana plugins: `/opt/homebrew/var/lib/grafana/plugins`

### WSL notes
- Run the stack inside your WSL distro.
- Open the dashboard from Windows at either:
  - `http://localhost:3000`
  - `http://wsl.localhost:3000`
- Install Linux packages inside WSL, not on the Windows side.

### Dependencies on Linux / WSL
Install these in the Linux environment:

```bash
sudo apt-get update
sudo apt-get install -y nmap grafana
```

Install the Infinity datasource plugin if it is missing:

```bash
grafana cli plugins install yesoreyeram-infinity-datasource
```

or, on some Linux installs:

```bash
grafana-cli plugins install yesoreyeram-infinity-datasource
```

### Path overrides
If Grafana is installed somewhere non-standard, set these before launching:

```bash
GRAFANA_SERVER_CMD="grafana server" \
GRAFANA_HOME="/custom/grafana/home" \
GRAFANA_CONFIG="/custom/grafana/grafana.ini" \
GRAFANA_PLUGINS="/custom/grafana/plugins" \
./router-monitor/start_router_monitor_stack.sh
```
