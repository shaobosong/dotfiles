local opts = { noremap = true, silent = true }

vim.keymap.set('', '<ESC>L', '<C-W>l', opts)
vim.keymap.set('', '<ESC>H', '<C-W>h', opts)
vim.keymap.set('', '<ESC>J', '<C-W>j', opts)
vim.keymap.set('', '<ESC>K', '<C-W>k', opts)

vim.keymap.set('!', '<ESC>L', '<ESC><C-W>l', opts)
vim.keymap.set('!', '<ESC>H', '<ESC><C-W>h', opts)
vim.keymap.set('!', '<ESC>J', '<ESC><C-W>j', opts)
vim.keymap.set('!', '<ESC>K', '<ESC><C-W>k', opts)

vim.keymap.set('n', 'gs', ':s@<c-r><c-w>@<c-r><c-w>@g<C-F>hhi', opts)
vim.keymap.set('x', 'gs', ':s@@@g<C-F>hhi', opts)

vim.keymap.set('', '<leader>tr', ':%s/\\s\\+$//g<CR>', opts)

-- menu
vim.cmd('anoremenu ToolBar.Go\\ to\\ definition    <Cmd>lua vim.lsp.buf.definition()<CR>')
vim.cmd('anoremenu ToolBar.-1-                     <Nop>')
vim.cmd('anoremenu ToolBar.Copy                    "+yiw')
vim.cmd('vnoremenu ToolBar.Copy                    "+y')
vim.cmd('anoremenu ToolBar.Cut                     "+diw')
vim.cmd('vnoremenu ToolBar.Cut                     "+x')
vim.cmd('anoremenu ToolBar.Paste                   "+gP')
vim.cmd('vnoremenu ToolBar.Paste                   "+P')
vim.cmd('vnoremenu ToolBar.Delete                  "_x')
vim.cmd('anoremenu ToolBar.-2-                     <Nop>')
vim.cmd('nnoremenu ToolBar.Select\\ All            ggVG')
vim.cmd('vnoremenu ToolBar.Select\\ All            gg0oG$')
vim.keymap.set('', '<leader>m', '<cmd>popup ToolBar<cr>', opts)
