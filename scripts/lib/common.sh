#!/usr/bin/env bash
#
# Shared helpers for the install steps.
#
# Every helper that touches the system goes through run(), so that --dry-run
# prints what would happen without doing it. Every helper is safe to call
# twice: re-running a step must be a no-op, not an error.

# Repository root. install.sh exports this; default for direct sourcing.
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
DRY_RUN="${DRY_RUN:-0}"

# --- output -----------------------------------------------------------------

info() { printf '     %s\n' "$*"; }
warn() { printf '     warning: %s\n' "$*" >&2; }
die() {
    printf ' !!! %s\n' "$*" >&2
    exit 1
}

# Run a command, or describe it under --dry-run.
run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '     [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

# --- predicates -------------------------------------------------------------

have() { command -v "$1" > /dev/null 2>&1; }
is_macos() { [ "$(uname)" = Darwin ]; }
is_linux() { [ "$(uname)" = Linux ]; }

# Architecture slug as used by upstream release tarballs.
arch_slug() {
    case "$(uname -m)" in
        x86_64 | amd64) printf 'x86_64' ;;
        aarch64 | arm64) printf 'arm64' ;;
        *) die "unsupported architecture: $(uname -m)" ;;
    esac
}

# --- filesystem -------------------------------------------------------------

# Create a directory and its parents if it does not already exist.
need_dir() { [ -d "$1" ] || run mkdir -p "$1"; }

# Symlink src -> dst, creating the parent directory first.
# Replaces an existing symlink, but refuses to clobber a real file.
link() {
    src=$1
    dst=$2
    if [ ! -e "$src" ]; then
        warn "link source missing, skipping: $src"
        return 0
    fi
    need_dir "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "$dst exists and is not a symlink, leaving it alone"
        return 0
    fi
    run ln -sfn "$src" "$dst"
    [ "$DRY_RUN" = 1 ] || info "linked $dst -> $src"
}

# Copy src -> dst only when dst does not exist.
#
# Used for machine-local files that the repo seeds once and the user then edits
# in place. A plain `cp` here would silently destroy those local edits on every
# re-run, which is exactly the bug this replaces.
copy_if_absent() {
    src=$1
    dst=$2
    if [ -e "$dst" ]; then
        info "$dst already exists, leaving your local copy untouched"
        return 0
    fi
    run cp "$src" "$dst"
    [ "$DRY_RUN" = 1 ] || info "seeded $dst from $src"
}

# Clone a repo, or fast-forward it if the checkout is already present.
# Extra arguments (e.g. --depth=1) are passed to git clone.
clone_or_pull() {
    url=$1
    dest=$2
    shift 2
    if [ -d "$dest/.git" ]; then
        info "updating $dest"
        run git -C "$dest" pull --ff-only || warn "could not fast-forward $dest"
    elif [ -e "$dest" ]; then
        warn "$dest exists but is not a git checkout, skipping"
    else
        run git clone "$@" "$url" "$dest"
    fi
}

# Scratch space for this run, removed on exit however the script exits.
# Steps download here rather than into $HOME or the current directory.
#
# One root created up front, with mktempdir() handing out subdirectories of it.
# Collecting paths in a variable instead would not work: steps call mktempdir
# via `tmp=$(mktempdir)`, and a command substitution runs in a subshell, so any
# bookkeeping it did would be discarded before the trap ever saw it.
SCRATCH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install.XXXXXX")"

cleanup_scratch() {
    if [ -n "${SCRATCH_ROOT:-}" ] && [ -d "$SCRATCH_ROOT" ]; then
        rm -rf "$SCRATCH_ROOT"
    fi
    return 0
}
trap cleanup_scratch EXIT INT TERM

mktempdir() { mktemp -d "$SCRATCH_ROOT/step.XXXXXX"; }

# Download a URL to a path.
# Usage: tmp=$(mktempdir); fetch <url> "$tmp/file"
fetch() { run curl -fsSL -o "$2" "$1"; }
