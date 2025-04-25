vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    command = "set colorcolumn=81"
})

vim.api.nvim_create_autocmd({ "InsertLeave", "FocusLost" }, {
    pattern = "*",
    command = "set colorcolumn=0"
})

vim.api.nvim_create_autocmd("FileType", {
    pattern = "fzf",
    callback = function()
        -- local opts = { noremap = true, silent = true }
        -- vim.api.nvim_buf_set_keymap(0, "t", "<ESC>j", "<Down>", opts)
        -- vim.api.nvim_buf_set_keymap(0, "t", "<ESC>k", "<Up>", opts)
        -- vim.api.nvim_buf_set_keymap(0, "t", "<ESC>l", "<C-Q>", opts)
        -- vim.api.nvim_buf_set_keymap(0, "t", "<C-R>", "<C-W>", opts)
    end
})

-- vim.api.nvim_create_autocmd("FileType", {
--     pattern = "qf,query",
--     callback = function()
--         local opts = { noremap = true, silent = true }
--         vim.api.nvim_buf_set_keymap(0, "n", "<ESC>l", "<C-W>c", opts)
--         vim.api.nvim_buf_set_keymap(0, "n", "<ESC>H", "<C-W>c", opts)
--         vim.api.nvim_buf_set_keymap(0, "n", "<ESC>J", "<C-W>c", opts)
--         vim.api.nvim_buf_set_keymap(0, "n", "<ESC>K", "<C-W>c", opts)
--         vim.api.nvim_buf_set_keymap(0, "n", "<ESC>L", "<C-W>c", opts)
--         vim.api.nvim_buf_set_keymap(0, "n", "<CR>", "<CR>:cclose<CR>", opts)
--     end
-- })

vim.api.nvim_create_autocmd({"WinLeave"}, {
    pattern = "*",
    callback = function()
        local ft_tbl = { "aerial", "query", "qf", "netrw", "man", "lazy" }
        if vim.tbl_contains(ft_tbl, vim.bo.filetype) and vim.fn.winnr("$") > 1 then
            vim.api.nvim_win_close(vim.api.nvim_get_current_win(), false)
        end
    end
})

vim.api.nvim_create_autocmd("CmdwinEnter", {
    pattern = "*",
    callback = function()
        local opts = { noremap = true, silent = true }
        -- vim.api.nvim_buf_set_keymap(0, "n", "<ESC>l", "<C-W>c", opts)
        vim.api.nvim_buf_set_keymap(0, "n", "<ESC>K", "<C-W>c", opts)
        vim.api.nvim_buf_set_keymap(0, "i", "<ESC>K", "<ESC><C-W>c", opts)
    end
})

vim.api.nvim_create_autocmd({"BufNewFile", "BufRead", "BufEnter"}, {
    pattern = "*.c.inc",
    command = "setlocal filetype=c"
})


--- @see lsp-defaults-disable
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        local opts = { noremap = true, silent = true, buffer = ev.buf }
        -- type: vim.diagnostic.Opts
        local diagnostic = {
            underline = true,
            -- virtual_text = {
            --     prefix = '▶',
            --     virt_text_pos = 'right_align',
            -- },
            update_in_insert = false,
            signs = false,
        }
        vim.bo[ev.buf].formatexpr = nil
        vim.bo[ev.buf].omnifunc = nil
        vim.bo[ev.buf].tagfunc = nil
        -- keymaps
        -- disable the following keymaps if 'fzf-lua' is enabled.
        -- vim.keymap.set('', '<leader>ld', vim.lsp.buf.definition, opts)
        -- vim.keymap.set('', '<leader>lD', vim.lsp.buf.declaration, opts)
        -- vim.keymap.set('', '<leader>lt', vim.lsp.buf.type_definition, opts)
        -- vim.keymap.set('', '<leader>li', vim.lsp.buf.implementation, opts)
        -- vim.keymap.set('', '<leader>lr', vim.lsp.buf.references, opts)
        -- vim.keymap.set('', '<leader>la', vim.lsp.buf.code_action, opts)
        vim.keymap.set('', '<leader>k', vim.lsp.buf.hover, opts)
        vim.keymap.set('', '<leader>lR', vim.lsp.buf.rename, opts)
        vim.keymap.set('', '<leader>lf', function()
            vim.lsp.buf.format { async = true }
        end, opts)
        vim.keymap.del('n', 'K', { buffer = ev.buf })
        if client then
            -- disable syntax highlight from lsp server
            -- client.server_capabilities.semanticTokensProvider = nil
        end
        vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
            vim.lsp.diagnostic.on_publish_diagnostics, diagnostic
        )
        vim.lsp.handlers["textDocument/diagnostic"] = vim.lsp.with(
            vim.lsp.diagnostic.on_diagnostic, diagnostic
        )
        vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
            vim.lsp.handlers.hover, {
                border = "single",
                -- title = " hover "
            }
        )
        -- vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end,
})





