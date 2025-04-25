-- Install lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.print("Cloning lazy.nvim")
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        lazyrepo,
        lazypath
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Configure lazy.nvim
require("lazy").setup({
    spec = {
        { import = 'plugins.tokyonight' },
        -- { import = 'plugins.sonokai' },
        -- { import = 'plugins.catppuccin' },
        -- { import = 'plugins.kanagawa' },
        -- { "oxfist/night-owl.nvim" },
        { import = "plugins.treesitter" },
        { import = 'plugins.cmp' },
        { import = 'plugins.fzf' },
        { import = "plugins.lsp" },
        { import = "plugins.aerial" },
        { import = "plugins.gitsigns" },
        { import = "plugins.ui" },
        { import = "plugins.chdir" },
        { "shaobosong/vim-line-comment" },
        { "shaobosong/vim-copy" },
        -- { "mhinz/vim-signify" },
        -- { "AstroNvim/astrocommunity", {import = "astrocommunity.colorscheme", lazy = false} },
        -- { "AstroNvim/astrocommunity", lazy = false },
    },
    change_detection = {
        notify = false,
    },
    -- colorscheme that will be used when installing plugins.
    -- install = { colorscheme = { "tokyonight-night" } },
    -- automatically check for plugin updates
    checker = { enabled = false },
    ui = {
        border = "none",
        -- The backdrop opacity. 0 is fully opaque, 100 is fully transparent.
        backdrop = 100,
        icons = {
            cmd = "⌘",
            config = "🛠",
            event = "📅",
            ft = "📂",
            init = "⚙",
            keys = "🗝",
            plugin = "🔌",
            runtime = "💻",
            require = "🌙",
            source = "📄",
            start = "🚀",
            task = "📌",
            lazy = "💤 ",
        },
    },
})
