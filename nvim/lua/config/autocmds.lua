-- Highlight when yanking text
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Demo command from following the "write your first plugin" guide.
-- Kept only to preserve existing behaviour; safe to delete.
vim.api.nvim_create_user_command("HelloWorld", function()
  print("Hello, World from my first plugin!")
end, {
  nargs = 0,
  desc = "Prints a greeting",
})
