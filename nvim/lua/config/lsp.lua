-- Enable LSP server(s). Each server's settings live in after/lsp/<name>.lua
-- (Neovim 0.11 native LSP config).
vim.lsp.enable("basedpyright")
vim.lsp.enable("bashls")
vim.lsp.enable("lua_ls")

-- Enable rounded borders in floating windows
vim.o.winborder = "rounded"
