#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="aws-infra-dev"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_HOME="/home/dev"

COMMAND="${1:-run}"

build_image() {
  echo "===> Building dev image: $IMAGE_NAME"
  docker build \
    -f "$REPO_ROOT/.devcontainer/Dockerfile" \
    -t "$IMAGE_NAME" \
    "$REPO_ROOT"
}

rebuild_image() {
  echo "===> Rebuilding dev image with no cache: $IMAGE_NAME"
  docker build --no-cache \
    -f "$REPO_ROOT/.devcontainer/Dockerfile" \
    -t "$IMAGE_NAME" \
    "$REPO_ROOT"
}

run_shell() {
  # Auto-build if image doesn't exist
  if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "===> Dev image not found. Building now..."
    build_image
  fi

  echo "===> Starting dev shell in container..."
  docker run --rm -it \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace \
    -v "$HOME/.aws:$DEV_HOME/.aws:rw" \
    -v "/var/run/docker.sock:/var/run/docker.sock" \
    "$IMAGE_NAME" \
    /bin/bash
}

case "$COMMAND" in
  build)
    build_image
    ;;
  rebuild)
    rebuild_image
    ;;
  run)
    run_shell
    ;;
  *)
    echo "Usage: $0 [build|rebuild|run]"
    exit 1
    ;;
esac
