local mason = {
  {
    "mason-org/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
}

local lsp = {
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = {
      "williamboman/mason.nvim",
    },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {},
        automatic_installation = false,
        handlers = nil,
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

local formatter = {
  {
    "stevearc/conform.nvim",
    opts = {},
    config = function()
      require("conform").setup({
        default_format_opts = {
          lsp_format = "prefer",
        },
        -- formatters_by_ft = {
        --   c = { "clang-format" },
        --   rust = { "rustfmt" },
        --   go = { "gofmt" },
        --   lua = { "stylua" },
        -- },
        format_on_save = {
          timeout_ms = 500,
        },
      })
    end,
  },
}

return {
  mason,
  lsp,
  formatter,
}
