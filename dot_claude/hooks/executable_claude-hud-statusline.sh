#!/usr/bin/env bash
# claude-hud statusline launcher.
#
# /claude-hud:setup normally bakes a one-line shell command into settings.json
# with the absolute runtime path hardcoded. That path differs per machine
# (/opt/homebrew/bin/node on macOS, /usr/bin/node on Arch), so a versioned
# settings.json cannot carry it. This script resolves the runtime and the
# plugin directory at launch instead.
#
# Never fails loudly: a missing plugin or runtime means no HUD, not a broken
# prompt. Claude Code renders whatever lands on stdout.

# Homebrew is not on PATH when the terminal starts from launchd.
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"

# Claude Code pipes our stdout, so the plugin cannot read the terminal width
# from process.stdout.columns. It reads COLUMNS, which Claude Code >= 2.1.153
# exports itself; stty covers older versions and 120 is the last resort.
cols=${COLUMNS:-}
case "$cols" in
  '' | *[!0-9]*) cols=$(stty size 2>/dev/null </dev/tty | awk '{print $2}') ;;
esac
case "$cols" in
  '' | *[!0-9]*) cols=120 ;;
esac
# Claude Code pads the input area by 2 columns on each side.
if [ "$cols" -gt 4 ]; then
  COLUMNS=$((cols - 4))
else
  COLUMNS=1
fi
export COLUMNS

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# Several versions coexist in the cache after an update, so sort by version
# number rather than mtime. The [[:space:]] class is deliberate: GNU grep does
# not expand \t in a pattern and would silently match nothing.
PLUGIN_DIR=$(
  ls -d "$CLAUDE_DIR"/plugins/cache/*/claude-hud/*/ 2>/dev/null |
    awk -F/ '{ print $(NF-1) "\t" $0 }' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' |
    sort -t. -k1,1n -k2,2n -k3,3n |
    tail -1 | cut -f2-
)

if [ -z "$PLUGIN_DIR" ]; then
  exit 0
fi

# Bun runs the TypeScript sources directly and starts faster. --env-file
# /dev/null keeps it from auto-loading the project's .env into the HUD.
if RUNTIME=$(command -v bun 2>/dev/null); then
  exec "$RUNTIME" --env-file /dev/null "${PLUGIN_DIR}src/index.ts"
elif RUNTIME=$(command -v node 2>/dev/null); then
  exec "$RUNTIME" "${PLUGIN_DIR}dist/index.js"
fi

exit 0
