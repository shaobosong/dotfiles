return {
  -- {
  --   "nvim-zh/colorful-winsep.nvim",
  --   config = true,
  --   event = { "WinLeave" },
  -- },
  {
    "tadaa/vimade",
    opts = {
      -- Recipe can be any of 'default', 'minimalist', 'duo', and 'ripple'
      -- Set animate = true to enable animations on any recipe.
      -- See the docs for other config options.
      recipe = { "minimalist", { animate = false } },
      -- ncmode = 'windows' will fade inactive windows.
      -- ncmode = 'focus' will only fade after you activate the `:VimadeFocus` command.
      ncmode = "windows",
      fadelevel = 0.4, -- any value between 0 and 1. 0 is hidden and 1 is opaque.
    },
  },
}
