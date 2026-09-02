return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- master is the last branch supporting Neovim <= 0.11; it breaks on 0.12,
    -- which is why the editor is pinned (see NEOVIM_VERSION in
    -- scripts/steps/shared.sh). Moving to `main` means dropping
    -- nvim-treesitter.configs, ensure_installed, auto_install, highlight and
    -- indent entirely, and needs tree-sitter-cli >= 0.26.1.
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "diff",
        "html",
        "lua",
        "luadoc",
        "python",
        "markdown",
        "markdown_inline",
        "query",
        "vim",
        "vimdoc",
      },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
      indent = { enable = true },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
