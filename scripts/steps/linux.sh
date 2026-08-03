#!/usr/bin/env bash
#
# Linux (Ubuntu/Debian) install steps.

# Pinned versions, collected here so they are easy to find and bump.
NERD_FONT_VERSION="v3.4.0"
ANACONDA_VERSION="2025.06-0"
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
    run sudo apt install -y net-tools nmap
    run sudo apt install -y fcitx5 fcitx5-chewing fcitx5-mozc fcitx5-pinyin
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
    clone_or_pull https://github.com/Gogh-Co/Gogh.git "$HOME/gogh" --depth=1
    # Required by Gogh's installers when running under GNOME Terminal
    export TERMINAL=gnome-terminal
    run "$HOME/gogh/installs/gruvbox-dark.sh"
    run "$HOME/gogh/installs/gruvbox.sh"
    run rm -rf "$HOME/gogh"
}

step_bat() {
    run sudo apt install -y bat
    # Ubuntu ships the binary as batcat because of a name clash. Provide a
    # `bat` on PATH. need_dir first: ~/.local/bin may not exist yet.
    need_dir "$HOME/.local/bin"
    if [ -e /usr/bin/batcat ]; then
        link /usr/bin/batcat "$HOME/.local/bin/bat"
    fi
}

step_lazygit() {
    # Installed under ~/.local/bin so the step needs no sudo and works the
    # same on a workstation and on a server account.
    need_dir "$HOME/.local/bin"
    version=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" |
        grep -Po '"tag_name": *"v\K[^"]*')
    [ -n "$version" ] || die "could not determine the latest lazygit version"
    info "installing lazygit $version"
    tmp=$(mktempdir)
    fetch "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_x86_64.tar.gz" \
        "$tmp/lazygit.tar.gz"
    run tar -C "$tmp" -xzf "$tmp/lazygit.tar.gz" lazygit
    run install -m 755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
}

step_neovim() {
    # One step for both architectures, chosen from uname -m.
    # Pinned to NEOVIM_VERSION; see scripts/steps/shared.sh for why.
    install_neovim_tarball linux
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

step_miniconda() {
    case "$(uname -m)" in
        x86_64) installer="Miniconda3-latest-Linux-x86_64.sh" ;;
        aarch64 | arm64) installer="Miniconda3-latest-Linux-aarch64.sh" ;;
        *) die "unsupported architecture: $(uname -m)" ;;
    esac
    if [ -d "$HOME/miniconda3" ]; then
        info "miniconda already installed at ~/miniconda3"
        return 0
    fi
    tmp=$(mktempdir)
    fetch "https://repo.anaconda.com/miniconda/${installer}" "$tmp/${installer}"
    run bash "$tmp/${installer}" -b -p "$HOME/miniconda3"
}

step_conda_packages() {
    [ -f "$HOME/anaconda3/bin/conda" ] || die "anaconda not found at ~/anaconda3"
    run "$HOME/anaconda3/bin/conda" install -c conda-forge -y \
        xsel tree eza bat nvtop fastfetch
    run "$HOME/anaconda3/bin/pip" install ranger-fm trash-cli
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
    # gdb-dashboard needs pygments. Use whichever pip3 is on PATH; the old
    # hardcoded ~/.pyenv/shims/pip3 pointed at a pyenv nothing here installs.
    run pip3 install -U pygments
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
            'curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | bash'
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
