#!/usr/bin/env bash
# ============================================================
# start_system.sh — starts the whole stack:
#   1. FastAPI backend  -> http://localhost:8000
#   2. Frontend (proxy_server.py, serves static files and
#      proxies /api/* to the backend) -> http://localhost:8001
#
# Works on Ubuntu. Logs are written to ./run/, PID files as well.
# Stop everything with ./stop_system.sh
# ============================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_DIR="$ROOT_DIR/run"
mkdir -p "$RUN_DIR"

BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKEND_LOG="$RUN_DIR/backend.log"
FRONTEND_LOG="$RUN_DIR/frontend.log"
BACKEND_PID="$RUN_DIR/backend.pid"
FRONTEND_PID="$RUN_DIR/frontend.pid"

BACKEND_PORT=8000
FRONTEND_PORT=8001

# Find a usable python3 + pip
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is not installed. Install it with: sudo apt install python3 python3-pip" >&2
    exit 1
fi

# ------------------------------------------------------------
# Sanity checks: ports must be free
# ------------------------------------------------------------
check_port() {
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]$1$"; then
        echo "ERROR: port $1 is already in use. Run ./stop_system.sh first or free the port." >&2
        exit 1
    fi
}
check_port "$BACKEND_PORT"
check_port "$FRONTEND_PORT"

# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------
install_deps() {
    # Skip installation if every required package is already importable
    if python3 -c "import fastapi, uvicorn, pwdlib, mysql.connector, email_validator" >/dev/null 2>&1; then
        echo "[deps] All required Python packages already available."
        return
    fi

    echo "[deps] Installing Python dependencies from requirements.txt ..."
    if python3 -m pip --version >/dev/null 2>&1; then
        PIP_CMD=(python3 -m pip)
    elif command -v pip3 >/dev/null 2>&1; then
        PIP_CMD=(pip3)
    elif command -v uv >/dev/null 2>&1; then
        echo "[deps] Using 'uv' ..."
        uv pip install -r "$ROOT_DIR/requirements.txt" && return
    else
        echo "[deps] No pip/uv found and packages are missing." >&2
        echo "[deps] Install them with:  sudo apt install python3-pip && pip3 install -r requirements.txt" >&2
        exit 1
    fi
    "${PIP_CMD[@]}" install -r "$ROOT_DIR/requirements.txt"
}
install_deps

# ------------------------------------------------------------
# Start the FastAPI backend (port 8000)
# ------------------------------------------------------------
echo "[backend] Starting FastAPI backend on port $BACKEND_PORT ..."
(
    cd "$BACKEND_DIR"
    exec python3 -m uvicorn main:app --host 127.0.0.1 --port "$BACKEND_PORT"
) >"$BACKEND_LOG" 2>&1 &
BACKEND_PID_VAL=$!
echo "$BACKEND_PID_VAL" > "$BACKEND_PID"

# Wait until the backend actually answers
for _ in $(seq 1 30); do
    if curl -s -o /dev/null "http://127.0.0.1:$BACKEND_PORT/docs" 2>/dev/null; then
        echo "[backend] Ready: http://localhost:$BACKEND_PORT  (Swagger UI at /docs)"
        break
    fi
    if ! kill -0 "$BACKEND_PID_VAL" 2>/dev/null; then
        echo "[backend] FAILED to start. Last log lines:" >&2
        tail -n 20 "$BACKEND_LOG" >&2
        exit 1
    fi
    sleep 0.5
done

# ------------------------------------------------------------
# Start the frontend (proxy server, port 8001)
# ------------------------------------------------------------
echo "[frontend] Starting frontend on port $FRONTEND_PORT ..."
(
    cd "$FRONTEND_DIR"
    exec python3 proxy_server.py
) >"$FRONTEND_LOG" 2>&1 &
FRONTEND_PID_VAL=$!
echo "$FRONTEND_PID_VAL" > "$FRONTEND_PID"

sleep 1
if ! kill -0 "$FRONTEND_PID_VAL" 2>/dev/null; then
    echo "[frontend] FAILED to start. Last log lines:" >&2
    tail -n 20 "$FRONTEND_LOG" >&2
    "$ROOT_DIR/stop_system.sh" || true
    exit 1
fi

echo "[frontend] Ready: http://localhost:$FRONTEND_PORT"
echo
echo "System is running."
echo "  Frontend : http://localhost:$FRONTEND_PORT"
echo "  Backend  : http://localhost:$BACKEND_PORT"
echo "  Logs     : $BACKEND_LOG , $FRONTEND_LOG"
echo "  Stop     : ./stop_system.sh"
