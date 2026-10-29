#!/usr/bin/env bash
#
# Linux (Ubuntu/Debian) install steps.

# Pinned versions, collected here so they are easy to find and bump.
NERD_FONT_VERSION="v3.4.0"
ANACONDA_VERSION="2026.07-1"
LAZYGIT_VERSION="0.63.0"
GDU_VERSION="5.38.0"
STYLUA_VERSION="2.6.0"
GO_VERSION="go1.23.4"
DRAWIO_VERSION="24.1.0"

# --- base -------------------------------------------------------------------

step_apt_update() {
    run sudo apt update
    run sudo apt upgrade -y
    run sudo apt autoremove -y
}

step_apt_general() {
    run sudo apt install -y zsh tmux vim ranger ripgrep xsel xclip \
        git wget curl tree eza bat jq build-essential \
        htop nvtop glances neofetch trash-cli
    # Shell lint/format, used by the repo checks and by nvim (bashls, conform).
    run sudo apt install -y shellcheck shfmt
    run sudo apt install -y net-tools nmap
    run sudo apt install -y fcitx5 fcitx5-chewing fcitx5-mozc fcitx5-pinyin
    # Ubuntu ships bat as batcat because of a name clash. ranger's scope.sh
    # calls `bat`, and it does not see zshrc's alias.
    if [ -e /usr/bin/batcat ]; then
        link /usr/bin/batcat "$HOME/.local/bin/bat"
    fi
}

step_nerd_fonts() {
    need_dir "$HOME/.local/share/fonts/NerdFonts"
    tmp=$(mktempdir)
    fetch "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONT_VERSION/Hack.zip" \
        "$tmp/Hack.zip"
    run unzip -o "$tmp/Hack.zip" -d "$HOME/.local/share/fonts/NerdFonts"
    # An `x && y` tail would make this function return non-zero when x is
    # false, which under `set -e` aborts the whole run.
    if have fc-cache; then
        run fc-cache -f
    fi
}

step_gogh() {
    run sudo apt install -y dconf-cli uuid-runtime
    tmp=$(mktempdir)
    clone_or_pull https://github.com/Gogh-Co/Gogh.git "$tmp/gogh" --depth=1
    # Required by Gogh's installers when running under GNOME Terminal
    export TERMINAL=gnome-terminal
    run "$tmp/gogh/installs/gruvbox-dark.sh"
    run "$tmp/gogh/installs/gruvbox.sh"
}

step_lazygit() {
    # Installed under ~/.local/bin so the step needs no sudo and works the
    # same on a workstation and on a server account.
    need_dir "$HOME/.local/bin"
    v=$LAZYGIT_VERSION
    tmp=$(mktempdir)
    fetch "https://github.com/jesseduffield/lazygit/releases/download/v${v}/lazygit_${v}_Linux_$(arch_slug).tar.gz" \
        "$tmp/lazygit.tar.gz"
    run tar -C "$tmp" -xzf "$tmp/lazygit.tar.gz" lazygit
    run install -m 755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
}

step_stylua() {
    # Lua formatter, for `stylua --check nvim/` and conform's format-on-save
    # (Mason is deliberately not asked for it). Not in apt; the musl build is
    # static. ~/.local/bin, no sudo.
    need_dir "$HOME/.local/bin"
    case "$(arch_slug)" in
        x86_64) asset=stylua-linux-x86_64-musl ;;
        arm64) asset=stylua-linux-aarch64-musl ;;
    esac
    tmp=$(mktempdir)
    fetch "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/${asset}.zip" \
        "$tmp/stylua.zip"
    run unzip -o "$tmp/stylua.zip" stylua -d "$tmp"
    run install -m 755 "$tmp/stylua" "$HOME/.local/bin/stylua"
}

step_gdu() {
    # Disk usage browser (ncdu-like, parallel scan). ~/.local/bin, no sudo.
    need_dir "$HOME/.local/bin"
    case "$(arch_slug)" in
        x86_64) asset=gdu_linux_amd64_static ;;
        arm64) asset=gdu_linux_arm64 ;;
    esac
    tmp=$(mktempdir)
    fetch "https://github.com/dundee/gdu/releases/download/v${GDU_VERSION}/${asset}.tgz" \
        "$tmp/gdu.tgz"
    run tar -C "$tmp" -xzf "$tmp/gdu.tgz" "$asset"
    run install -m 755 "$tmp/$asset" "$HOME/.local/bin/gdu"
    link "$DOTFILES/gdu/gdu.yaml" "$HOME/.gdu.yaml"
}

step_neovim() {
    # One step for both architectures, chosen from uname -m.
    # Pinned to NEOVIM_VERSION; see scripts/steps/shared.sh for why.
    install_neovim_tarball linux
}

# Hand SSH logins over to zsh (and from there to tmux, see zsh/zshrc).
#
# The usual answer, `chsh -s $(which zsh)`, is unavailable on the servers this
# targets: chsh asks for the account password through PAM, and these accounts
# have none (key-only login) and no sudo. So the login shell stays bash, and
# bash is made to exec zsh instead.
#
# The hook goes in ~/.profile (or ~/.bash_profile, which bash prefers when it
# exists), not ~/.bashrc:
#   - ~/.profile is read by login shells only, i.e. exactly the shell sshd
#     starts. ~/.bashrc is read by every interactive bash, so a hook there also
#     hijacks a `bash` typed deliberately, subshells of editors, and so on.
#   - The block is appended at the end, after the stock PATH setup, so
#     ~/.local/bin (where zsh may live on a no-sudo box) is already searched.
# The block only fires for an interactive shell: `ssh host cmd`, scp and rsync
# get plain non-interactive bash and are not disturbed. If zsh is missing, or
# exec fails, login simply continues in bash.
#
# Re-runs find the markers and do nothing. To undo, delete the marked block.
step_login_shell() {
    target="$HOME/.profile"
    if [ -e "$HOME/.bash_profile" ]; then
        target="$HOME/.bash_profile"
    fi

    if [ -f "$target" ] && grep -q '>>> dotfiles login shell >>>' "$target"; then
        info "login-shell hook already present in $target"
    else
        tmp=$(mktempdir)
        cat > "$tmp/block" << 'EOF'

# >>> dotfiles login shell >>>
# Managed by dotfiles/scripts (step_login_shell). Interactive login shells
# become zsh; chsh is not available without a password.
case $- in
    *i*)
        if [ -z "${ZSH_VERSION:-}" ] && command -v zsh > /dev/null 2>&1; then
            SHELL=$(command -v zsh)
            export SHELL
            exec zsh -l
        fi
        ;;
esac
# <<< dotfiles login shell <<<
EOF
        run bash -c 'cat "$1" >> "$2"' _ "$tmp/block" "$target"
        [ "$DRY_RUN" = 1 ] || info "added login-shell hook to $target"
    fi

    # Older setups put an unconditional `exec zsh -l` in ~/.bashrc. It is
    # harmless next to the hook above (ZSH_VERSION guards the second exec), but
    # it keeps hijacking non-login interactive bash. It is a hand-edited file,
    # so say so rather than rewrite it.
    if [ -f "$HOME/.bashrc" ] && grep -q 'exec zsh' "$HOME/.bashrc"; then
        warn "~/.bashrc also execs zsh; remove that block to let non-login bash stay bash"
    fi
}

# Make zsh the account's real login shell, on machines with sudo (desktops).
#
# login_shell above only catches interactive *login* shells, and GNOME Terminal
# starts non-login ones, so on a desktop terminals would stay bash. With sudo,
# chsh works; `sudo chsh` asks for the sudo password instead of going through
# chsh's own PAM prompt. Not for linux-server: no sudo there.
step_default_shell() {
    if ! have zsh; then
        warn "zsh not found, skipping (run apt_general first)"
        return 0
    fi
    zsh_path=$(command -v zsh)
    current=$(getent passwd "$USER" | cut -d: -f7)
    if [ "$current" = "$zsh_path" ]; then
        info "login shell is already $zsh_path"
        return 0
    fi
    grep -qx "$zsh_path" /etc/shells ||
        run sudo sh -c 'echo "$1" >> /etc/shells' _ "$zsh_path"
    run sudo chsh -s "$zsh_path" "$USER"
    [ "$DRY_RUN" = 1 ] || info "login shell changed to $zsh_path; log out and back in"
}

# --- conda ------------------------------------------------------------------

step_anaconda() {
    if [ -d "$HOME/anaconda3" ]; then
        info "anaconda already installed at ~/anaconda3"
        return 0
    fi
    installer="Anaconda3-${ANACONDA_VERSION}-Linux-$(uname -m).sh"
    tmp=$(mktempdir)
    fetch "https://repo.anaconda.com/archive/${installer}" "$tmp/${installer}"
    run bash "$tmp/${installer}" -b -p "$HOME/anaconda3"
}

step_conda_packages() {
    root=$(conda_root) || die "no conda found (run the anaconda step first)"
    run "$root/bin/conda" install --override-channels -c conda-forge -y \
        xsel tree eza bat nvtop fastfetch
    run "$root/bin/pip" install ranger-fm trash-cli
}

# --- desktop ----------------------------------------------------------------

step_desktop_general() {
    run sudo apt install -y vlc chromium-browser \
        gnome-shell-extension-manager chrome-gnome-shell
    info 'open "Extension Manager" and search for "Tiling Shell"'
}

step_docker() {
    tmp=$(mktempdir)
    clone_or_pull https://github.com/docker/docker-install.git "$tmp/docker-install" --depth=1
    run sh "$tmp/docker-install/install.sh"
    run sudo docker run --rm hello-world
}

# ranger-root wrapper that runs ranger as root in a container on $PWD. Builds
# the image only when missing, so re-runs do not rebuild it.
step_ranger_docker() {
    if ! have docker; then
        warn "docker not found, skipping"
        return 0
    fi
    image="nvidia/cuda:12.8.1-base-ubuntu24.04-sm"
    docker image inspect "$image" > /dev/null 2>&1 ||
        run docker build -t "$image" "$DOTFILES/ranger/docker"
    link "$DOTFILES/ranger/ranger-root" "$HOME/.local/bin/ranger-root"
}

# Optional: in no profile. It switches to the recommended driver (often a newer
# -open variant), so only run it by name when you mean to change drivers.
step_nvidia_driver() {
    driver=$(ubuntu-drivers devices | awk '/recommended/ {print $3}')
    [ -n "$driver" ] || die "no recommended NVIDIA driver found"
    info "installing $driver"
    run sudo apt install -y "$driver"
}

step_nvidia_container_toolkit() {
    run sudo apt-get update
    run sudo apt-get install -y --no-install-recommends curl gnupg2
    run bash -c 'curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |
        sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg'
    run bash -c 'curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
        sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" |
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list'
    run sudo apt-get update
    run sudo apt-get install -y nvidia-container-toolkit
    run sudo nvidia-ctk runtime configure --runtime=docker
    run sudo systemctl restart docker
    run sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
}

# --- development ------------------------------------------------------------

step_cpp() {
    run sudo apt install -y clang clang-format clang-tidy clangd \
        gcc g++ gdb libstdc++-12-dev llvm lldb
    link "$DOTFILES/gdb/gdbinit" "$HOME/.gdbinit"
    link "$DOTFILES/clang-format/clang-format-ubuntu.yml" "$HOME/.clang-format"
    # gdb-dashboard needs pygments.
    if root=$(conda_root); then
        run "$root/bin/pip" install -U pygments
    else
        warn "no conda found, skipping pygments for gdb-dashboard"
    fi
}

step_java() {
    run sudo apt install -y default-jre default-jdk maven
}

step_gvm() {
    run sudo apt install -y bison
    if [ -d "$HOME/.gvm" ]; then
        info "gvm already installed at ~/.gvm"
    else
        run bash -c \
            'curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | GVM_NO_UPDATE_PROFILE=1 bash'
    fi
    if [ "$DRY_RUN" = 1 ]; then
        info "[dry-run] gvm install $GO_VERSION -B && gvm use $GO_VERSION --default"
        return 0
    fi
    # shellcheck disable=SC1091
    . "$HOME/.gvm/scripts/gvm"
    gvm install "$GO_VERSION" -B
    gvm use "$GO_VERSION" --default
}

step_tfenv() {
    clone_or_pull https://github.com/tfutils/tfenv.git "$HOME/.tfenv" --depth=1
    need_dir "$HOME/.local/bin"
    for f in "$HOME"/.tfenv/bin/*; do
        link "$f" "$HOME/.local/bin/$(basename "$f")"
    done
}

# --- desktop applications ---------------------------------------------------

# Claude desktop app (Linux beta), from Anthropic's apt repository so updates
# arrive with apt upgrade: https://code.claude.com/docs/en/desktop-linux
# The key is checked against the documented fingerprint before apt trusts it;
# a temporary GNUPGHOME keeps the check from creating ~/.gnupg.
CLAUDE_DESKTOP_KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"

step_claude_desktop() {
    keyring=/usr/share/keyrings/claude-desktop-archive-keyring.asc
    list=/etc/apt/sources.list.d/claude-desktop.list
    if [ -f "$keyring" ]; then
        info "signing key already at $keyring"
    else
        tmp=$(mktempdir)
        fetch https://downloads.claude.ai/claude-desktop/key.asc "$tmp/key.asc"
        if [ "$DRY_RUN" != 1 ]; then
            fpr=$(GNUPGHOME="$tmp" gpg --show-keys --with-colons "$tmp/key.asc" |
                awk -F: '/^fpr/ {print $10; exit}') || fpr=""
            [ "$fpr" = "$CLAUDE_DESKTOP_KEY_FPR" ] ||
                die "claude-desktop key fingerprint is '$fpr', expected $CLAUDE_DESKTOP_KEY_FPR"
        fi
        run sudo install -m 644 "$tmp/key.asc" "$keyring"
    fi
    if [ ! -f "$list" ]; then
        run bash -c 'echo "deb [arch=amd64,arm64 signed-by=$1] https://downloads.claude.ai/claude-desktop/apt/stable stable main" |
            sudo tee "$2" > /dev/null' _ "$keyring" "$list"
    fi
    run sudo apt update
    run sudo apt install -y claude-desktop

    # Cowork runs tasks in a QEMU/KVM VM and needs /dev/vhost-vsock, which
    # only the kvm group can open. Takes effect at the next login.
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx kvm; then
        run sudo usermod -aG kvm "$USER"
        [ "$DRY_RUN" = 1 ] || info "added $USER to kvm (for Cowork); log out and back in"
    fi
}

step_spotify() { run sudo snap install spotify; }
step_screenkey() { run sudo apt install -y screenkey; }

step_mechatronics() {
    run sudo apt install -y kicad kicad-packages3d openscad freecad blender libreoffice
}

step_drawio() {
    # Release notes: https://github.com/jgraph/drawio-desktop/releases/
    deb="drawio-amd64-${DRAWIO_VERSION}.deb"
    tmp=$(mktempdir)
    fetch "https://github.com/jgraph/drawio-desktop/releases/download/v${DRAWIO_VERSION}/${deb}" \
        "$tmp/${deb}"
    run sudo apt install -y "$tmp/${deb}"
}
