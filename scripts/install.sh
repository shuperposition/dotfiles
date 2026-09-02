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

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DRY_RUN=0
export DOTFILES DRY_RUN

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
# Named step sets, reproducing what the previous four install_*.sh files
# encoded. A case statement rather than an associative array, so this still
# works on the bash 3.2 that macOS ships.

profile_steps() {
    case "$1" in
        linux-base)
            echo "apt_update apt_general oh_my_zsh oh_my_tmux nerd_fonts gogh
                  ranger fzf bat lazygit nvm neovim"
            ;;
        linux-server)
            echo "oh_my_zsh oh_my_tmux ranger fzf lazygit nvm neovim
                  anaconda conda_packages"
            ;;
        linux-desktop)
            echo "desktop_general docker nvidia_driver nvidia_container_toolkit
                  python cpp java gvm tfenv spotify screenkey"
            ;;
        macos)
            echo "essentials terminal_utilities desktop_applications
                  iterm2_colors oh_my_zsh oh_my_tmux ranger fzf nvm neovim
                  anaconda aerospace python cpp"
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
    printf '\n >>> %s\n' "$name"
    "step_$name"
    printf ' <<< %s\n' "$name"
}

# --- argument parsing -------------------------------------------------------

STEPS=""
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
            export DRY_RUN
            ;;
        -p | --profile)
            [ $# -ge 2 ] || die "--profile needs a name"
            want=$(profile_steps "$2") || die "unknown profile: $2 (have: $ALL_PROFILES)"
            [ "$(profile_platform "$2")" = "$PLATFORM" ] ||
                die "profile '$2' cannot run on $PLATFORM"
            STEPS="$STEPS $want"
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

# Normalise whitespace from the heredoc-style profile definitions.
STEPS=$(echo "$STEPS" | tr -s '[:space:]' '\n' | sed '/^$/d')
[ -n "$STEPS" ] || die "nothing to do (try --list)"

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

for s in $STEPS; do
    run_step "$s"
done

printf '\nAll done.\n'
