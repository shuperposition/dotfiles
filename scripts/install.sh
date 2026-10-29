#!/usr/bin/env bash
#
# Entry point for installing this dotfiles repo.
#
#   ./scripts/install.sh --list                     # show every available step
#   ./scripts/install.sh oh_my_zsh fzf neovim       # run individual steps
#   ./scripts/install.sh --profile linux-server     # run a named set of steps
#   ./scripts/install.sh --dry-run --profile macos  # show what would happen
#
# Steps are `step_<name>` functions in scripts/steps/. Only the steps for the
# current OS are loaded, so --list always shows what can actually be run here.
# Every step is safe to re-run.

# Resolve the `source=` paths below against this file, not the working directory.
# shellcheck source-path=SCRIPTDIR

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# DRY_RUN and NO_SUDO are deliberately not exported: only the sourced step
# files read them, and third-party installers may read the same names
# (docker-install treats any non-empty DRY_RUN, even 0, as its own dry run).
DRY_RUN=0
export DOTFILES
# On a fresh machine ~/.local/bin did not exist at login, so ~/.profile left it
# off PATH; steps install into it and later steps (claude_plugins) look there.
export PATH="$HOME/.local/bin:$PATH"

# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=steps/shared.sh
. "$SCRIPT_DIR/steps/shared.sh"
if is_macos; then
    # shellcheck source=steps/macos.sh
    . "$SCRIPT_DIR/steps/macos.sh"
    PLATFORM="macos"
else
    # shellcheck source=steps/linux.sh
    . "$SCRIPT_DIR/steps/linux.sh"
    PLATFORM="linux"
fi

# --- profiles ---------------------------------------------------------------
# Named step sets. A case statement rather than an associative array, so this still
# works on the bash 3.2 that macOS ships.
#
# linux-base is the terminal environment, installed entirely under $HOME with
# no sudo. linux-server and linux-desktop both build on it: a server adds what
# a shared GPU box needs, a desktop wraps it in the system packages it relies
# on (apt, before) and the GUI and sudo-only extras (after).

profile_steps() {
    case "$1" in
        linux-base)
            echo "prerequisites login_shell oh_my_zsh oh_my_tmux fzf lazygit gdu stylua
                  neovim nvm bun anaconda conda_packages python ranger
                  claude_code claude_plugins"
            ;;
        linux-server)
            echo "$(profile_steps linux-base) ranger_docker"
            ;;
        linux-desktop)
            # nvidia_driver is deliberately not here: it installs whatever
            # ubuntu-drivers recommends, which can replace a working driver.
            # Run it by name when that is actually wanted.
            echo "apt_update apt_general default_shell
                  $(profile_steps linux-base)
                  nerd_fonts gogh desktop_general tiling_shell input_method docker nvidia_container_toolkit
                  cpp java gvm tfenv claude_desktop spotify screenkey"
            ;;
        macos)
            echo "essentials terminal_utilities desktop_applications
                  iterm2_colors oh_my_zsh oh_my_tmux ranger fzf nvm bun neovim
                  anaconda aerospace python cpp gvm claude_code claude_plugins"
            ;;
        *) return 1 ;;
    esac
}

profile_platform() {
    case "$1" in
        linux-*) echo linux ;;
        macos) echo macos ;;
    esac
}

ALL_PROFILES="linux-base linux-server linux-desktop macos"

# --- helpers ----------------------------------------------------------------

# Every step_* function currently defined, without the prefix, sorted.
available_steps() {
    declare -F | awk '{print $3}' | sed -n 's/^step_//p' | sort
}

is_step() {
    declare -F "step_$1" > /dev/null 2>&1
}

usage() {
    cat << EOF
Usage: ${0##*/} [options] [step ...]

Options:
  -l, --list              list available steps and profiles for this OS
  -p, --profile <name>    run a named profile (may be repeated)
  -n, --dry-run           print what would run without changing anything
  -h, --help              show this message

Detected platform: $PLATFORM
Profiles:          $ALL_PROFILES

Run '${0##*/} --list' to see every step.
EOF
}

list_all() {
    printf 'Steps available on %s:\n' "$PLATFORM"
    available_steps | sed 's/^/  /'
    printf '\nProfiles:\n'
    for p in $ALL_PROFILES; do
        if [ "$(profile_platform "$p")" = "$PLATFORM" ]; then
            printf '  %-16s %s\n' "$p" "$(profile_steps "$p" | tr -s '[:space:]' ' ')"
        else
            printf '  %-16s (not applicable on %s)\n' "$p" "$PLATFORM"
        fi
    done
}

run_step() {
    name=$1
    CURRENT_STEP=$name
    printf '\n >>> %s\n' "$name"
    "step_$name"
    printf ' <<< %s\n' "$name"
    CURRENT_STEP=""
}

# Under `set -e` a failing command ends the run wherever it happens, and the
# steps after it silently never run. Say which step it was, and how to resume.
CURRENT_STEP=""
on_exit() {
    status=$?
    if [ "$status" != 0 ] && [ -n "$CURRENT_STEP" ]; then
        rest=$(echo "$STEPS" | sed -n "/^$CURRENT_STEP\$/,\$p" | tr '\n' ' ')
        printf '\n !!! step %s failed (exit %s); the remaining steps did not run.\n' \
            "$CURRENT_STEP" "$status" >&2
        printf '     fix it, then resume with: %s %s\n' "$0" "$rest" >&2
    fi
    cleanup_scratch
}

# --- argument parsing -------------------------------------------------------

STEPS=""
PROFILES=""
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        -l | --list)
            list_all
            exit 0
            ;;
        -n | --dry-run)
            DRY_RUN=1
            ;;
        -p | --profile)
            [ $# -ge 2 ] || die "--profile needs a name"
            want=$(profile_steps "$2") || die "unknown profile: $2 (have: $ALL_PROFILES)"
            [ "$(profile_platform "$2")" = "$PLATFORM" ] ||
                die "profile '$2' cannot run on $PLATFORM"
            STEPS="$STEPS $want"
            PROFILES="$PROFILES $2"
            shift
            ;;
        -*) die "unknown option: $1" ;;
        *)
            is_step "$1" || die "unknown step: $1 (try --list)"
            STEPS="$STEPS $1"
            ;;
    esac
    shift
done

# Normalise whitespace from the heredoc-style profile definitions, and run each
# step once even when profiles overlap (linux-base is inside the other two).
STEPS=$(echo "$STEPS" | tr -s '[:space:]' '\n' | sed '/^$/d' | awk '!seen[$0]++')
[ -n "$STEPS" ] || die "nothing to do (try --list)"

# linux-base and linux-server target accounts without sudo. Enforce it, so a
# step that grows a `sudo` fails loudly (under --dry-run too) instead of
# stopping at a password prompt on a server. linux-desktop lifts it.
case " $PROFILES " in
    *" linux-desktop "*) NO_SUDO=0 ;;
    *" linux-base "* | *" linux-server "*) NO_SUDO=1 ;;
    *) NO_SUDO=0 ;;
esac

# Validate everything up front, so a typo in a long profile fails immediately
# rather than half way through an install.
for s in $STEPS; do
    is_step "$s" || die "unknown step: $s (try --list)"
done

if [ "$DRY_RUN" = 1 ]; then
    info "dry run: no changes will be made"
fi
info "repo:  $DOTFILES"
info "steps: $(echo "$STEPS" | tr '\n' ' ')"

trap on_exit EXIT

# Ask for the password once, up front, rather than at whichever step first
# needs it -- possibly after a long unattended download.
case " $PROFILES " in
    *" linux-desktop "*) [ "$DRY_RUN" = 1 ] || sudo -v ;;
esac

for s in $STEPS; do
    run_step "$s"
done

printf '\nAll done.\n'
