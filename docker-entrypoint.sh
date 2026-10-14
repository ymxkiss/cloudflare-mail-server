#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/app}"
IMAGE_APP_DIR="/opt/cloudflare-mail-server"

if [ ! -f "$APP_DIR/package.json" ]; then
  if [ -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    echo "ERROR: $APP_DIR is not empty but package.json is missing; refusing to overwrite mounted files." >&2
    exit 1
  fi
  echo "Initializing the bind-mounted project directory from the image..."
  cp -R "$IMAGE_APP_DIR"/. "$APP_DIR"/
fi

if [ ! -f "$APP_DIR/server.js" ]; then
  echo "ERROR: $APP_DIR/server.js is missing; ensure the complete project directory is mounted." >&2
  exit 1
fi

# Keep secrets and editable settings in the mounted directory. Never overwrite an existing config.
if [ ! -f "$APP_DIR/config.yaml" ] && [ -f "$APP_DIR/config.yaml.sample" ]; then
  cp "$APP_DIR/config.yaml.sample" "$APP_DIR/config.yaml"
  echo "Created $APP_DIR/config.yaml from config.yaml.sample; edit it with your service credentials."
fi

mkdir -p "$APP_DIR/data" "$APP_DIR/logs"
export NODE_PATH="/opt/node_modules${NODE_PATH:+:$NODE_PATH}"
cd "$APP_DIR"
exec "$@"
