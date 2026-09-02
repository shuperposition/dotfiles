return {
  {
    "nvim-mini/mini.nvim",
    config = function()
      -- hop-style label jumps: labels every spot, and automatically uses
      -- multi-character labels when candidates outnumber the label letters.
      require("mini.jump2d").setup({
        -- show upcoming label steps too, so the full 2-char label is visible
        -- up front (like hop) instead of one character at a time
        view = { n_steps_ahead = 2 },
        -- don't map <CR> in Normal mode (mini's default) — we drive jumps via gw/gl
        mappings = { start_jumping = "" },
      })
    end,
    keys = {
      -- go-to-word: jump to any word start on screen (HopWord equivalent)
      {
        "gw",
        mode = { "n", "x", "o" },
        function()
          local jump2d = require("mini.jump2d")
          jump2d.start(jump2d.builtin_opts.word_start)
        end,
        desc = "Jump to word (mini.jump2d)",
      },
      -- go-to-line: jump to the start of any visible line (HopLine equivalent)
      {
        "gl",
        mode = { "n", "x", "o" },
        function()
          local jump2d = require("mini.jump2d")
          jump2d.start(jump2d.builtin_opts.line_start)
        end,
        desc = "Jump to line (mini.jump2d)",
      },
    },
  },

  {
    "nvim-mini/mini.align",
    opts = {
      mappings = {
        start = "<leader>fa",
        start_with_preview = "<leader>fA",
      },
    },
  },
}
