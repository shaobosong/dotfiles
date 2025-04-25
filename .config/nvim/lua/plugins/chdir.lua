return {
    "shaobosong/chdir.nvim",
    lazy = true,
    cmd = { "ChangeDirectory" },
    keys = {
        { "<leader>ci", "<cmd>ChangeDirectory<cr>", mode = "" },
    },
    config = function ()
        require("chdir").setup({
            sign = '-',
        })
    end,
}
