#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

stop_from_pid_file() {
  local pid_file="$1"
  local label="$2"
  if [ ! -f "$pid_file" ]; then
    echo "$label not running"
    return
  fi

  local pid
  pid="$(cat "$pid_file")"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    echo "Stopped $label (PID $pid)"
  else
    echo "$label PID file exists, but process is not running"
  fi
  rm -f "$pid_file"
}

stop_from_pid_file "$LOG_DIR/monitor.pid" "monitor"
stop_from_pid_file "$LOG_DIR/grafana.pid" "grafana"
