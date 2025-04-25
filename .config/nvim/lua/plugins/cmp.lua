return {
    "hrsh7th/nvim-cmp",
    dependencies = {
        { "hrsh7th/cmp-nvim-lua", lazy = true },
        { 'hrsh7th/cmp-nvim-lsp', lazy = true },
        { 'hrsh7th/cmp-buffer', lazy = true },
        { 'hrsh7th/cmp-path', lazy = true },
        { 'hrsh7th/cmp-cmdline', lazy = true },
        -- { 'L3MON4D3/LuaSnip', lazy = true },
        -- { 'saadparwaiz1/cmp_luasnip', lazy = true },
        { 'dmitmel/cmp-cmdline-history', lazy = true },
    },
    opts = function(_, opts)
        if not opts.sources then opts.sources = {} end
        table.insert(opts.sources, { name = "nvim_lua" })
    end,
    config = function()
        local cmp = require'cmp'
        cmp.setup{
            snippet = {
                expand = function(args)
                    -- For native neovim snippets (Neovim v0.10+)
                    vim.snippet.expand(args.body)
                    -- For `luasnip` users.
                    -- require('luasnip').lsp_expand(args.body)
                    -- For `snippy` users.
                    -- require('snippy').expand_snippet(args.body)
                end,
            },
            window = {
                completion = {
                    border = 'single',
                    winhighlight = 'Normal:Pmenu,CursorLine:PmenuSel',
                    winblend = 10,
                },
                documentation = {
                    border = 'rounded',
                    winhighlight = 'Normal:Pmenu',
                    winblend = 10,
                },
            },
            preselect = cmp.PreselectMode.Item,
            mapping = cmp.mapping.preset.insert({
                ['<S-Up>'] = cmp.mapping.scroll_docs(-4),
                ['<S-Down>'] = cmp.mapping.scroll_docs(4),
                ['<ESC>j'] = {
                    i = function()
                        if cmp.visible() then
                            cmp.select_next_item()
                        else
                            cmp.complete()
                        end
                    end,
                },
                ['<ESC>k'] = {
                    i = function()
                        if cmp.visible() then
                            cmp.select_prev_item()
                        else
                            cmp.complete()
                        end
                    end,
                },
                ['<ESC>l'] = {
                    i = function()
                        -- if cmp.visible() then
                        --     cmp.close()
                        -- end
                        vim.api.nvim_input('<Esc><Esc>')
                    end
                },
                ['<Tab>'] = cmp.mapping(function(fallback)
                    -- For native neovim snippets (Neovim v0.10+)
                    if vim.snippet.active({ direction = 1 }) then
                        vim.snippet.jump(1)
                    -- For `luasnip` users
                    -- if require('luasnip').expand_or_jumpable() then
                    --     require('luasnip').expand_or_jump()
                    else
                        fallback()
                    end
                end, { 'i', 's' }),
                ['<S-Tab>'] = cmp.mapping(function(fallback)
                    -- For native neovim snippets (Neovim v0.10+)
                    if vim.snippet.active({ direction = -1 }) then
                        vim.snippet.jump(-1)
                    -- For `luasnip` users
                    -- if require('luasnip').jumpable(-1) then
                    --     require('luasnip').expand_or_jump()
                    else
                        fallback()
                    end
                end, { 'i', 's' }),
                -- [''] = cmp.mapping.complete(),
                -- [''] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior, count = 1 }),
                -- [''] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior, count = 1 }),
                ['<CR>'] = cmp.mapping.confirm({ select = false, behavior = cmp.ConfirmBehavior.Insert }),

            }),
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'nvim_lua' },
                -- { name = 'luasnip' }, -- For luasnip users.
                -- { name = 'snippy' }, -- For snippy users.
                -- { name = 'buffer' },
                -- { name = 'path' },
                -- { name = 'cmdline' },
            })
        }
        local my_mapping_preset_cmdline = {
            ['<Tab>'] = {
                c = function()
                    if cmp.visible() then
                        cmp.select_next_item()
                    else
                        cmp.complete()
                    end
                end,
            },
            ['<M-j>'] = {
                c = function()
                    if cmp.visible() then
                        cmp.select_next_item()
                    else
                        cmp.complete()
                    end
                end,
            },
            ['<S-Tab>'] = {
                c = function()
                    if cmp.visible() then
                        cmp.select_prev_item()
                    else
                        cmp.complete()
                    end
                end,
            },
            ['<M-k>'] = {
                c = function()
                    if cmp.visible() then
                        cmp.select_prev_item()
                    else
                        cmp.complete()
                    end
                end,
            },
        }
        -- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
        cmp.setup.cmdline({ '/', '?' }, {
            -- mapping = cmp.mapping.preset.cmdline(),
            mapping = my_mapping_preset_cmdline,
            sources = {
                { name = 'buffer' },
            }
        })

        -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
        cmp.setup.cmdline(':', {
            -- mapping = cmp.mapping.preset.cmdline(),
            mapping = my_mapping_preset_cmdline,
            sources = cmp.config.sources({
                { name = 'path' },
            }, {
                { name = 'cmdline' },
                -- { name = 'cmdline_history' },
            }),
            matching = { disallow_symbol_nonprefix_matching = false }
        })
    end
}
