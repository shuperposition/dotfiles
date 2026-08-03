#!/usr/bin/env bash
#
# macOS install steps.

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
        steam battle-net
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
    # still come from brew. If a brew-installed nvim shadows ~/.local/bin on
    # PATH, `brew uninstall neovim` once.
    run brew install ripgrep fd lazygit
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

step_cpp() {
    run brew install llvm lldb clang-format clangd gcc
    link "$DOTFILES/clang-format/clang-format-macos.yml" "$HOME/.clang-format"
}
