#!/usr/bin/env bash
# Fetches the offline Vosk speech model bundled into the Android app (voice fallback on
# devices without an on-device recogniser, e.g. the LineageOS wall tablet).
# Build-time only: the app itself never downloads anything.
# Model: vosk-model-small-en-in-0.4 (Apache-2.0), https://alphacephei.com/vosk/models
set -euo pipefail
URL=https://alphacephei.com/vosk/models/vosk-model-small-en-in-0.4.zip
SHA256=20663dcac4d5cb783a579c54d98339344a688e4ec6e1b4a4b059fd1235454cc7
DEST="$(cd "$(dirname "$0")/.." && pwd)/app/android/app/src/main/assets/vosk-en-in"
if [ -f "$DEST/uuid" ] && [ "$(cat "$DEST/uuid")" = "$SHA256" ]; then
  echo "vosk model present: $DEST"; exit 0
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$URL" -o "$tmp/m.zip"
got=$( (command -v sha256sum >/dev/null && sha256sum "$tmp/m.zip" || shasum -a 256 "$tmp/m.zip") | cut -d' ' -f1)
[ "$got" = "$SHA256" ] || { echo "checksum mismatch: $got" >&2; exit 1; }
unzip -q "$tmp/m.zip" -d "$tmp"
rm -rf "$DEST"; mkdir -p "$(dirname "$DEST")"
mv "$tmp/vosk-model-small-en-in-0.4" "$DEST"
# The app unpacks the model once and re-unpacks when this id changes.
echo "$SHA256" > "$DEST/uuid"
echo "vosk model installed: $DEST"
