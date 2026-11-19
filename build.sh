#!/bin/bash
# Build the launcher and the disclaim helper into build/.
#
# The launcher's cdhash is its identity to TCC, so this build is deliberately
# reproducible: an unchanged tree rebuilds the exact binary that holds the
# grants, which is how install.sh tells "nothing to do" from "the grants are
# about to be lost". The output depends on how -o is spelled, so the launcher
# is linked from inside build/ with a bare name. `-o build/...` or an absolute
# path links identical code to a different cdhash.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build
cd build
clang -O2 -Wall -o brew-autoupdate-launcher ../src/launcher.c
codesign --force --sign - --identifier brew-autoupdate-launcher brew-autoupdate-launcher 2>/dev/null
clang -O2 -Wall -o disclaim ../src/disclaim.c

echo "build/brew-autoupdate-launcher $(codesign -dvvv brew-autoupdate-launcher 2>&1 | awk -F= '/^CDHash=/ {print $2}')"
