syntax on

highlight Comment ctermfg=darkgray
highlight String ctermfg=darkcyan
highlight Keyword ctermfg=darkyellow
highlight Normal ctermfg=white
highlight Search ctermfg=black ctermbg=darkyellow

highlight default link cComment Comment
highlight default link cString String
highlight default link cKeyword Keyword

function! s:syntax_c()
    setlocal syntax=off
    syntax clear
    syntax region cComment start="/\*" end="\*/" extend fold
    syntax region cComment start="//" skip="\\$" end="$" keepend
    syntax region cString start=+L\="+ skip=+\\\\\|\\"+ end=+"+
    syntax keyword cKeyword 
      \ if else
      \ switch case default
      \ while for do continue
      \ break goto return
    syntax sync ccomment cCommentB minlines=50
endfunction

function! s:syntax_c3()
    call s:syntax_c()
    syntax region cComment start="<\*" end="\*>" extend fold
    syntax keyword cKeyword 
      \ module import
      \ try catch
      \ foreach foreach_r
      \ nextcase
      \ def alias faultdef fn macro fault bitstruct interface
      \ defer
      \ cast asm null true false
endfunction

augroup custom_syntax
    autocmd!
    autocmd FileType c,cpp call s:syntax_c()
    autocmd FileType c3 call s:syntax_c3()
augroup END

set hls
set number
set relativenumber
set scrolloff=5
set nocompatible
set backspace=indent,eol,start
set wildmenu
set wildmode=list:longest
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set autoindent
set cindent
set smartindent

noremap <silent> <ESC>L <C-W>l
noremap <silent> <ESC>H <C-W>h
noremap <silent> <ESC>J <C-W>j
noremap <silent> <ESC>K <C-W>k
noremap! <silent> <ESC>L <ESC><C-W>l
noremap! <silent> <ESC>H <ESC><C-W>h
noremap! <silent> <ESC>J <ESC><C-W>j
noremap! <silent> <ESC>K <ESC><C-W>k
