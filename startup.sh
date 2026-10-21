#!/usr/bin/env bash
set -euo pipefail

FLUTTER_HOME="$HOME/flutter"
FLUTTER_VERSION='3.47.7'
ARCHIVE="/tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [[ ! -x "$FLUTTER_HOME/bin/flutter" ]]; then
  /usr/bin/time -p curl --fail --location --retry 3 \
    --output "$ARCHIVE" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  /usr/bin/time -p mkdir -p "$(dirname "$FLUTTER_HOME")"
  /usr/bin/time -p tar -xJf "$ARCHIVE" -C "$(dirname "$FLUTTER_HOME")"
  /usr/bin/time -p rm -f "$ARCHIVE"
fi

/usr/bin/time -p "$FLUTTER_HOME/bin/flutter" --version >/dev/null
