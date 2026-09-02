return {
  {
    "goolord/alpha-nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")
      dashboard.section.header.val = {
        [[                                                                       ]],
        [[                                                                       ]],
        [[                                                                       ]],
        [[                                                                       ]],
        [[                                                                     ]],
        [[       ████ ██████           █████      ██                     ]],
        [[      ███████████             █████                             ]],
        [[      █████████ ███████████████████ ███   ███████████   ]],
        [[     █████████  ███    █████████████ █████ ██████████████   ]],
        [[    █████████ ██████████ █████████ █████ █████ ████ █████   ]],
        [[  ███████████ ███    ███ █████████ █████ █████ ████ █████  ]],
        [[ ██████  █████████████████████ ████ █████ █████ ████ ██████ ]],
        [[                                                                       ]],
        [[                                                                       ]],
        [[                                                                       ]],
      }
      dashboard.section.buttons.val = {
        dashboard.button("n", " " .. " New file", "<cmd> ene <BAR> startinsert <CR>"),
        dashboard.button("r", " " .. " Recent files", "<cmd> Telescope oldfiles <CR>"),
        dashboard.button("f", " " .. " Find file", "<cmd> Telescope find_files <CR>"),
        dashboard.button("t", " " .. " Find text", "<cmd> Telescope live_grep <CR>"),
        dashboard.button("l", "󰒲 " .. " Lazy", "<cmd> Lazy <CR>"),
        dashboard.button("m", " " .. " Mason", "<cmd> Mason <CR>"),
        dashboard.button("h", " " .. " Check health", "<cmd> checkhealth <CR>"),
        dashboard.button("s", " " .. " Settings", "<cmd> Telescope find_files cwd=~/.config/nvim <CR>"),
        dashboard.button("q", " " .. " Quit", "<cmd> qa <CR>"),
      }

      -- Set fortune footer
      local fortune = require("alpha.fortune")
      dashboard.section.footer.val = fortune()

      -- Send config to alpha
      alpha.setup(dashboard.opts)
      -- Disable folding on alpha buffer
      vim.cmd([[ autocmd FileType alpha setlocal nofoldenable ]])
    end,
  },
}
