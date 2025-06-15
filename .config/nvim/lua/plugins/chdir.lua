return {
  "shaobosong/chdir.nvim",
  lazy = true,
  cmd = { "Chdir" },
  keys = {
    { "<leader>ci", "<cmd>Chdir<cr>", mode = "" },
  },
  config = function()
    require("chdir").setup({
      sign = '-',
    })
  end,
}
