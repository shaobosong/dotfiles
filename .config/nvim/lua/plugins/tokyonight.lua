return {
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
                hl.StatusLine = { bg = "#444444", fg = "#FFFFFF" }
                hl.StatusLineNC = { bg = "", fg = "#FFFFFF" }
                -- hl.StatusLineNC = { fg = "#FFFFFF" }
                hl.MsgArea = { fg = "#c0caf5" }
                hl.ModeMsg = { fg = "#c0caf5" }
                hl.Visual = { bg = "#484848" }
                hl.MatchParen = { bg = "#606060", fg = "#FF9E64" }
                hl.Identifier = { fg = "#ff8700" }
                hl.SignColumn = { bg = "" }

                -- hl.Search = { bg = "#444444" }

                hl.Pmenu = { bg = "#343434", fg = "#828282" }
                hl.PmenuSel = { bg = "#6A6A6A" }

                hl.NormalFloat = { bg = "#343434", fg = "#c0caf5" }
                hl.FloatBorder = { fg = "#666666" }

                hl.ColorColumn = { bg = "#f20f44" }

                hl.DiffAdd = { fg = "#FFFFFF", bg = "#005FFF" }
                hl.DiffChange = { fg = "#FFFFFF", bg = "#AF0087" }
                hl.DiffDelete = { fg = "#FFFFFF", bg = "#00AFAF" }

                hl.WinSeparator = { bg = "", fg = "#626262" }
                hl.CursorLineNr = { bg = "#292E42", fg = "#FF9E64" }
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
}
