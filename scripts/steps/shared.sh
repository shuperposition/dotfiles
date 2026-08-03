#!/usr/bin/env bash
#
# Steps that are identical on Linux and macOS.
#
# Each step is a `step_<name>` function. The dispatcher prints the surrounding
# "Started / Finished" banner, so steps only contain the work itself.

# Pinned versions, collected here so they are easy to find and bump.
NODE_VERSION="v20.19.6"
NVM_VERSION="v0.40.3"

# Link the editor configuration. Shared by every neovim install path.
link_editor_config() {
    link "$DOTFILES/nvim" "$HOME/.config/nvim"
    link "$DOTFILES/stylua" "$HOME/.config/stylua"
}

step_oh_my_zsh() {
    omz="$HOME/.oh-my-zsh"
    custom="${ZSH_CUSTOM:-$omz/custom}"

    if [ -d "$omz" ]; then
        info "oh-my-zsh already present at $omz"
    else
        run sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
            "" --unattended
    fi

    clone_or_pull https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"
    clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"
    clone_or_pull https://github.com/zsh-users/zsh-completions.git "$custom/plugins/zsh-completions"
    clone_or_pull https://github.com/esc/conda-zsh-completion.git "$custom/plugins/conda-zsh-completion"
    clone_or_pull https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k" --depth=1

    link "$DOTFILES/zsh/zshrc" "$HOME/.zshrc"

    # Machine-local overrides. Seeded once from the template and never
    # overwritten afterwards: this file is where per-machine settings live.
    copy_if_absent "$DOTFILES/zsh/zshlc.template" "$HOME/.zshlc"
}

step_oh_my_tmux() {
    clone_or_pull https://github.com/gpakosz/.tmux.git "$HOME/.oh-my-tmux"
    link "$HOME/.oh-my-tmux/.tmux.conf" "$HOME/.tmux.conf"
    link "$DOTFILES/tmux/tmux.conf.local" "$HOME/.tmux.conf.local"
}

step_ranger() {
    need_dir "$HOME/.config/ranger"
    for f in commands.py commands_full.py rc.conf rifle.conf scope.sh; do
        link "$DOTFILES/ranger/$f" "$HOME/.config/ranger/$f"
    done
}

step_fzf() {
    clone_or_pull https://github.com/junegunn/fzf.git "$HOME/.fzf" --depth=1
    run "$HOME/.fzf/install" --key-bindings --completion --no-update-rc
}

step_nvm() {
    if is_macos; then
        have brew || die "homebrew is required for the nvm step"
        run brew install nvm
        NVM_DIR="/opt/homebrew/opt/nvm"
    else
        if [ -s "$HOME/.nvm/nvm.sh" ]; then
            info "nvm already installed at ~/.nvm"
        else
            run bash -c \
                "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash"
        fi
        NVM_DIR="$HOME/.nvm"
    fi
    export NVM_DIR

    # Sourcing nvm.sh is all that is needed to get the `nvm` function.
    #
    # Do NOT source ~/.profile here. It ends in `exec zsh -l`, which replaces
    # this script's process, so everything after it — including the node
    # install below — silently never ran.
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        warn "nvm.sh not found under $NVM_DIR, skipping node install"
        return 0
    fi
    if [ "$DRY_RUN" = 1 ]; then
        info "[dry-run] nvm install $NODE_VERSION"
        return 0
    fi
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh"
    nvm install "$NODE_VERSION"
}

step_python() {
    run pip3 install -U pip pip-autoremove ipdb pdbpp
    link "$DOTFILES/pdb/pdbrc.py" "$HOME/.pdbrc.py"
}

step_ssh_config() {
    need_dir "$HOME/.ssh"
    copy_if_absent "$DOTFILES/ssh/config" "$HOME/.ssh/config"
    info "review ~/.ssh/config: the IdentityFile paths are examples"
}
