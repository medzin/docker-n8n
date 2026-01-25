#!/bin/bash
set -e

IMAGE_NAME="${1:-n8n-custom-test}"
SKIP_BUILD="${2:-false}"
CONTAINER_NAME="n8n-perm-check"
TEST_DIR="$(pwd)/n8n-test-data"

# Get current user's UID and GID
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

echo "Current User: $CURRENT_UID:$CURRENT_GID"

if [ "$SKIP_BUILD" != "skip-build" ]; then
  # Build the Docker image
  echo "Building Docker image..."
  docker build -t "$IMAGE_NAME" .
else
  echo "Skipping Docker build..."
fi

# Create a test directory
echo "Creating test directory: $TEST_DIR"
mkdir -p "$TEST_DIR"

# Run the container
echo "Running container..."
docker run --rm -d \
  --name "$CONTAINER_NAME" \
  -e PUID="$CURRENT_UID" \
  -e PGID="$CURRENT_GID" \
  -v "$TEST_DIR":/data \
  "$IMAGE_NAME"

echo "Waiting for container to initialize (10s)..."
sleep 10

# Check permissions of the test directory
echo "Checking permissions..."
DIR_UID=$(stat -c '%u' "$TEST_DIR")
DIR_GID=$(stat -c '%g' "$TEST_DIR")

echo "Directory UID: $DIR_UID (Expected: $CURRENT_UID)"
echo "Directory GID: $DIR_GID (Expected: $CURRENT_GID)"

if [ "$DIR_UID" -eq "$CURRENT_UID" ] && [ "$DIR_GID" -eq "$CURRENT_GID" ]; then
  echo "SUCCESS: Permissions are correct."
else
  echo "FAILURE: Permissions do not match."
  # Show logs to debug
  docker logs "$CONTAINER_NAME"
fi

# Cleanup
echo "Cleaning up..."
docker stop "$CONTAINER_NAME"
# We can remove the dir because we own it (if success) or we might need sudo if fail/root owned it
rm -rf "$TEST_DIR" || echo "Warning: Could not remove test directory. You might need sudo."

echo "Done."
