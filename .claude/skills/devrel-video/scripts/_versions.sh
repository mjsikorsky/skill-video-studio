#!/usr/bin/env bash
# Pinned tool versions for reproducible captures and renders — sourced by the capture/render scripts.
# Bump deliberately (and re-run a render) rather than tracking the newest release. Env vars already set win.
HYPERFRAMES_VERSION="${HYPERFRAMES_VERSION:-0.8.179}"
PLAYWRIGHT_CLI_VERSION="${PLAYWRIGHT_CLI_VERSION:-0.1.22}"
VHS_VERSION="${VHS_VERSION:-v0.12.1}"
TTYD_VERSION="${TTYD_VERSION:-1.7.7}"

# Install @playwright/cli into <skill>/.pw with an explicit prefix: without one, npm installs into the
# nearest ancestor that has a package.json (often $HOME). Usage: ensure_playwright_cli <skill-dir>
ensure_playwright_cli() {
  local skill="$1" bin="$1/.pw/node_modules/.bin/playwright-cli"
  if [ ! -x "$bin" ] || ! grep -q "\"version\": \"$PLAYWRIGHT_CLI_VERSION\"" "$skill/.pw/node_modules/@playwright/cli/package.json" 2>/dev/null; then
    echo "installing @playwright/cli@$PLAYWRIGHT_CLI_VERSION (one-time)…"
    mkdir -p "$skill/.pw"
    npm i --prefix "$skill/.pw" --loglevel=error "@playwright/cli@$PLAYWRIGHT_CLI_VERSION" >/dev/null
  fi
  export PATH="$skill/.pw/node_modules/.bin:$PATH"
}
