# brew-autoupdate-launcher

A 40-line C launcher that lets the [homebrew-autoupdate](https://github.com/domt4/homebrew-autoupdate) launch agent use a Homebrew cache on an external drive.

## Why

Say `HOMEBREW_CACHE` points at an external volume (for example `/Volumes/External/caches/homebrew`, set in `brew.env` so every brew invocation uses it). launchd makes a job's own executable the process macOS privacy checks (TCC) hold responsible for everything the job does. For homebrew-autoupdate that is `/bin/sh`, which may not touch removable volumes, and a background job cannot be shown the permission prompt. So every scheduled run fails inside `brew update` with `Operation not permitted`, and because the script chains `update && upgrade`, nothing gets upgraded. Notifications only fire on failure if you asked for them, so this can go unnoticed for weeks.

The launcher sits in front of the tap's script and spawns it as a child, so TCC checks the launcher instead. It holds exactly two grants:

- **Removable Volumes**, for the cache on the external drive
- **App Management**, so cask upgrades can replace apps in `/Applications`

It spawns rather than execs, because an exec would turn the process back into `/bin/sh` as far as TCC is concerned.

## Use

Set up the agent with `brew autoupdate start` first, then:

```sh
./install.sh            # build, install to ~/Library/Application Support/brew-autoupdate-launcher/, wrap the agent
./install.sh --replace  # the same, when this build's cdhash differs from the installed copy
./grant.sh              # (re)grant both permissions for the installed copy
```

`install.sh` is idempotent. Re-run it whenever `brew autoupdate start` has regenerated the plist, since that drops the launcher.

TCC keys both grants on the installed path plus the binary's cdhash, so replacing the binary with a different build loses them, and the job goes back to failing quietly. `install.sh` therefore refuses to replace a differing binary without `--replace`. The build is reproducible on a given toolchain, so an unchanged tree installs as a no-op. A Command Line Tools update can change the cdhash of unchanged source; if `launcher.c` did not change, keep the installed copy rather than replacing it.

Requires macOS with the Command Line Tools (`clang`, `codesign`) and the `domt4/autoupdate` tap.

## Layout

| Path | What |
|---|---|
| `src/launcher.c` | the launcher |
| `src/disclaim.c` | helper that raises the Removable Volumes prompt on the launcher's behalf |
| `build.sh` | reproducible build into `build/` |
| `install.sh` | install the launcher and wrap the agent |
| `grant.sh` | grant the two permissions |

The launch agent (`com.github.domt4.homebrew-autoupdate`) and its script belong to the tap. This repo only rewrites the plist's `Program` and `ProgramArguments`.

`disclaim.c` uses `responsibility_spawnattrs_setdisclaim`, a private libSystem function, so a future macOS may break it. Only `grant.sh` needs it; the launcher itself uses plain `posix_spawn`.

## License

[MIT](LICENSE)
