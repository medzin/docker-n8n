#!/bin/bash
set -e

IMAGE_NAME="${1:-n8n-custom-test}"
SKIP_BUILD="${2:-false}"
CONTAINER_NAME="n8n-smoke-check"
# n8n runs DB migrations on first boot, so allow generous time to become ready.
TIMEOUT_SECONDS="${STARTUP_TIMEOUT:-120}"

if [ "$SKIP_BUILD" != "skip-build" ]; then
  echo "Building Docker image..."
  docker build -t "$IMAGE_NAME" .
else
  echo "Skipping Docker build..."
fi

# Make sure a stale container from a previous run does not block us.
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Starting container..."
docker run -d --name "$CONTAINER_NAME" "$IMAGE_NAME" >/dev/null

fail() {
  echo "$1"
  echo "----- container logs (last 40 lines) -----"
  docker logs "$CONTAINER_NAME" 2>&1 | tail -40
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  exit 1
}

echo "Waiting for n8n to become ready (up to ${TIMEOUT_SECONDS}s)..."
READY=0
for _ in $(seq 1 "$TIMEOUT_SECONDS"); do
  # Fail fast if n8n crashed on startup instead of waiting for the full timeout.
  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" != "true" ]; then
    fail "FAILURE: container exited before n8n became ready (startup crash)."
  fi
  # /healthz responds 200 once the HTTP server is up.
  if docker exec "$CONTAINER_NAME" wget -qO- http://127.0.0.1:5678/healthz >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done

if [ "$READY" -ne 1 ]; then
  fail "FAILURE: n8n did not become ready within ${TIMEOUT_SECONDS}s."
fi

echo "SUCCESS: n8n started and /healthz is responding."

# Cleanup
echo "Cleaning up..."
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "Done."
