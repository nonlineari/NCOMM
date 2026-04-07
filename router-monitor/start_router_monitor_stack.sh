#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
GRAFANA_DIR="$SCRIPT_DIR/grafana"
MONITOR_PID_FILE="$LOG_DIR/monitor.pid"
GRAFANA_PID_FILE="$LOG_DIR/grafana.pid"

MONITOR_PORT="${MONITOR_PORT:-8199}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
DASHBOARD_PATH="$GRAFANA_DIR/dashboards/ncomm-router-security.json"

mkdir -p "$LOG_DIR" "$GRAFANA_DIR/data" "$GRAFANA_DIR/logs"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

find_first_existing_dir() {
  local path
  for path in "$@"; do
    [ -n "$path" ] || continue
    if [ -d "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  return 1
}

find_first_existing_file() {
  local path
  for path in "$@"; do
    [ -n "$path" ] || continue
    if [ -f "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  return 1
}

resolve_grafana_server_cmd() {
  if [ -n "${GRAFANA_SERVER_CMD:-}" ]; then
    read -r -a GRAFANA_SERVER_CMD_ARR <<<"${GRAFANA_SERVER_CMD}"
    return 0
  fi

  if command -v grafana >/dev/null 2>&1; then
    GRAFANA_SERVER_CMD_ARR=(grafana server)
    return 0
  fi

  if command -v grafana-server >/dev/null 2>&1; then
    GRAFANA_SERVER_CMD_ARR=(grafana-server)
    return 0
  fi

  echo "Could not find a Grafana server binary. Expected 'grafana' or 'grafana-server'." >&2
  exit 1
}

resolve_grafana_paths() {
  GRAFANA_HOME_DIR="$(find_first_existing_dir \
    "${GRAFANA_HOME:-}" \
    "/opt/homebrew/opt/grafana/share/grafana" \
    "/usr/share/grafana" \
    "/usr/local/share/grafana")" || {
      echo "Could not find Grafana home path. Set GRAFANA_HOME." >&2
      exit 1
    }

  GRAFANA_CONFIG_FILE="$(find_first_existing_file \
    "${GRAFANA_CONFIG:-}" \
    "/opt/homebrew/etc/grafana/grafana.ini" \
    "/etc/grafana/grafana.ini" \
    "/usr/local/etc/grafana/grafana.ini")" || {
      echo "Could not find grafana.ini. Set GRAFANA_CONFIG." >&2
      exit 1
    }

  GRAFANA_PLUGINS_DIR="$(find_first_existing_dir \
    "${GRAFANA_PLUGINS:-}" \
    "/opt/homebrew/var/lib/grafana/plugins" \
    "/var/lib/grafana/plugins" \
    "/usr/local/var/lib/grafana/plugins")" || {
      echo "Could not find Grafana plugins dir. Set GRAFANA_PLUGINS." >&2
      exit 1
    }
}

ensure_infinity_plugin() {
  if [ -d "$GRAFANA_PLUGINS_DIR/yesoreyeram-infinity-datasource" ]; then
    return 0
  fi

  echo "Missing Grafana Infinity plugin: $GRAFANA_PLUGINS_DIR/yesoreyeram-infinity-datasource" >&2
  echo "Install it, then rerun the launcher." >&2
  echo "Common commands:" >&2
  echo "  grafana cli --homepath \"$GRAFANA_HOME_DIR\" --pluginsDir \"$GRAFANA_PLUGINS_DIR\" plugins install yesoreyeram-infinity-datasource" >&2
  echo "  grafana-cli plugins install yesoreyeram-infinity-datasource" >&2
  exit 1
}

wait_for_http() {
  local url="$1"
  local label="$2"
  for _ in {1..45}; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$label ready: $url"
      return 0
    fi
    sleep 1
  done
  echo "$label failed to come up: $url" >&2
  return 1
}

start_monitor() {
  if [ -f "$MONITOR_PID_FILE" ] && kill -0 "$(cat "$MONITOR_PID_FILE")" 2>/dev/null; then
    echo "Monitor already running with PID $(cat "$MONITOR_PID_FILE")"
    return
  fi

  nohup python3 "$SCRIPT_DIR/ncomm_monitor.py" --port "$MONITOR_PORT" > "$LOG_DIR/monitor.stdout.log" 2>&1 &
  echo $! > "$MONITOR_PID_FILE"
  wait_for_http "http://127.0.0.1:${MONITOR_PORT}/health" "Monitor API"
}

start_grafana() {
  if [ -f "$GRAFANA_PID_FILE" ] && kill -0 "$(cat "$GRAFANA_PID_FILE")" 2>/dev/null; then
    echo "Grafana already running with PID $(cat "$GRAFANA_PID_FILE")"
    return
  fi

  nohup env \
    GF_PATHS_PROVISIONING="$GRAFANA_DIR/provisioning" \
    GF_PATHS_DATA="$GRAFANA_DIR/data" \
    GF_PATHS_LOGS="$GRAFANA_DIR/logs" \
    GF_PATHS_PLUGINS="$GRAFANA_PLUGINS_DIR" \
    GF_SERVER_HTTP_ADDR="127.0.0.1" \
    GF_SERVER_HTTP_PORT="$GRAFANA_PORT" \
    GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH="$DASHBOARD_PATH" \
    GF_AUTH_ANONYMOUS_ENABLED="true" \
    GF_AUTH_ANONYMOUS_ORG_ROLE="Viewer" \
    GF_AUTH_DISABLE_LOGIN_FORM="true" \
    "${GRAFANA_SERVER_CMD_ARR[@]}" --homepath "$GRAFANA_HOME_DIR" --config "$GRAFANA_CONFIG_FILE" > "$LOG_DIR/grafana.stdout.log" 2>&1 &
  echo $! > "$GRAFANA_PID_FILE"
  wait_for_http "http://127.0.0.1:${GRAFANA_PORT}/api/health" "Grafana"
}

require_cmd python3
require_cmd nmap
require_cmd curl
resolve_grafana_server_cmd
resolve_grafana_paths
ensure_infinity_plugin

echo "Using Grafana home: $GRAFANA_HOME_DIR"
echo "Using Grafana config: $GRAFANA_CONFIG_FILE"
echo "Using Grafana plugins: $GRAFANA_PLUGINS_DIR"

start_monitor
start_grafana

echo
echo "Dashboard:"
echo "  http://127.0.0.1:${GRAFANA_PORT}/d/ncomm-router-security/ncomm-router-security-monitor"
if is_wsl; then
  echo "  http://wsl.localhost:${GRAFANA_PORT}/d/ncomm-router-security/ncomm-router-security-monitor"
fi
echo
echo "Logs:"
echo "  $LOG_DIR/monitor.stdout.log"
echo "  $LOG_DIR/grafana.stdout.log"
