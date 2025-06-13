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
  {
    name = "c3_lsp",
    bin = "c3lsp",
    config = {
      cmd = {
        'c3lsp',
        '-diagnostics-delay', '500',
      },
      filetypes = { 'c3', 'c3i', "c3t" },
    },
  },
}

for _, server in ipairs(servers) do
  if vim.fn.exepath(server.bin) ~= "" then
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
  'c3_lsp',
})
