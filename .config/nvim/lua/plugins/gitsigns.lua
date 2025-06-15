return {
  "lewis6991/gitsigns.nvim",
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
      signcolumn              = true,
      numhl                   = false,
      linehl                  = false,
      word_diff               = false,
      attach_to_untracked     = true,
      current_line_blame      = true,
      current_line_blame_opts = {
        delay = 300,
      },
      on_attach               = function(bufnr)
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

        -- Toggles
        map('n', '<leader>ht', function()
          gitsigns.toggle_linehl()
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

    vim.api.nvim_set_hl(0, 'GitSignsAddLn', { fg = "", bg = "#12261E" })
    vim.api.nvim_set_hl(0, 'GitSignsChangeLn', { fg = "", bg = "#121726" })
    vim.api.nvim_set_hl(0, 'GitSignsDeleteLn', { fg = "", bg = "" })
    vim.api.nvim_set_hl(0, 'GitSignsChangedeleteLn', { link = 'GitSignsChangeLn' })
    vim.api.nvim_set_hl(0, 'GitSignsTopdeleteLn', { link = 'GitSignsDeleteLn' })
    vim.api.nvim_set_hl(0, 'GitSignsUntrackedLn', { link = 'GitSignsAddLn' })
    vim.api.nvim_set_hl(0, 'GitSignsDeleteVirtLn', { fg = "#626262", bg = "#25171C" })

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

    vim.api.nvim_set_hl(0, 'GitSignsAddPreview', { fg = "", bg = "#12261E" })
    vim.api.nvim_set_hl(0, 'GitSignsDeletePreview', { fg = "", bg = "#25171C" })
  end
}
