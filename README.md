# dotfiles

Personal configuration for zsh, neovim, tmux, ranger and the tooling around
them, plus the install steps that put it all on a new machine. Targets Ubuntu
(desktop and server) and macOS.

## Install

Everything goes through one entry point. Nothing needs to be edited to run it.

```sh
git clone <this repo> ~/dotfiles
cd ~/dotfiles

./scripts/install.sh --list                     # what can I run here?
./scripts/install.sh --dry-run --profile macos  # what would it do?
./scripts/install.sh --profile linux-server     # do it
./scripts/install.sh oh_my_zsh fzf neovim       # or pick individual steps
```

Only the steps for the current OS are loaded, so `--list` always shows what can
actually run on this machine. **Every step is safe to run twice** — clones are
pulled rather than re-cloned, symlinks are refreshed, and downloads go to a
scratch directory that is removed on exit.

### Profiles

| Profile | For |
| --- | --- |
| `linux-base` | A fresh Ubuntu desktop: packages, shell, fonts, colours, core tools, node |
| `linux-server` | A server account: shell, tools and conda, no desktop packages |
| `linux-desktop` | Desktop extras: docker, NVIDIA, language toolchains, apps |
| `macos` | Homebrew, casks, iTerm2 colours, shell, tools, aerospace |

### Layout

```
scripts/
  install.sh        entry point: argument parsing, profiles, step dispatch
  lib/common.sh     link / clone_or_pull / copy_if_absent / run helpers
  steps/shared.sh   steps identical on both platforms
  steps/linux.sh    apt, NVIDIA, toolchains
  steps/macos.sh    brew, casks
```

A step is just a `step_<name>` bash function. To add one, drop it in the right
`steps/` file — `--list` picks it up automatically.

### Pinned versions

Everything fetched from upstream is pinned to a specific release, so two
machines set up months apart land on the same tooling. The pins sit at the top
of the step files:

| Where | Pins |
| --- | --- |
| `scripts/steps/shared.sh` | `NEOVIM_VERSION`, `NODE_VERSION`, `NVM_VERSION` |
| `scripts/steps/linux.sh` | `NERD_FONT_VERSION`, `ANACONDA_VERSION`, `GO_VERSION`, `DRAWIO_VERSION` |

Neovim is the one that matters most. `NEOVIM_VERSION` is held at 0.11.x on all
three platforms because nvim-treesitter's `master` branch breaks on 0.12 — the
comment above the variable has the details. macOS and Linux both install that
exact upstream tarball to `~/.local/bin/nvim` rather than going through a
package manager, since neither brew nor apt can be asked for a given version.
For the same reason nothing else may install an `nvim`: a brew-installed one
shadows `~/.local/bin` on `PATH` and quietly defeats the pin, so `step_neovim`
removes it.

Two deliberate exceptions:

- **nvm on macOS** comes from `brew install nvm` and rolls forward, because
  Homebrew has no versioned formula and pinning one would mean maintaining a
  private tap. `NVM_VERSION` therefore governs Linux alone. `NODE_VERSION` —
  the version that actually affects what you run — is pinned on both, and
  `NVM_DIR` is `~/.nvm` on both so that `brew upgrade nvm` cannot delete the
  installed node versions along with the keg.
- **lazygit on Linux** resolves the latest release at install time.

## What gets linked where

| Repo path | Destination |
| --- | --- |
| `zsh/zshrc` | `~/.zshrc` |
| `zsh/zshenv` | `~/.zshenv` |
| `zsh/zshlc.template` | `~/.zshlc` *(copied once, never overwritten)* |
| `nvim/` | `~/.config/nvim` |
| `stylua/` | `~/.config/stylua` |
| `tmux/tmux.conf.local` | `~/.tmux.conf.local` |
| `ranger/*` | `~/.config/ranger/` |
| `aerospace/aerospace.toml` | `~/.config/aerospace/aerospace.toml` |
| `clang-format/clang-format-{ubuntu,macos}.yml` | `~/.clang-format` |
| `gdb/gdbinit` | `~/.gdbinit` |
| `pdb/pdbrc.py` | `~/.pdbrc.py` |

## Machine-local settings

`zsh/zshrc` is shared across every machine and is a symlink, so do not edit it
for one-off settings. It sources `~/.zshlc` at the end — that is where
per-machine values belong (dataset paths, CUDA helpers, API endpoints, local
aliases).

`~/.zshlc` is seeded once from `zsh/zshlc.template` and is **never** overwritten
by the installer, and it is gitignored. Anything you want on every machine goes
in `zsh/zshrc`; anything specific to one box goes in `~/.zshlc`.

## Shell startup

`zsh/zshrc` is kept fast (~50ms) deliberately. Three things are responsible and
are worth preserving if you edit it:

- **compinit runs once.** `oh-my-zsh.sh` already calls it; calling it again
  costs ~230ms. Anything that extends `FPATH` must come *before* that source.
  `zsh/zshenv` exists for the same reason: Ubuntu's `/etc/zsh/zshrc` runs a
  third, bare `compinit`, and `~/.zshenv` is the only file read early enough to
  set the `skip_global_compinit=1` that turns it off. On a host with a
  group-writable `FPATH` entry — an lmod cluster, say — that bare compinit stops
  and asks about it, which hangs the login on a tty and kills completions
  without one. Do not delete it because it looks like one stray line.
- **nvm is lazy.** `nvm`, `node`, `npm` and `npx` are stubs that load the real
  nvm on first use, instead of paying ~360ms in every shell.
- **conda activation is cached.** `conda activate base` shells out to Python
  (~220ms). The resulting environment is cached in
  `~/.cache/conda-base-activate.zsh` and replayed instead. The cache rebuilds
  itself whenever the conda install changes; delete it to force a refresh.

To check the cost after a change:

```sh
for i in 1 2 3; do /usr/bin/time -f %e zsh -i -c exit; done
```

## Reference notes

Some directories are documentation rather than configuration — `kernel/`,
`networks/`, `pyenv/`, `ssh/`, `vnc/`, `mutter/`, `tilingshell/`, `docker/`,
`std/`. They are runbooks kept next to the configuration they describe.

`templates/README.template.md` is a markdown scaffold for new projects.
