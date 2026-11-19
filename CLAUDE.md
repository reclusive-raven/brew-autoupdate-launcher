# CLAUDE.md

## What this is

A tiny C launcher that the `com.github.domt4.homebrew-autoupdate` launch agent runs in place of the tap's `brew_autoupdate` script. It exists only so macOS TCC attributes the job's file access to a binary that holds the right grants, which is what lets `HOMEBREW_CACHE` live on an external volume. `README.md` has the why.

## Commands

```sh
./build.sh              # build/brew-autoupdate-launcher + build/disclaim; prints the launcher's cdhash
./install.sh            # install if absent or identical, then make sure the agent runs through it
./install.sh --replace  # replace a differing installed binary (drops its grants)
./grant.sh              # re-grant Removable Volumes (prompt) and App Management (Settings toggle)
launchctl kickstart gui/$(id -u)/com.github.domt4.homebrew-autoupdate   # run the job now
```

There are no tests. Verify a change by running the job under launchd, then check `launchctl print gui/$(id -u)/com.github.domt4.homebrew-autoupdate` for `last exit code = 0` and the log at `~/Library/Logs/com.github.domt4.homebrew-autoupdate/com.github.domt4.homebrew-autoupdate.out` for no `Operation not permitted`. A kickstart really upgrades whatever is outdated, so check `brew outdated` first and do not kickstart while a cask for an app in use is due.

## Invariants

Each of these breaks the job silently, which is the failure mode this repo exists to end.

- **Spawn, never exec.** TCC looks up the responsible process's identity when the check happens. After an exec that process is `/bin/sh` again, and the grants stop applying.
- **The installed binary is what TCC trusts.** Grants are keyed on `~/Library/Application Support/brew-autoupdate-launcher/brew-autoupdate-launcher` plus its cdhash. Moving it, re-signing it, or replacing it with a different build drops both, and a background job cannot ask for them back. The only way to replace it is `./install.sh --replace` followed by `./grant.sh`, with someone at the Mac to click Allow and flip the App Management toggle.
- **The build is reproducible, and that is load-bearing.** It is what lets `install.sh` treat an unchanged tree as a no-op. Comment edits keep the cdhash, and so does building from any directory. Code, flags, the signing identifier, or a toolchain update change it. The output also depends on how `-o` is spelled: a bare `-o brew-autoupdate-launcher` run from inside `build/` reproduces the installed copy, while `-o build/brew-autoupdate-launcher` or an absolute path links identical code to a different cdhash (observed with Apple clang 21.0.0). Keep `build.sh` linking from inside `build/`.
- **A toolchain update is not a reason to replace.** A Command Line Tools or SDK update changes the cdhash of unchanged source, and `install.sh` then refuses. If `src/launcher.c` did not change, keep the installed copy (compare `otool -tv` output with addresses stripped) and finish any plist step by hand; `--replace` would drop the grants for nothing.
- **Keep the installed copy on internal storage.** A launchd `Program` on an external volume can hang or fail to spawn, so never point the plist at a build inside a checkout that lives on one.
- **Replace by copy-then-rename**, as `install.sh` does. Writing over the file in place invalidates the signature of a run in progress.

## The tap

`domt4/autoupdate` generates the plist and the `brew_autoupdate` script; this repo only patches the plist's `Program` and `ProgramArguments`. `brew autoupdate start` rewrites the plist and drops the launcher, so run `./install.sh` after it.

On Homebrew 6.0.x (tap commit `0ea0c0f`) the tap's `delete` and `start` both crash with `undefined method 'quiet_system' for module Autoupdate`. `start` writes the script and plist before it crashes, so `./install.sh` afterwards loads the job correctly. A working `delete` would also `rm -rf` the log directory, so back the log up first. To change options by hand: `launchctl bootout` the job, remove the plist and `~/Library/Application Support/com.github.domt4.homebrew-autoupdate`, run `start` under `env -i HOME=$HOME USER=$USER TMPDIR=$TMPDIR PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin HOMEBREW_CACHE=<cache>` (it bakes the caller's PATH into the script), then `./install.sh`.
