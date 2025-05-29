syntax off

" c or c++
syntax region cCommentL start="//" skip="\\$" end="$" keepend
syntax region cComment start="/\*" end="\*/" fold extend
" syntax sync fromstart
syntax sync ccomment cComment minlines=50

highlight default link cCommentL cComment
highlight default link cComment Comment
highlight Comment ctermfg=darkyellow

set hls
set number
set relativenumber
set scrolloff=5
set nocompatible
set backspace=indent,eol,start
set wildmenu
set wildmode=list:longest

noremap <silent> <ESC>L <C-W>l
noremap <silent> <ESC>H <C-W>h
noremap <silent> <ESC>J <C-W>j
noremap <silent> <ESC>K <C-W>k
noremap! <silent> <ESC>L <ESC><C-W>l
noremap! <silent> <ESC>H <ESC><C-W>h
noremap! <silent> <ESC>J <ESC><C-W>j
noremap! <silent> <ESC>K <ESC><C-W>k
