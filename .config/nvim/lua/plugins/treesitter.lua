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
                disable = { "c", "cpp" },
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
    end,
}
