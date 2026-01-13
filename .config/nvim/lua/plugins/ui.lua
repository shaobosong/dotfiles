local theme = {
  -- {
  --   "sainnhe/sonokai",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     -- Optionally configure and load the colorscheme
  --     -- directly inside the plugin declaration.
  --     vim.g.sonokai_enable_italic = false
  --     vim.g.sonokai_style = "atlantis"
  --     vim.g.sonokai_better_performance = 1
  --     vim.cmd.colorscheme('sonokai')
  --   end,
  -- },
  -- {
  --   "rebelot/kanagawa.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     require('kanagawa').setup({
  --       compile = false,  -- enable compiling the colorscheme
  --       undercurl = true, -- enable undercurls
  --       commentStyle = { italic = true },
  --       functionStyle = {},
  --       keywordStyle = { italic = true },
  --       statementStyle = { bold = true },
  --       typeStyle = {},
  --       transparent = false,   -- do not set background color
  --       dimInactive = false,   -- dim inactive window `:h hl-NormalNC`
  --       terminalColors = true, -- define vim.g.terminal_color_{0,17}
  --       colors = {             -- add/modify theme and palette colors
  --         palette = {},
  --         theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
  --       },
  --       overrides = function(colors) -- add/modify highlights
  --         return {}
  --       end,
  --       theme = "wave",  -- Load "wave" theme when 'background' option is not set
  --       background = {   -- map the value of 'background' option to a theme
  --         dark = "wave", -- try "dragon" !
  --         light = "lotus"
  --       },
  --     })
  --     -- Optionally configure and load the colorscheme
  --     -- directly inside the plugin declaration.
  --     -- vim.cmd("colorscheme kanagawa")
  --     vim.cmd.colorscheme('kanagawa-wave')
  --   end,
  -- },
  -- {
  --   "catppuccin/nvim",
  --   lazy = false,
  --   priority = 1000,
  --   opts = {
  --   },

  --   config = function()
  --     require('catppuccin').setup({
  --       flavour = "frappe", -- latte, frappe, macchiato, mocha
  --       background = {      -- :h background
  --         light = "latte",
  --         dark = "mocha",
  --       },
  --       transparent_background = false, -- disables setting the background color.
  --       show_end_of_buffer = false,     -- shows the '~' characters after the end of buffers
  --       term_colors = false,            -- sets terminal colors (e.g. `g:terminal_color_0`)
  --       dim_inactive = {
  --         enabled = false,              -- dims the background color of inactive window
  --         shade = "dark",
  --         percentage = 0.15,            -- percentage of the shade to apply to the inactive window
  --       },
  --       no_italic = false,              -- Force no italic
  --       no_bold = false,                -- Force no bold
  --       no_underline = false,           -- Force no underline
  --       styles = {                      -- Handles the styles of general hi groups (see `:h highlight-args`):
  --         comments = { "italic" },      -- Change the style of comments
  --         conditionals = { "italic" },
  --         loops = {},
  --         functions = {},
  --         keywords = {},
  --         strings = {},
  --         variables = {},
  --         numbers = {},
  --         booleans = {},
  --         properties = {},
  --         types = {},
  --         operators = {},
  --         -- miscs = {}, -- Uncomment to turn off hard-coded styles
  --       },
  --       color_overrides = {},
  --       custom_highlights = {},
  --       default_integrations = true,
  --       integrations = {
  --         cmp = true,
  --         gitsigns = true,
  --         nvimtree = true,
  --         treesitter = true,
  --         notify = false,
  --         mini = {
  --           enabled = true,
  --           indentscope_color = "",
  --         },
  --         -- For more plugins integrations please scroll down (https://github.com/catppuccin/nvim#integrations)
  --       },
  --     })
  --     -- Optionally configure and load the colorscheme
  --     -- directly inside the plugin declaration.
  --     -- vim.g.sonokai_enable_italic = false
  --     -- vim.g.sonokai_style = "atlantis"
  --     -- vim.g.sonokai_better_performance = 1
  --     vim.cmd.colorscheme('catppuccin')
  --   end,
  -- },
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
    config = function()
      require("tokyonight").setup({
        -- use the night style
        style = "night",
        -- disable italic for functions
        styles = {
          functions = {}
        },
        on_colors = function(colors)
          -- vim.print(colors)
          colors.fg = "#FFFFFF"
          -- Change the "hint" color to the "orange" color, and make the "error" color bright red
          -- colors.hint = colors.orange
          -- colors.error = "#ff0000"
        end,
        on_highlights = function(hl, _)
          hl.Cursor = { bg = "#FFFFFF", fg = "#161616" }
          hl.Normal = { bg = "", fg = "#FFFFFF" }
          hl.NormalNC = { bg = "", fg = "#FFFFFF" }
          hl.StatusLine = { bg = "", fg = "#C0CAF5" }
          hl.StatusLineNC = { bg = "", fg = "#C0CAF5" }
          hl.MsgArea = { fg = "#c0caf5" }
          hl.ModeMsg = { fg = "#c0caf5" }
          hl.Visual = { bg = "#484848" }
          hl.MatchParen = { bg = "#606060", fg = "#FF9E64" }
          hl.Identifier = { fg = "#ff8700" }
          hl.SignColumn = { bg = "" }

          -- hl.Search = { bg = "#444444" }

          hl.Pmenu = { bg = "#343434", fg = "#828282" }
          hl.PmenuSel = { bg = "#6A6A6A", fg = "#FFFFFF" }

          hl.NormalFloat = { bg = "#343434", fg = "#c0caf5" }
          hl.FloatBorder = { fg = "#666666" }

          hl.ColorColumn = { bg = "#f20f44" }

          -- hl.DiffAdd = { fg = "", bg = "#1D421A" }
          -- hl.DiffChange = { fg = "", bg = "#30415D" }
          -- hl.DiffDelete = { fg = "", bg = "#421E1E" }

          hl.DiffAdd = { fg = "", bg = "#12261E" }
          hl.DiffChange = { fg = "", bg = "#1A2137" }
          hl.DiffDelete = { fg = "", bg = "#25171C" }
          hl.DiffText = { fg = "", bg = "#0C2D6B" }

          hl.Folded = { fg = "#C38000", bg = "#5D4C2B" }

          hl.WinSeparator = { bg = "", fg = "#626262" }
          hl.CursorLineNr = { bg = "", fg = "#FF9E64" }
          hl.LineNr = { fg = "#626262" }
          hl.LineNrAbove = { fg = "#626262" }
          hl.LineNrBelow = { fg = "#626262" }

          hl.Constant = { fg = "#f20f44" }
          hl.String = { fg = "#AFAF87" }
          hl.Special = { fg = "#D772FF" }
          hl.Comment = { fg = "#626262" }
          hl.Whitespace = { fg = "#626262" }
          hl.PreProc = { fg = "#D70087" }
          hl.PreCondit = { fg = "#FF8700" }
          hl.Type = { fg = "#00AF00" }
          hl.Operator = { fg = "#00AF00" }
          hl.Statement = { fg = "#FFD700" }
          hl.Function = { fg = "#7AA2F7" }

          -- hl["@lsp.type.variable"] = { fg = "#FFFFFF" }
          -- hl["@property"] = { fg = "#FFFE91" }
        end,
      })
      vim.cmd.colorscheme('tokyonight')
    end,
  },
}

local focus = {
  -- {
  --   "shaobosong/maskwin.nvim",
  --   config = function()
  --     require("maskwin").setup({
  --       enabled = true,
  --       lighten_blend = 100,
  --       darken_blend = 50,
  --       ignore_win_types = { "popup" },
  --     })
  --   end,
  -- },
  -- {
  --   "nvim-zh/colorful-winsep.nvim",
  --   config = true,
  --   event = { "WinLeave" },
  -- },
  {
    "tadaa/vimade",
    opts = {
      -- Recipe can be any of 'default', 'minimalist', 'duo', and 'ripple'
      -- Set animate = true to enable animations on any recipe.
      -- See the docs for other config options.
      recipe = { "minimalist", { animate = false } },
      -- ncmode = 'windows' will fade inactive windows.
      -- ncmode = 'focus' will only fade after you activate the `:VimadeFocus` command.
      ncmode = "windows",
      fadelevel = 0.4, -- any value between 0 and 1. 0 is hidden and 1 is opaque.
      blocklist = {
        custom = {
          highlights = {
            'WinSeparator',
            'EndOfBuffer',
          },
        },
      },
    },
  },
}

local vcs = {
  -- { "mhinz/vim-signify" },
  -- { "airblade/vim-gitgutter" },
  {
    -- dir = '/root/freedom/gitsigns.nvim',
    "lewis6991/gitsigns.nvim",
    tag = "v2.0.0",
    config = function()
      require("gitsigns").setup({
        signs                   = {
          add          = { text = '┃' },
          change       = { text = '┃' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '┃' },
          untracked    = { text = '┆' },
        },
        signs_staged            = {
          add          = { text = '┃' },
          change       = { text = '┃' },
          delete       = { text = '_' },
          topdelete    = { text = '‾' },
          changedelete = { text = '┃' },
          untracked    = { text = '┆' },
        },
        signs_staged_enable     = true,
        signcolumn              = true,
        numhl                   = false,
        linehl                  = false,
        word_diff               = false,
        watch_gitdir = {
          enable = true,
          follow_files = true,
        },
        auto_attach = true,
        attach_to_untracked     = true,
        current_line_blame      = true,
        current_line_blame_opts = {
          delay = 300,
        },
        max_file_length = 40000,
        preview_config = {
          -- Options passed to nvim_open_win
          style = 'minimal',
          relative = 'cursor',
          row = 0,
          col = 1
        },
        on_attach = function(bufnr)
          local gitsigns = require('gitsigns')
          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation
          map('n', ']c', function()
            if vim.wo.diff then
              vim.cmd.normal({ ']c', bang = true })
            else
              gitsigns.nav_hunk('next')
            end
          end)

          map('n', '[c', function()
            if vim.wo.diff then
              vim.cmd.normal({ '[c', bang = true })
            else
              gitsigns.nav_hunk('prev')
            end
          end)

          -- map('n', ']C', function()
          --   if vim.wo.diff then
          --     vim.cmd.({ ']c', bang = true })
          --   else
          --     gitsigns.nav_hunk('next', { target = 'staged' })
          --   end
          -- end)

          -- map('n', '[C', function()
          --   if vim.wo.diff then
          --     vim.cmd.normal({ '[c', bang = true })
          --   else
          --     gitsigns.nav_hunk('prev', { target = 'staged' })
          --   end
          -- end)

          -- Actions
          map('n', '<leader>hs', gitsigns.stage_hunk)
          map('v', '<leader>hs', function()
            gitsigns.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
          end)

          map('n', '<leader>hr', gitsigns.reset_hunk)
          map('v', '<leader>hr', function()
            gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
          end)

          map('n', '<leader>hS', gitsigns.stage_buffer)
          map('n', '<leader>hR', gitsigns.reset_buffer)
          map('n', '<leader>hp', gitsigns.preview_hunk)
          map('n', '<leader>hi', gitsigns.preview_hunk_inline)

          map('n', '<leader>hb', function()
            gitsigns.blame_line({ full = true })
          end)

          map('n', '<leader>hd', gitsigns.diffthis)

          map('n', '<leader>hD', function()
            gitsigns.diffthis('~')
          end)

          map('n', '<leader>hq', gitsigns.setqflist)
          map('n', '<leader>hQ', function() gitsigns.setqflist('all') end)

          -- Toggles
          map('n', '<leader>ht', function()
            -- gitsigns.toggle_linehl()
            -- topdelete issue: lewis6991/gitsigns.nvim#566
            gitsigns.toggle_deleted()
            gitsigns.toggle_word_diff()
          end)

          -- Text object
          map({ 'o', 'x' }, 'ih', gitsigns.select_hunk)
        end
      })
      -- Sign highlight group for dark theme
      vim.api.nvim_set_hl(0, 'GitSignsAdd', { fg = "#20D030", bg = "" })
      vim.api.nvim_set_hl(0, 'GitSignsChange', { fg = "#005FFF", bg = "" })
      vim.api.nvim_set_hl(0, 'GitSignsDelete', { fg = "#F20F44", bg = "" })
      vim.api.nvim_set_hl(0, 'GitSignsChangedelete', { link = 'GitSignsChange' })
      vim.api.nvim_set_hl(0, 'GitSignsTopdelete', { link = 'GitSignsDelete' })
      vim.api.nvim_set_hl(0, 'GitSignsUntracked', { link = 'GitSignsAdd' })

      vim.api.nvim_set_hl(0, 'GitSignsAddNr', { link = 'GitSignsAdd' })
      vim.api.nvim_set_hl(0, 'GitSignsChangeNr', { link = 'GitSignsChange' })
      vim.api.nvim_set_hl(0, 'GitSignsDeleteNr', { link = 'GitSignsDelete' })
      vim.api.nvim_set_hl(0, 'GitSignsChangedeleteNr', { link = 'GitSignsChange' })
      vim.api.nvim_set_hl(0, 'GitSignsTopdeleteNr', { link = 'GitSignsDelete' })
      vim.api.nvim_set_hl(0, 'GitSignsUntrackedNr', { link = 'GitSignsAdd' })

      vim.api.nvim_set_hl(0, 'GitSignsAddLn', { link = 'DiffAdd' })
      vim.api.nvim_set_hl(0, 'GitSignsChangeLn', { link = 'DiffChange' })
      vim.api.nvim_set_hl(0, 'GitSignsDeleteLn', { fg = "", bg = "" })
      vim.api.nvim_set_hl(0, 'GitSignsChangedeleteLn', { link = 'GitSignsChangeLn' })
      vim.api.nvim_set_hl(0, 'GitSignsTopdeleteLn', { link = 'GitSignsDeleteLn' })
      vim.api.nvim_set_hl(0, 'GitSignsUntrackedLn', { link = 'GitSignsAddLn' })
      vim.api.nvim_set_hl(0, 'GitSignsDeleteVirtLn', { link = 'DiffDelete' })

      vim.api.nvim_set_hl(0, 'GitSignsStagedAdd', { fg = "#0a5010", bg = "" })
      vim.api.nvim_set_hl(0, 'GitSignsStagedChange', { fg = "#003080", bg = "" })
      vim.api.nvim_set_hl(0, 'GitSignsStagedDelete', { fg = "#500316", bg = "" })
      vim.api.nvim_set_hl(0, 'GitSignsStagedChangedelete', { link = 'GitSignsStagedChange' })
      vim.api.nvim_set_hl(0, 'GitSignsStagedTopdelete', { link = 'GitSignsStagedDelete' })
      vim.api.nvim_set_hl(0, 'GitSignsStagedUntracked', { link = 'GitSignsStagedAdd' })

      vim.api.nvim_set_hl(0, 'GitSignsAddInline', { fg = "", bg = "#1D572D" })
      vim.api.nvim_set_hl(0, 'GitSignsChangeInline', { fg = "", bg = "#1D572D" })
      vim.api.nvim_set_hl(0, 'GitSignsDeleteInline', { fg = "", bg = "#542426" })

      vim.api.nvim_set_hl(0, 'GitSignsAddLnInline', { link = 'GitSignsAddInline' })
      vim.api.nvim_set_hl(0, 'GitSignsChangeLnInline', { link = 'GitSignsChangeInline' })
      vim.api.nvim_set_hl(0, 'GitSignsDeleteLnInline', { link = 'GitSignsDeleteInline' })
      vim.api.nvim_set_hl(0, 'GitSignsDeleteVirtLnInline', { fg = "#626262", bg = "#542426" })

      vim.api.nvim_set_hl(0, 'GitSignsAddPreview', { link = 'DiffAdd' })
      vim.api.nvim_set_hl(0, 'GitSignsDeletePreview', { link = 'DiffDelete' })
    end
  },
}

local lsp = {
  {
    "j-hui/fidget.nvim",
    config = function()
      require("fidget").setup({
        notification = {
          window = {
            normal_hl = "Comment",
            winblend = 0,
          },
        },
      })
    end,
  },
}

local cursor = {
  {
    url = 'git@github.com:jake-stewart/multicursor.nvim.git',
    branch = "1.0",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local set = vim.keymap.set

      -- Add or skip cursor above/below the main cursor.
      set({"n", "x"}, "<ESC><C-K>", function() mc.lineAddCursor(-1) end)
      set({"n", "x"}, "<ESC><C-J>", function() mc.lineAddCursor(1) end)
      set({"n", "x"}, "<c-up>", function() mc.lineSkipCursor(-1) end)
      set({"n", "x"}, "<c-down>", function() mc.lineSkipCursor(1) end)

      -- Add or skip adding a new cursor by matching word/selection
      set({"n", "x"}, "<leader>n", function() mc.matchAddCursor(1) end)
      set({"n", "x"}, "<leader>s", function() mc.matchSkipCursor(1) end)
      set({"n", "x"}, "<leader>N", function() mc.matchAddCursor(-1) end)
      set({"n", "x"}, "<leader>S", function() mc.matchSkipCursor(-1) end)

      -- Add and remove cursors with control + left click.
      set("n", "<c-leftmouse>", mc.handleMouse)
      set("n", "<c-leftdrag>", mc.handleMouseDrag)
      set("n", "<c-leftrelease>", mc.handleMouseRelease)

      -- match new cursors within visual selections by regex.
      set("x", "<leader>/", mc.matchCursors)

      -- Disable and enable cursors.
      set({"n", "x"}, "<c-q>", mc.toggleCursor)

      -- Mappings defined in a keymap layer only apply when there are
      -- multiple cursors. This lets you have overlapping mappings.
      mc.addKeymapLayer(function(layerSet)

        -- Select a different cursor as the main one.
        layerSet({"n", "x"}, "<esc>N", mc.prevCursor)
        layerSet({"n", "x"}, "<esc>n", mc.nextCursor)

        -- Delete the main cursor.
        layerSet({"n", "x"}, "<leader>x", mc.deleteCursor)

        -- Enable and clear cursors using escape.
        layerSet("n", "<M-l>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          elseif mc.hasCursors() then
            mc.clearCursors()
          else
            -- default <esc> handler
          end
        end)
      end)

      -- Customize how cursors look.
      local hl = vim.api.nvim_set_hl
      hl(0, "MultiCursorCursor", { reverse = true })
      hl(0, "MultiCursorVisual", { link = "Visual" })
      hl(0, "MultiCursorSign", { link = "SignColumn"})
      hl(0, "MultiCursorMatchPreview", { link = "Search" })
      hl(0, "MultiCursorDisabledCursor", { reverse = true })
      hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
      hl(0, "MultiCursorDisabledSign", { link = "SignColumn"})
    end
  },
}

return {
  theme,
  focus,
  vcs,
  lsp,
  cursor,
}
