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
| `linux-base` | A fresh Ubuntu desktop: packages, shell, fonts, colours, core tools |
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

## What gets linked where

| Repo path | Destination |
| --- | --- |
| `zsh/zshrc` | `~/.zshrc` |
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
