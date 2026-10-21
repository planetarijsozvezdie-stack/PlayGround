#!/usr/bin/env bash
set -euo pipefail

timed() {
  printf '[capture] %s\n' "$*" >&2
  /usr/bin/time -p "$@"
}

: "${CAPTURE_URL:?Set CAPTURE_URL}"
: "${CAPTURE_DIR:?Set CAPTURE_DIR}"

SESSION="capture-$$-$RANDOM"
cleanup() {
  timed playwright-cli -s="$SESSION" close >/dev/null 2>&1 || true
}
trap cleanup EXIT

timed mkdir -p "$CAPTURE_DIR"
CAPTURE_DIR="$(cd "$CAPTURE_DIR" && pwd)"

if ! timed curl --fail --silent --show-error --max-time 30 \
  --output /dev/null "$CAPTURE_URL"; then
  echo "Preview is not reachable: $CAPTURE_URL" >&2
  exit 75
fi

if ! timed playwright-cli -s="$SESSION" open "$CAPTURE_URL" >/dev/null; then
  echo "Browser could not open preview: $CAPTURE_URL" >&2
  exit 75
fi

rendered=false
for _ in $(seq 1 90); do
  if ! out="$(timed playwright-cli -s="$SESSION" eval \
    "() => { const p = document.querySelector('flt-glass-pane'); return !!(p && p.shadowRoot && p.shadowRoot.querySelector('canvas')); }" \
    2>/dev/null)"; then
    echo 'Browser became unavailable while waiting for the app.' >&2
    exit 75
  fi
  if grep -qx 'true' <<<"$out"; then
    rendered=true
    break
  fi
  sleep 0.5
done

if [[ "$rendered" != true ]]; then
  echo 'Flutter app did not render a canvas within 45 seconds.' >&2
  exit 1
fi

timed sleep 1

if ! timed playwright-cli -s="$SESSION" resize 1440 900 >/dev/null; then
  echo 'Browser failed to resize for the desktop capture.' >&2
  exit 75
fi
timed sleep 1
if ! timed playwright-cli -s="$SESSION" screenshot \
  --filename="$CAPTURE_DIR/final-desktop.png" >/dev/null; then
  echo 'Browser failed to take the desktop capture.' >&2
  exit 75
fi

if ! timed playwright-cli -s="$SESSION" resize 390 844 >/dev/null; then
  echo 'Browser failed to resize for the mobile capture.' >&2
  exit 75
fi
timed sleep 1
if ! timed playwright-cli -s="$SESSION" screenshot \
  --filename="$CAPTURE_DIR/final-mobile.png" >/dev/null; then
  echo 'Browser failed to take the mobile capture.' >&2
  exit 75
fi

for image in final-desktop.png final-mobile.png; do
  path="$CAPTURE_DIR/$image"
  if [[ ! -s "$path" ]]; then
    echo "Missing capture: $path" >&2
    exit 1
  fi
  size="$(stat -c '%s' "$path")"
  if (( size < 5000 )); then
    echo "Capture looks blank or truncated: $path ($size bytes)" >&2
    exit 1
  fi
  echo "[capture] $path ($size bytes)" >&2
done
