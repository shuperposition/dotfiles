# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal dotfiles for Ubuntu (desktop + server) and macOS. `README.md` is the
user-facing documentation — read it for what gets linked where, the profile
table, the version pins and their rationale. This file covers what is not
obvious from any single file.

## Commands

There is no build, no package manager and no test suite. The checks are:

```sh
./scripts/install.sh --list                     # steps + profiles for this OS
./scripts/install.sh --dry-run --profile macos  # verify a change without touching the system
./scripts/install.sh --dry-run <step>           # verify one step
shellcheck scripts/install.sh scripts/lib/*.sh scripts/steps/*.sh
shfmt -d scripts/                               # 4-space indent, indented case bodies
stylua --check nvim/                            # config in stylua/stylua.toml
for i in 1 2 3; do /usr/bin/time -f %e zsh -i -c exit; done   # shell startup cost
```

`--dry-run` is the primary test: it exercises argument parsing, profile
expansion and every step body without mutating the machine. Run it after any
change to `scripts/`.

## Installer architecture

`scripts/install.sh` sources `lib/common.sh`, then `steps/shared.sh`, then
*only* `steps/linux.sh` or `steps/macos.sh` for the current OS. Consequences:

- Steps are discovered by reflection (`declare -F | sed -n 's/^step_//p'`).
  A `step_<name>` function in the right file is automatically listed and
  runnable — there is no registry to update. Put it in the wrong file and it is
  invisible on that platform.
- `step_neovim` is defined in both platform files; the shared helpers it calls
  (`install_neovim_tarball`, `link_editor_config`) live in `shared.sh`.
- Profiles are a `case` statement, not an associative array, because macOS
  ships bash 3.2.

### Invariants for any step

1. **Everything that touches the system goes through `run()`.** A bare command
   in a step body executes under `--dry-run` and makes the dry run a lie.
2. **Steps must be idempotent.** Re-running is a no-op, not an error:
   `clone_or_pull` instead of `git clone`, `link` instead of `ln`,
   `need_dir` instead of `mkdir`.
3. **Never overwrite a file the user edits in place.** `copy_if_absent`, not
   `cp` — this applies to `~/.zshlc` and `~/.ssh/config`. `link` likewise
   refuses to clobber a real (non-symlink) file.
4. **Downloads go to `$(mktempdir)`**, a subdirectory of the run's scratch root,
   which a trap removes on exit.

## Machine-local vs shared

`~/.zshrc` is a symlink into this repo and is shared by every machine, so it
must never hold per-machine values. It sources `~/.zshlc` last; that file is
seeded once from `zsh/zshlc.template`, gitignored, and never overwritten.
Anything host-specific (dataset paths, CUDA helpers, endpoints) belongs there.

## Shell startup budget

`zsh/zshrc` is deliberately ~50ms. Three things carry that and are easy to
break unknowingly:

- **One compinit.** `oh-my-zsh.sh` calls it; a second costs ~230ms. Anything
  extending `FPATH` must be placed *above* that `source`. `zsh/zshenv` exists
  solely to set `skip_global_compinit=1` before Ubuntu's `/etc/zsh/zshrc` runs
  a third one — it is one line and it is load-bearing.
- **nvm is lazy.** `nvm`/`node`/`npm`/`npx` are stubs that source nvm on first
  use (~360ms saved per shell).
- **conda activation is cached** in `~/.cache/conda-base-activate.zsh`.

**Corollary that bites:** because the lazy loaders are interactive-shell
*functions*, the real binaries are not on `PATH` for non-interactive children —
Claude Code hooks (`/bin/sh -c`), launchd agents, editor subprocesses. The fix
used throughout is to symlink the real binary into `~/.local/bin`, which zshrc
prepends and children inherit (`step_nvm` does this for node/npm/npx,
`step_bun` for bun). Apply the same pattern to anything installed by a version
manager.

## Version pins

Pins sit at the top of `scripts/steps/shared.sh` and `linux.sh` with the reason
in a comment above them. The one with teeth: `NEOVIM_VERSION` is held at 0.11.x
because nvim-treesitter's `master` branch breaks on 0.12 — bumping it requires
migrating `nvim/lua/plugins/treesitter.lua` to the `main` branch first. Neovim
is installed from the upstream tarball on both platforms because neither brew
nor apt can be asked for a version, and `step_neovim` on macOS actively
`brew uninstall`s any neovim that would shadow `~/.local/bin` on `PATH`.

## Neovim config

`nvim/init.lua` loads `lua/config/{options,autocmds,keymaps,lsp}.lua` (options
first — it sets `mapleader`, which every later `<leader>` mapping resolves at
definition time), then bootstraps lazy.nvim with `{ import = "plugins" }`. One
file per plugin in `nvim/lua/plugins/`; a new file is picked up with no
registration. LSP server settings go in `nvim/after/lsp/<server>.lua`. Commit
`nvim/lazy-lock.json` with plugin changes. Formatting on save is conform.nvim
(`shfmt`, `stylua`, `isort`+`black`).

## Documentation-only directories

`kernel/`, `networks/`, `pyenv/`, `ssh/`, `vnc/`, `mutter/`, `tilingshell/`,
`docker/`, `std/`, `users/` are runbooks kept beside the config they describe,
not things the installer consumes. Editing them changes nothing on disk.
