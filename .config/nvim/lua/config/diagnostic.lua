-- global diagnostic
local opts = { noremap = true, silent = true }
vim.keymap.set('', '<leader>K', vim.diagnostic.open_float, opts)
--- @type vim.diagnostic.Opts
vim.diagnostic.config({
    --- @type boolean|vim.diagnostic.Opts.Underline
    underline = true,
    --- @type boolean|vim.diagnostic.Opts.VirtualText
    virtual_text = {
        prefix = '▶', -- <c-v>25b6
        virt_text_pos = 'eol',
        spacing = 0,
    },
    --- @type boolean|function|vim.diagnostic.Opts.Signs
    signs = function(_, bufnr)
        return vim.b[bufnr].show_signs == true
    end,
    --- @type boolean|vim.diagnostic.Opts.Float
    float = {
        border = 'single',
    },
    --- @type boolean
    update_in_insert = false,
    --- @type boolean
    severity_sort= false,
})

