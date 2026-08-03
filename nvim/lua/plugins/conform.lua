return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    -- FormatDisable/FormatEnable are defined in config() below, so they must
    -- be declared here too, otherwise lazy.nvim has not loaded the plugin yet
    -- and calling them reports "Not an editor command".
    cmd = { "ConformInfo", "FormatDisable", "FormatEnable" },
    opts = {
      notify_on_error = false,
      -- Must be a function, not a plain `false`: the :FormatDisable and
      -- :FormatEnable commands below work by setting these variables, and a
      -- static value would mean nothing ever reads them.
      format_on_save = function(bufnr)
        if vim.b[bufnr].disable_autoformat or vim.g.disable_autoformat then
          return
        end
        return { timeout_ms = 500, lsp_format = "fallback" }
      end,
      formatters_by_ft = {
        -- Shell formatter
        sh = { "shfmt" },
        zsh = { "shfmt" },
        bash = { "shfmt" },
        -- Lua formatter
        lua = { "stylua" },
        -- Conform can also run multiple formatters sequentially
        python = { "isort", "black" },
      },
    },
    keys = {
      {
        "<leader>ff",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
          vim.notify("Format for current buffer")
        end,
        mode = "",
        desc = "[F]ormat [B]uffer",
      },
      {
        "<leader>ft",
        function()
          -- If autoformat is currently disabled for this buffer,
          -- then enable it, otherwise disable it
          if vim.b.disable_autoformat then
            vim.cmd("FormatEnable")
            vim.notify("Enabled autoformat for current buffer")
          else
            vim.cmd("FormatDisable!")
            vim.notify("Disabled autoformat for current buffer")
          end
        end,
        desc = "[F]ormat [T]oggle autoformat for current buffer",
      },
      {
        "<leader>fT",
        function()
          -- If autoformat is currently disabled globally,
          -- then enable it globally, otherwise disable it globally
          if vim.g.disable_autoformat then
            vim.cmd("FormatEnable")
            vim.notify("Enabled autoformat globally")
          else
            vim.cmd("FormatDisable")
            vim.notify("Disabled autoformat globally")
          end
        end,
        desc = "[F]ormat [T]oggle autoformat for globally",
      },
    },

    -- Create custom toggle commands
    config = function(_, opts)
      -- Start with format-on-save off, matching the previous behaviour.
      -- Turn it on for a session with :FormatEnable or <leader>fT.
      if vim.g.disable_autoformat == nil then
        vim.g.disable_autoformat = true
      end
      require("conform").setup(opts)
      vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then
          -- :FormatDisable! disables autoformat for this buffer only
          vim.b.disable_autoformat = true
        else
          -- :FormatDisable disables autoformat globally
          vim.g.disable_autoformat = true
        end
      end, {
        desc = "Disable autoformat-on-save",
        bang = true, -- allows the ! variant
      })
      vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, {
        desc = "Re-enable autoformat-on-save",
      })
    end,
  },
}
