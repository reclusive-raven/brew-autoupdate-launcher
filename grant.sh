#!/bin/bash
# Give the installed launcher its two TCC grants. Needed once per installed
# build: after `./install.sh --replace`, or if the grants were revoked.
#
# Removable Volumes has a prompt, but a launchd job cannot show it, and a
# command run from a terminal or Claude Code is attributed to that app, not
# the launcher. disclaim spawns the launcher as its own responsible process
# for one read of the Homebrew cache, which raises the prompt. Click Allow.
#
# App Management has no prompt at all. The first attempt is denied and leaves
# a switched-off row in System Settings, so this makes one attempt (the same
# write test Homebrew runs before a cask upgrade) and opens that pane if it
# was refused.
set -euo pipefail
cd "$(dirname "$0")"

dest="$HOME/Library/Application Support/brew-autoupdate-launcher/brew-autoupdate-launcher"
[[ -x "$dest" ]] || { echo "not installed; run ./install.sh first" >&2; exit 1; }
[[ -x build/disclaim ]] || ./build.sh >/dev/null

echo "Removable Volumes: click Allow if macOS asks about brew-autoupdate-launcher..."
build/disclaim "$dest" /bin/ls "$(brew --cache)" >/dev/null
echo "Removable Volumes: ok"

app=$(find /Applications -maxdepth 1 -name '*.app' -user "$USER" | head -1)
if [[ -n "$app" ]] && build/disclaim "$dest" /usr/bin/touch "$app/.homebrew-write-test" 2>/dev/null; then
  rm -f "$app/.homebrew-write-test"
  echo "App Management: ok"
else
  echo "App Management: switch on brew-autoupdate-launcher in the System Settings pane that just opened."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles"
fi
