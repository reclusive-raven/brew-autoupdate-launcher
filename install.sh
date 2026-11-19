#!/bin/bash
# Install the launcher at its fixed internal path and put it in front of the
# homebrew-autoupdate launch agent. Safe to re-run, and re-running is how to
# restore the wrapping after `brew autoupdate start` rewrites the plist.
#
# TCC keys both grants (Removable Volumes, App Management) on the installed
# path plus the binary's cdhash. Replacing the binary with a different build
# silently drops them and brings back the exact failure this tool fixes, so
# this refuses unless given --replace. After --replace, run ./grant.sh.
set -euo pipefail
cd "$(dirname "$0")"

label=com.github.domt4.homebrew-autoupdate
dest_dir="$HOME/Library/Application Support/brew-autoupdate-launcher"
dest="$dest_dir/brew-autoupdate-launcher"
plist="$HOME/Library/LaunchAgents/$label.plist"
script="$HOME/Library/Application Support/$label/brew_autoupdate"

cdhash() { codesign -dvvv "$1" 2>&1 | awk -F= '/^CDHash=/ {print $2}'; }

./build.sh >/dev/null
new=$(cdhash build/brew-autoupdate-launcher)

install_binary=0
if [[ ! -e "$dest" ]]; then
  install_binary=1
elif [[ "$(cdhash "$dest")" == "$new" ]]; then
  echo "launcher: installed copy matches this build ($new), left in place"
elif [[ "${1:-}" == "--replace" ]]; then
  install_binary=1
else
  echo "launcher: installed cdhash $(cdhash "$dest") differs from this build's $new." >&2
  echo "Replacing it drops its TCC grants. Re-run with --replace, then run ./grant.sh." >&2
  exit 1
fi

if (( install_binary )); then
  mkdir -p "$dest_dir"
  # Copy, then rename over: the new file is a new inode, so a run already in
  # progress keeps executing the old binary instead of having its code
  # signature invalidated underneath it.
  cp build/brew-autoupdate-launcher "$dest.new"
  mv -f "$dest.new" "$dest"
  echo "launcher: installed $new. Grants are per cdhash, so run ./grant.sh now."
fi

if [[ ! -f "$plist" || ! -x "$script" ]]; then
  echo "agent: no homebrew-autoupdate agent found. Run brew autoupdate start first (see README)." >&2
  exit 1
fi
if [[ "$(plutil -extract Program raw "$plist" 2>/dev/null)" == "$dest" &&
      "$(plutil -extract ProgramArguments.1 raw "$plist" 2>/dev/null)" == "$script" ]]; then
  echo "agent: already runs through the launcher"
  exit 0
fi

plutil -replace Program -string "$dest" "$plist"
plutil -replace ProgramArguments -json "[\"$dest\", \"$script\"]" "$plist"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
# A bootstrap straight after a bootout can fail with "5: Input/output error"
# while launchd still holds the old job, so give it a few tries.
for _ in 1 2 3 4 5; do
  if launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null; then
    echo "agent: now runs through the launcher (reloaded)"
    exit 0
  fi
  sleep 2
done
echo "agent: plist updated but bootstrap failed. Run: launchctl bootstrap gui/$(id -u) \"$plist\"" >&2
exit 1
