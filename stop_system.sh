#!/usr/bin/env bash
# ============================================================
# stop_system.sh — stops the frontend (port 8001) and the
# FastAPI backend (port 8000) started by start_system.sh.
# ============================================================
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$ROOT_DIR/run"

stop_pid_file() {
    local pidfile="$1"
    local name="$2"
    if [[ -f "$pidfile" ]]; then
        local pid
        pid="$(cat "$pidfile" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "[stop] Stopping $name (pid $pid) ..."
            kill "$pid" 2>/dev/null || true
            # Give it a moment, then force kill if still alive
            for _ in $(seq 1 10); do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.3
            done
            if kill -0 "$pid" 2>/dev/null; then
                echo "[stop] $name did not exit, force killing ..."
                kill -9 "$pid" 2>/dev/null || true
            fi
            echo "[stop] $name stopped."
        else
            echo "[stop] $name is not running (stale pid file)."
        fi
        rm -f "$pidfile"
    else
        echo "[stop] No pid file for $name — nothing to do."
    fi
}

stop_pid_file "$RUN_DIR/backend.pid"  "backend (port 8000)"
stop_pid_file "$RUN_DIR/frontend.pid" "frontend (port 8001)"

# Fallback: kill anything still bound to the ports
free_port() {
    local port="$1"
    local pids
    pids="$(lsof -t -i tcp:"$port" 2>/dev/null || true)"
    if [[ -z "$pids" ]] && command -v fuser >/dev/null 2>&1; then
        fuser -k "${port}/tcp" 2>/dev/null && echo "[stop] Freed port $port." || true
        return
    fi
    if [[ -n "$pids" ]]; then
        echo "[stop] Killing leftover process(es) on port $port: $pids"
        kill $pids 2>/dev/null || true
    fi
}
free_port 8000
free_port 8001

echo "[stop] Done. System stopped."
