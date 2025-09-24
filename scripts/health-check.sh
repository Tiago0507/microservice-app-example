#!/usr/bin/env bash
set -euo pipefail

# Simple health check script for local/dev CI
# Requires: curl, jq (optional), docker compose

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
err()  { echo "[ERROR] $*" >&2; }

curl_ok() {
  local url="$1"; shift || true
  local expected="${1:-200}"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 5 "$url" || echo "000")
  [[ "$code" == "$expected" ]]
}

wait_for_http() {
  local name="$1"; local url="$2"; local expected="${3:-200}"; local timeout="${4:-60}"
  local start_ts=$(date +%s)
  info "Waiting for $name at $url to return $expected (timeout ${timeout}s)"
  while true; do
    if curl_ok "$url" "$expected"; then
      info "$name is healthy"
      return 0
    fi
    local now=$(date +%s)
    if (( now - start_ts > timeout )); then
      err "$name did not become healthy in time"
      return 1
    fi
    sleep 2
  done
}

wait_for_compose_health() {
  local service="$1"; local timeout="${2:-90}"
  local start_ts=$(date +%s)
  info "Waiting for compose health: ${service} (timeout ${timeout}s)"
  while true; do
    # docker compose ps --format json is not available everywhere; use grep on HEALTHY
    if docker compose -f "$COMPOSE_FILE" ps | grep -E "${service}.*(healthy)" >/dev/null 2>&1; then
      info "${service} reports healthy"
      return 0
    fi
    local now=$(date +%s)
    if (( now - start_ts > timeout )); then
      err "${service} did not report healthy in time"
      return 1
    fi
    sleep 3
  done
}

collect_logs() {
  warn "Collecting docker compose logs..."
  docker compose -f "$COMPOSE_FILE" logs --no-color > "${ROOT_DIR}/compose-logs.txt" 2>&1 || true
  warn "Logs saved to ${ROOT_DIR}/compose-logs.txt"
}

main() {
  trap 'collect_logs; docker compose -f "$COMPOSE_FILE" down -v || true' EXIT

  info "Starting stack via docker compose"
  docker compose -f "$COMPOSE_FILE" up -d --build

  # Wait for base infra
  wait_for_http "zipkin" "http://localhost:9411/health" 200 60 || true

  # users-api has a compose healthcheck at port 8083
  wait_for_compose_health users-api 120

  # auth-api exposes /version
  wait_for_http "auth-api" "http://localhost:8000/version" 200 60

  # todos-api is JWT protected; we only check TCP/HTTP 401 to confirm it's up
  if curl_ok "http://localhost:8082/todos" 401; then
    info "todos-api responds (401 expected without token)"
  else
    err "todos-api did not respond as expected"
    return 1
  fi

  # frontend should serve index
  wait_for_http "frontend" "http://localhost:8080/" 200 60

  info "All health checks passed"
}

main "$@"


