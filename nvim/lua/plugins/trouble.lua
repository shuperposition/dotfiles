return {
  {
    "folke/trouble.nvim",
    opts = {},
    cmd = "Trouble",
    keys = {
      { "<leader>xX", "<cmd>Trouble diagnostics toggle<CR>", desc = "[D]iagnostics [R]oot" },
      { "<leader>xx", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "[D]iagnostics [B]uffer" },
      { "<leader>xS", "<cmd>Trouble symbols toggle focus=false<CR>", desc = "[D]iagnostics [S]ymbols" },
    },
  },
}
