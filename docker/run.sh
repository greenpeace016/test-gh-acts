#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <path-to-env-file>" >&2
  exit 2
}

[ $# -eq 1 ] || usage
ENV_FILE=$1
[ -f "$ENV_FILE" ] || { echo "env file not found: $ENV_FILE" >&2; exit 2; }
[ -r "$ENV_FILE" ] || { echo "env file is not readable: $ENV_FILE" >&2; exit 2; }

NAME=${NAME:-gh-runner-test}

docker rm -f "$NAME" >/dev/null 2>&1 || true

# .env only via --env-file: this script never reads its content
# container is kept after exit (no --rm) so failures are inspectable via docker logs
# TUN=1 runs tailscaled with kernel /dev/net/tun instead of userspace-networking
DOCKER_ARGS=(--env-file "$ENV_FILE")
if [ "${TUN:-0}" = "1" ]; then
  DOCKER_ARGS+=(--cap-add NET_ADMIN --device /dev/net/tun -e TS_TUN=tun)
fi
docker run -d \
  --name "$NAME" \
  "${DOCKER_ARGS[@]}" \
  gh-acts-runner-test:latest
echo "container '$NAME' started. follow logs:  docker logs -f $NAME"
