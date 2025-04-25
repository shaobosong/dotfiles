-- variable
vim.g.neovide_opacity = 0.95

vim.g.neovide_floating_blur_amount_x = 0
vim.g.neovide_floating_blur_amount_y = 0

vim.g.line_comment_map='<C-/>'

if vim.fn.has("win") then
    vim.g.neovide_title_background_color = string.format(
        "%x",
        vim.api.nvim_get_hl(0, {id=vim.api.nvim_get_hl_id_by_name("Normal")}).bg
    )
end

vim.g.neovide_title_text_color = "white"

-- keymap
-- copy into system-clipboard in neovide on windows 11
local opts = { noremap = true, silent = true }
vim.keymap.set('x', '<C-S-C>', '"+y', opts)

-- paste from system-clipboard in neovide on windows 11
vim.keymap.set('n', '<C-S-V>', '"+p', opts)
vim.keymap.set('x', '<C-S-V>', '"+P', opts)
vim.keymap.set('!', '<C-S-V>', '<C-R>+', opts)
