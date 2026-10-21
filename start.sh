#!/usr/bin/env bash
set -euo pipefail

timed() {
  printf '[start] %s\n' "$*" >&2
  /usr/bin/time -p "$@"
}

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
APP_DIR="$PROJECT_DIR/app"
DIST_DIR="$PROJECT_DIR/dist"
DEPLOY_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
PORT="${PORT:-${APP_PORT:-3000}}"

[[ "$PORT" =~ ^[1-9][0-9]*$ ]] || {
  echo "PORT must be a positive integer, got: $PORT" >&2
  exit 1
}

FLUTTER_BIN="${FLUTTER_BIN:-$HOME/flutter/bin/flutter}"
if [[ ! -x "$FLUTTER_BIN" ]]; then
  FLUTTER_BIN="$(command -v flutter || true)"
fi
if [[ -z "$FLUTTER_BIN" || ! -x "$FLUTTER_BIN" ]]; then
  echo 'Flutter is not installed. Run startup.sh on this worker first.' >&2
  exit 1
fi

timed mkdir -p "$DEPLOY_DIR"
timed test -f "$APP_DIR/pubspec.yaml"

cd "$APP_DIR"
timed "$FLUTTER_BIN" pub get

needs_build=0
if [[ ! -f "$DIST_DIR/index.html" ]]; then
  needs_build=1
elif find \
  "$APP_DIR/lib" \
  "$APP_DIR/web" \
  "$APP_DIR/assets" \
  "$APP_DIR/pubspec.yaml" \
  "$APP_DIR/pubspec.lock" \
  -newer "$DIST_DIR/index.html" -print -quit 2>/dev/null | grep -q .; then
  needs_build=1
fi

if [[ "$needs_build" == 1 ]]; then
  timed "$FLUTTER_BIN" build web --release --no-web-resources-cdn --output "$DIST_DIR"
else
  echo '[start] web build is up to date' >&2
fi

timed test -f "$DIST_DIR/index.html"
timed /usr/bin/printf '{"project":"%s","directory":"%s"}\n' \
  "$PROJECT_DIR" "$DIST_DIR" > "$DEPLOY_DIR/deployment-output.json"
timed cat "$DEPLOY_DIR/deployment-output.json" >&2

echo "[start] serving $DIST_DIR on 0.0.0.0:$PORT" >&2
exec /usr/bin/time -p python3 -m http.server "$PORT" \
  --bind 0.0.0.0 --directory "$DIST_DIR"
