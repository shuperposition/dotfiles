-- NOTE: [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear highlights on search" })

-- Buffer and tab management
vim.keymap.set("n", "<leader>w", "<cmd>bd<CR>", { desc = "Close window" })
vim.keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit window" })
vim.keymap.set("n", "<leader>t", "<cmd>tabnew<CR>", { desc = "Create new tab" })
vim.keymap.set("n", "<leader>s", "<cmd>w<CR>", { desc = "Write to buffer" })

-- Diff mode
vim.keymap.set("n", "<leader>d", "<cmd>diffthis<CR>", { desc = "Diff this buffer" })
vim.keymap.set("n", "<leader>D", "<cmd>diffoff<CR>", { desc = "Diff mode off" })

-- Check
vim.keymap.set("n", "<leader>cf", "<cmd>echo expand('%p')<CR>", { desc = "Check current file path" })
vim.keymap.set("n", "<leader>ch", "<cmd>checkhealth<CR>", { desc = "[C]heck [H]ealth" })
vim.keymap.set("n", "<leader>cl", "<cmd>Lazy<CR>", { desc = "[C]heck [L]azy" })
vim.keymap.set("n", "<leader>cm", "<cmd>Mason<CR>", { desc = "[C]heck [M]ason" })

-- LSP
vim.keymap.set("n", "<S-l>", vim.lsp.buf.hover, { desc = "LSP Hover" })
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "LSP Definition" })

-- Diagnostic
-- goto_next/goto_prev are deprecated since nvim 0.11 and slated for removal
vim.keymap.set("n", "gJ", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Diagnostic next" })
vim.keymap.set("n", "gK", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Diagnostic previous" })

-- Move lines
vim.keymap.set("n", "<S-j>", "<cmd>m +1<CR>", { desc = "Move line down" })
vim.keymap.set("n", "<S-k>", "<cmd>m -2<CR>", { desc = "Move line up" })

-- Switch between windows
vim.keymap.set("n", "<leader>h", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<leader>l", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<leader>j", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<leader>k", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- Resize window
vim.keymap.set("n", "<C-h>", "<cmd>vertical resize +2<CR>", { desc = "Widen window" })
vim.keymap.set("n", "<C-l>", "<cmd>vertical resize -2<CR>", { desc = "Narrow window" })
vim.keymap.set("n", "<C-k>", "<cmd>horizontal resize +2<CR>", { desc = "Heighten window" })
vim.keymap.set("n", "<C-j>", "<cmd>horizontal resize -2<CR>", { desc = "Shorten window" })
