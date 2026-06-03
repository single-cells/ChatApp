#!/usr/bin/env bash
# Run on the production server from /opt/chat (compose + .env + image tar).
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env}"
ACTION="${1:-up}"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Missing $COMPOSE_FILE (run from deploy directory, e.g. /opt/chat)" >&2
  exit 1
fi

compose() {
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}

case "$ACTION" in
  load)
    TAR="${2:?usage: $0 load chat-api-VERSION.tar.gz}"
    if [[ "$TAR" == *.gz ]]; then
      gunzip -c "$TAR" | docker load
    else
      docker load -i "$TAR"
    fi
    ;;
  pull)
    compose pull postgres redis minio minio-init
    ;;
  up)
    compose pull postgres redis minio minio-init
    compose up -d
    echo "Health: curl -sf http://127.0.0.1:3000/health"
    ;;
  down)
    compose down
    ;;
  restart-api)
    compose restart api
    ;;
  logs)
    compose logs -f "${2:-api}"
    ;;
  ps)
    compose ps
    ;;
  *)
    echo "Usage: $0 {load|pull|up|down|restart-api|logs|ps} [args...]" >&2
    exit 1
    ;;
esac
