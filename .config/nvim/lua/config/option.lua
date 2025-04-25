-- Set update time
vim.opt.updatetime = 100

-- Enable true color support
vim.opt.termguicolors = true

-- Line number settings
vim.opt.number = true
vim.opt.relativenumber = true

-- Search settings
vim.opt.hlsearch = true
vim.opt.incsearch = false
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Folding settings
vim.opt.foldlevel = 99

-- Highlight the current line
vim.opt.cursorline = true

-- Number of lines to keep above/below the cursor when scrolling
vim.opt.scrolloff = 5

-- Display invisible characters
vim.opt.list = true
vim.opt.listchars = {
    tab = '>·',
    trail = '▉',
    extends = '>',
    precedes = '<',
}

-- Status line settings
vim.opt.laststatus = 2
vim.opt.statusline = '%<%f%h%m%r%=[%n] %l/%L'

-- Indentation settings
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.autoindent = true
vim.opt.cindent = true
vim.opt.smartindent = true

-- Backspace behavior
vim.opt.backspace = 'indent,eol,start'

-- Command-line completion
vim.opt.wildmenu = true
vim.opt.wildmode = 'list:longest'

-- Disable compatibility with Vi
vim.opt.compatible = false

-- Add all subdirectories to the search path
-- vim.opt.path:append('**')

-- Tags file
if vim.fn.empty(vim.fn.glob('~/.vim/tags/systags')) == 0 then
    vim.opt.tags:append('~/.vim/tags/systags')
end

-- Allow hidden buffers
vim.opt.hidden = true
