#!/usr/bin/env bash
#
# Linux (Ubuntu/Debian) install steps, grouped by the profile that uses them.

# Pinned versions, collected here so they are easy to find and bump.
NERD_FONT_VERSION="v3.5.1"
ANACONDA_VERSION="2026.07-1"
LAZYGIT_VERSION="0.66.2"
GDU_VERSION="5.38.0"
STYLUA_VERSION="2.6.0"
DRAWIO_VERSION="32.6.1"

# --- linux-base: terminal environment, no sudo -------------------------------

# What a no-sudo account has to be given by its admin: linux-base installs
# everything else under $HOME, but cannot install these. On a desktop,
# apt_general (earlier in linux-desktop) provides them.
step_prerequisites() {
    missing=""
    for c in zsh tmux git curl tar unzip; do
        have "$c" || missing="$missing $c"
    done
    [ -z "$missing" ] && return 0
    # A dry run of linux-desktop on a fresh machine never ran apt_general.
    if [ "$DRY_RUN" = 1 ]; then
        warn "missing:$missing (fine if apt_general runs first)"
        return 0
    fi
    die "missing:$missing -- ask the admin, or on a desktop run apt_general"
}

# Hand SSH logins over to zsh (and from there to tmux, see zsh/zshrc).
#
# The usual answer, `chsh -s $(which zsh)`, is unavailable on the accounts
# linux-base targets: chsh asks for the account password through PAM, and
# these accounts have none (key-only login) and no sudo. So the login shell
# stays bash, and bash is made to exec zsh instead.
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
        warn "$HOME/.bashrc also execs zsh; remove that block to let non-login bash stay bash"
    fi
}

# lazygit, stylua and gdu are static release binaries installed into
# ~/.local/bin, so they need no sudo and are the same on a desktop and a server.
step_lazygit() {
    need_dir "$HOME/.local/bin"
    v=$LAZYGIT_VERSION
    tmp=$(mktempdir)
    fetch "https://github.com/jesseduffield/lazygit/releases/download/v${v}/lazygit_${v}_Linux_$(arch_slug).tar.gz" \
        "$tmp/lazygit.tar.gz"
    run tar -C "$tmp" -xzf "$tmp/lazygit.tar.gz" lazygit
    run install -m 755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
}

# Lua formatter, for `stylua --check nvim/` and conform's format-on-save
# (Mason is deliberately not asked for it). The musl build is static.
step_stylua() {
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

# Disk usage browser (ncdu-like, parallel scan).
step_gdu() {
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

# Pinned to NEOVIM_VERSION; see scripts/steps/shared.sh for why.
step_neovim() {
    install_neovim_tarball linux
}

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

# The everyday terminal tools, into conda base: the one place linux-base can
# install binaries without sudo. zshrc activates base in every shell, so they
# are on PATH there and in whatever it starts (nvim's conform, ranger).
# The linters (shellcheck, shfmt) serve the repo checks and nvim (bashls, conform).
step_conda_packages() {
    if [ "$DRY_RUN" = 1 ]; then
        root=$(conda_root) || root="$HOME/anaconda3"
    else
        root=$(conda_root) || die "no conda found (run the anaconda step first)"
    fi
    run "$root/bin/conda" install --override-channels -c conda-forge -y \
        ripgrep fd-find jq tree eza bat xsel nvtop fastfetch glances \
        shellcheck go-shfmt
    run "$root/bin/pip" install ranger-fm trash-cli
}

# --- linux-server ------------------------------------------------------------

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

# --- linux-desktop: system, before linux-base --------------------------------

step_apt_update() {
    run sudo apt update
    run sudo apt upgrade -y
    run sudo apt autoremove -y
}

# What linux-base needs to exist already (step_prerequisites), plus clipboard
# and networking. Everyday terminal tools come from conda_packages instead, so
# a server gets the same set without sudo.
step_apt_general() {
    run sudo apt install -y zsh tmux vim git wget curl tar unzip build-essential \
        xclip htop net-tools nmap
    # For gogh, whose GNOME Terminal installers drive dconf.
    run sudo apt install -y dconf-cli uuid-runtime
}

# Make zsh the account's real login shell.
#
# login_shell only catches interactive *login* shells, and GNOME Terminal
# starts non-login ones, so on a desktop terminals would stay bash. With sudo,
# chsh works; `sudo chsh` asks for the sudo password instead of going through
# chsh's own PAM prompt. Desktop only: linux-base and linux-server have no sudo.
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

# --- linux-desktop: display, after linux-base --------------------------------

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

# GNOME Terminal colours. dconf-cli and uuid-runtime come from apt_general.
step_gogh() {
    tmp=$(mktempdir)
    clone_or_pull https://github.com/Gogh-Co/Gogh.git "$tmp/gogh" --depth=1
    # Required by Gogh's installers when running under GNOME Terminal
    export TERMINAL=gnome-terminal
    run "$tmp/gogh/installs/gruvbox-dark.sh"
    run "$tmp/gogh/installs/gruvbox-light.sh"
}

step_desktop_general() {
    run sudo apt install -y vlc chromium-browser \
        gnome-shell-extension-manager chrome-gnome-shell
}

# Add or remove one UUID in an org.gnome.shell string list (enabled-extensions,
# disabled-extensions). gsettings rather than `gnome-extensions enable`: that
# goes through the running shell, which does not know about an extension
# installed in this session until the next login.
# $1 = add|remove, $2 = key, $3 = uuid
shell_ext_list() {
    cur=$(gsettings get org.gnome.shell "$2")
    case "$1" in
        add)
            case "$cur" in *"'$3'"*) return 0 ;; esac
            case "$cur" in
                "@as []" | "[]") new="['$3']" ;;
                *) new="${cur%]}, '$3']" ;;
            esac
            ;;
        remove)
            case "$cur" in *"'$3'"*) ;; *) return 0 ;; esac
            new=$(printf '%s' "$cur" | sed "s/'${3//./\\.}'//; s/, ,/,/; s/\[, /[/; s/, \]/]/")
            [ "$new" != "[]" ] || new="@as []"
            ;;
    esac
    run gsettings set org.gnome.shell "$2" "$new"
}

# Tiling Shell, with the settings in tilingshell/tilingshell-settings.txt.
#
# Not pinned: extensions.gnome.org serves a different build per GNOME version,
# so the build is looked up for the running shell (a read-only query, made
# under --dry-run too). An installed copy is left alone; update it from
# Extension Manager. Settings are loaded only while the extension has none, so
# a re-run does not undo changes made in its preferences window.
TILING_SHELL_UUID="tilingshell@ferrarodomenico.com"

step_tiling_shell() {
    if ! have gnome-shell; then
        warn "gnome-shell not found, skipping"
        return 0
    fi
    uuid=$TILING_SHELL_UUID
    if [ -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]; then
        info "$uuid already installed"
    else
        shell=$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)
        path=$(curl -fsS "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$shell" |
            sed -n 's/.*"download_url": *"\([^"]*\)".*/\1/p') || path=""
        [ -n "$path" ] || die "no Tiling Shell build for GNOME $shell on extensions.gnome.org"
        tmp=$(mktempdir)
        fetch "https://extensions.gnome.org$path" "$tmp/tilingshell.zip"
        run gnome-extensions install --force "$tmp/tilingshell.zip"
    fi

    # Ubuntu's own tiler snaps windows too, and the two fight over the edges.
    shell_ext_list remove enabled-extensions tiling-assistant@ubuntu.com
    shell_ext_list add disabled-extensions tiling-assistant@ubuntu.com
    run gsettings set org.gnome.shell disable-user-extensions false
    shell_ext_list remove disabled-extensions "$uuid"
    shell_ext_list add enabled-extensions "$uuid"

    if [ -n "$(dconf dump /org/gnome/shell/extensions/tilingshell/)" ]; then
        info "Tiling Shell settings already present, leaving them alone"
    else
        run dconf load /org/gnome/shell/extensions/tilingshell/ \
            < "$DOTFILES/tilingshell/tilingshell-settings.txt"
    fi
    [ "$DRY_RUN" = 1 ] || info "log out and back in (on X11, Alt+F2 r) to start Tiling Shell"
}

# fcitx5 with Japanese (mozc) and Chinese (chewing, pinyin), replacing IBus.
# im-config only writes ~/.xinputrc; the switch takes effect at next login.
# fcitx5 rewrites its profile when you change input methods in its settings,
# so it is seeded once rather than linked.
step_input_method() {
    run sudo apt install -y fcitx5 fcitx5-config-qt fcitx5-frontend-all \
        fcitx5-mozc fcitx5-chewing fcitx5-pinyin
    if [ -f "$HOME/.xinputrc" ] && grep -q 'run_im fcitx5' "$HOME/.xinputrc"; then
        info "input method is already fcitx5"
    else
        run im-config -n fcitx5
        [ "$DRY_RUN" = 1 ] || info "input method set to fcitx5; log out and back in"
    fi
    need_dir "$HOME/.config/fcitx5"
    copy_if_absent "$DOTFILES/fcitx5/profile" "$HOME/.config/fcitx5/profile"
}

# Docker's convenience script. Skipped when docker is present: on a re-run the
# script stops to warn about the existing install, and apt upgrades it anyway.
step_docker() {
    if have docker; then
        info "docker already installed"
    else
        tmp=$(mktempdir)
        clone_or_pull https://github.com/docker/docker-install.git "$tmp/docker-install" --depth=1
        run sh "$tmp/docker-install/install.sh"
    fi
    run sudo docker run --rm hello-world
}

# Needs docker (step_docker, earlier in linux-desktop): it restarts the daemon.
# gpg --yes so that a re-run replaces the keyring instead of stopping to ask.
step_nvidia_container_toolkit() {
    run sudo apt-get update
    run sudo apt-get install -y --no-install-recommends curl gnupg2
    run bash -c 'curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey |
        sudo gpg --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg'
    run bash -c 'curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
        sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" |
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list'
    run sudo apt-get update
    run sudo apt-get install -y nvidia-container-toolkit
    run sudo nvidia-ctk runtime configure --runtime=docker
    run sudo systemctl restart docker
    run sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
}

# --- linux-desktop: development ----------------------------------------------

# Runs after linux-base, so conda is there for gdb-dashboard's pygments.
step_cpp() {
    run sudo apt install -y clang clang-format clang-tidy clangd \
        gcc g++ gdb libstdc++-12-dev llvm lldb
    link "$DOTFILES/gdb/gdbinit" "$HOME/.gdbinit"
    link "$DOTFILES/clang-format/clang-format-ubuntu.yml" "$HOME/.clang-format"
    if root=$(conda_root); then
        run "$root/bin/pip" install -U pygments
    else
        warn "no conda found, skipping pygments for gdb-dashboard"
    fi
}

step_java() {
    run sudo apt install -y default-jre default-jdk maven
}

# Not pinned: tfenv tracks its master branch; it pins terraform per project.
step_tfenv() {
    clone_or_pull https://github.com/tfutils/tfenv.git "$HOME/.tfenv" --depth=1
    need_dir "$HOME/.local/bin"
    for f in tfenv terraform; do
        link "$HOME/.tfenv/bin/$f" "$HOME/.local/bin/$f"
    done
}

# --- linux-desktop: applications ---------------------------------------------

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

# --- optional: in no profile, run by name ------------------------------------

# Switches to the recommended driver (often a newer -open variant), which can
# replace a working one, so only run it when you mean to change drivers.
step_nvidia_driver() {
    driver=$(ubuntu-drivers devices | awk '/recommended/ {print $3}')
    [ -n "$driver" ] || die "no recommended NVIDIA driver found"
    info "installing $driver"
    run sudo apt install -y "$driver"
}

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
