return {
    "nvim-treesitter/nvim-treesitter",
    tag = "v0.9.3",
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = { "lua", "c", "cpp" },
            sync_install = false,
            auto_install = false,
            ignore_install = {},
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
                disable = { "c", "cpp", "c3" },
            },
            indent = {
                enable = false,
            },
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<ESC>v",
                    node_incremental = "<ESC>v",
                    node_decremental = "<ESC>V",
                    -- scope_incremental = "",
                },
            },
            modules = {},
        })
        local parse_config = require "nvim-treesitter.parsers".get_parser_configs()
        parse_config.c3 = {
            install_info = {
                url = "https://github.com/c3lang/tree-sitter-c3",
                files = { "src/parser.c", "src/scanner.c" },
                branch = "main",
            },
            sync_install = false, -- Set to true if you want to install synchronously
            auto_install = false, -- Automatically install when opening a file
            filetype = "c3",      -- if filetype does not match the parser name
        }
    end,
}
