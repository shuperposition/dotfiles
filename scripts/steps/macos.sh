#!/usr/bin/env bash
#
# macOS install steps.

# Pinned versions, collected here so they are easy to find and bump.
GO_VERSION="go1.27.1"

step_brew_update() {
    run brew update
    run brew upgrade
    run brew cleanup
}

step_essentials() {
    run xcode-select --install || info "Xcode command line tools already installed"
    run softwareupdate --install-rosetta --agree-to-license
    if have brew; then
        info "homebrew already installed"
    else
        run bash -c \
            '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    fi
}

step_terminal_utilities() {
    run brew install zsh tmux vim ranger \
        git lazygit wget curl tree eza bat jq \
        htop glances watch trash-cli
}

step_desktop_applications() {
    run brew install --cask google-chrome firefox spotify vlc \
        iterm2 docker visual-studio-code notion drawio \
        steam battle-net claude
}

step_iterm2_colors() {
    run brew install --cask font-hack-nerd-font
    tmp=$(mktempdir)
    clone_or_pull https://github.com/mbadolato/iTerm2-Color-Schemes.git \
        "$tmp/iTerm2-Color-Schemes" --depth=1
    run "$tmp/iTerm2-Color-Schemes/tools/import-scheme.sh" 'schemes/Gruvbox Dark.itermcolors'
    run "$tmp/iTerm2-Color-Schemes/tools/import-scheme.sh" 'schemes/Gruvbox Light.itermcolors'
}

step_neovim() {
    # Homebrew has no versioned neovim formula, so nvim comes from the pinned
    # upstream tarball (see NEOVIM_VERSION in shared.sh); the companion tools
    # still come from brew.
    run brew install ripgrep fd
    # A brew-installed neovim sits in /opt/homebrew/bin and shadows
    # ~/.local/bin on PATH, which silently defeats the pin. Remove it rather
    # than leave a note asking someone to remember.
    if brew list --formula neovim > /dev/null 2>&1; then
        run brew uninstall neovim
    fi
    install_neovim_tarball macos
}

step_anaconda() {
    run brew install --cask anaconda
    info "conda is picked up automatically by zsh/zshrc from /opt/homebrew/anaconda3"
}

step_aerospace() {
    run brew install --cask nikitabobko/tap/aerospace
    link "$DOTFILES/aerospace/aerospace.toml" "$HOME/.config/aerospace/aerospace.toml"
}

step_gvm() {
    run brew install bison mercurial
    if [ -d "$HOME/.gvm" ]; then
        info "gvm already installed at ~/.gvm"
    else
        # ~/.zshrc is a symlink into this repo; zsh/zshrc sources gvm itself.
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

step_cpp() {
    run brew install llvm lldb clang-format clangd gcc
    link "$DOTFILES/clang-format/clang-format-macos.yml" "$HOME/.clang-format"
}
