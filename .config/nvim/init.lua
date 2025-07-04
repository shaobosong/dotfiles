-- vim options
require("config.option")
-- vim variables
require("config.variable")
-- vim filetypes
require("config.filetype")
-- vim autocmds
require("config.autocmd")
-- vim mappings
require("config.keymap")
-- vim diagnositc
require("config.diagnostic")
-- configuration for neovide
if vim.g.neovide then
  require("config.neovide")
end
-- plugin manager
require("config.lazy")
-- vim lsp
require("config.lsp")
