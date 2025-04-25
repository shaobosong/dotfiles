return {
    "shaobosong/maskwin.nvim",
    config = function ()
        require("maskwin").setup({
            enabled = true,
            lighten_blend = 100,
            darken_blend = 50,
            ignore_win_types = { "popup" },
        })
    end,
}
