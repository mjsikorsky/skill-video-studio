#!/usr/bin/env bash
# Extract real brand tokens + logo from a live URL into brands/<name>/.
# Usage: brand-extract.sh <url> <name>
set -euo pipefail

URL="${1:?url}"; NAME="${2:?brand name}"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_versions.sh"
ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
OUT="$ROOT/brands/$NAME"; mkdir -p "$OUT"

export HYPERFRAMES_NO_TELEMETRY=1 DO_NOT_TRACK=1 HYPERFRAMES_SKIP_SKILLS=1
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if ! npx --yes "hyperframes@$HYPERFRAMES_VERSION" capture "$URL" -o "$TMP/cap" --max-screenshots 3 --skip-vision --json \
    >"$TMP/capture.log" 2>&1; then
  echo "WARN: hyperframes capture exited non-zero; last lines of its output:" >&2
  tail -15 "$TMP/capture.log" >&2
fi

if [ -f "$TMP/cap/extracted/tokens.json" ]; then
  cp "$TMP/cap/extracted/tokens.json" "$OUT/tokens.json"; echo "wrote $OUT/tokens.json"
else
  echo "WARN: no tokens.json produced — check the URL / capture output"
fi
LOGO="$(find "$TMP/cap/assets/svgs" -maxdepth 1 -name 'logo-*.svg' 2>/dev/null | sort | head -1)"
if [ -n "$LOGO" ]; then
  cp "$LOGO" "$OUT/logo.svg"; echo "wrote $OUT/logo.svg"
else
  echo "note: no logo SVG captured — add $OUT/logo.svg by hand"
fi
echo "review $OUT/tokens.json → cssVariables / colors / fonts for the composition palette"
