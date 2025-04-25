local opts = { noremap = true, silent = true }

vim.keymap.set('', '<ESC>L', '<C-W>l', opts)
vim.keymap.set('', '<ESC>H', '<C-W>h', opts)
vim.keymap.set('', '<ESC>J', '<C-W>j', opts)
vim.keymap.set('', '<ESC>K', '<C-W>k', opts)
-- menu
-- vim.keymap.set('', '<leader>m', '', opts)

vim.keymap.set('!', '<ESC>L', '<ESC><C-W>l', opts)
vim.keymap.set('!', '<ESC>H', '<ESC><C-W>h', opts)
vim.keymap.set('!', '<ESC>J', '<ESC><C-W>j', opts)
vim.keymap.set('!', '<ESC>K', '<ESC><C-W>k', opts)

vim.keymap.set('n', 'gs', ':s@<c-r><c-w>@<c-r><c-w>@g<C-F>hhi' ,opts)
vim.keymap.set('x', 'gs', ':s@@@g<C-F>hhi' ,opts)

vim.keymap.set('n', 'gf', function()
    local saved_path = vim.opt.path:get()
    vim.opt.path:append('**')
    vim.cmd('normal! gf')
    vim.opt.path = saved_path
end, opts)
