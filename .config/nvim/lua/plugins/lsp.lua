return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = {},
                automatic_installation = false,
                handlers = nil,
            })
        end,
    },
    {
        "neovim/nvim-lspconfig",
        lazy = true,
        event = { "BufReadPost", "BufNewFile" },
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
        },
        config = function()
            local lspconfig = require("lspconfig")
            -- local capabilities = vim.lsp.protocol.make_client_capabilities()
            -- capabilities.textDocument.completion.completionItem.snippetSupport = true
            local servers = {
                {
                    name = "clangd",
                    bin = "clangd",
                    config = {
                        capabilities = {
                            textDocument = {
                                completion = {
                                    editsNearCursor = true,
                                    completionItem = {
                                        snippetSupport = true
                                    },
                                },
                            },
                        },
                        cmd = {
                            'clangd',
                            '--compile-commands-dir=build',
                            '--background-index',
                            '--completion-style=detailed',
                            '--header-insertion=iwyu',
                            -- '--clang-tidy',
                            -- '--inlay-hints',
                            -- "--function-arg-placeholders",
                            -- "--fallback-style=llvm",
                        },
                        filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda', 'proto' },
                        init_options = {
                            usePlaceholders = true,
                            completeUnimported = true,
                            clangdFileStatus = true,
                        },
                        single_file_support = true,
                    },
                },
                {
                    name = "lua_ls",
                    bin = "lua-language-server",
                    config = {
                        cmd = {
                            "lua-language-server",
                        },
                        filetypes = { 'lua' },
                        settings = {
                            Lua = {
                                runtime = {
                                    version = 'LuaJIT',
                                },
                                diagnostics = {
                                    globals = { 'vim' },
                                },
                                workspace = {
                                    library = vim.api.nvim_get_runtime_file("", true),
                                    checkThirdParty = false,
                                },
                                telemetry = {
                                    enable = false,
                                },
                            },
                        },
                    },
                },
                {
                    name = "rust_analyzer",
                    bin = "rust-analyzer",
                    config = {
                        cmd = {
                            'rust-analyzer',
                        },
                        filetypes = { 'rust' },
                        settings = {
                            ['rust-analyzer'] = {},
                        },
                    },
                },
            }
            for _, server in ipairs(servers) do
                if vim.fn.exepath(server.bin) ~= "" then
                    lspconfig[server.name].setup(server.config)
                    -- `nvim-lspconfig` includes configurations compatible
                    -- with `vim.lsp` under `lsp/` (neovim 0.11.0+)
                    vim.lsp.config(server.name, server.config)
                end
            end
            -- Auto-activated when a filetype is opened (neovim 0.11.0+)
            vim.lsp.enable({
                'lua_ls',
                'clangd',
                'rust_analyzer',
            })
        end,
    },
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
