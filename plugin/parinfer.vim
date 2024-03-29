" Copyright (C) 2021 Gregory Anders
"
" SPDX-License-Identifier: GPL-3.0-or-later
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <https://www.gnu.org/licenses/>.

if exists('g:loaded_parinfer') || !has('nvim')
    finish
endif
let g:loaded_parinfer = v:true

if !exists('g:parinfer_mode')
  let g:parinfer_mode = 'smart'
endif

if !exists('g:parinfer_enabled')
  let g:parinfer_enabled = v:true
endif

if !exists('g:parinfer_force_balance')
  let g:parinfer_force_balance = v:false
endif

if !exists('g:parinfer_comment_chars')
  let g:parinfer_comment_chars = [';']
endif

if !exists('g:parinfer_filetypes')
  let g:parinfer_filetypes = ['clojure', 'scheme', 'lisp', 'racket', 'hy', 'fennel', 'janet', 'carp', 'wast', 'yuck', 'dune']
endif

command! -bang ParinferOn call parinfer#enable(<bang>0, 1)
command! -bang ParinferOff call parinfer#enable(<bang>0, 0)
command! -bang ParinferToggle call parinfer#toggle(<bang>0)
command! -nargs=? ParinferLog call parinfer#log(<f-args>)

augroup parinfer
    autocmd!
    autocmd FileType janet let b:parinfer_comment_chars = ['#']
    autocmd FileType * if index(g:parinfer_filetypes, &filetype) != -1 | call parinfer#init() | endif
augroup END

inoremap <Plug>(parinfer-tab) <Cmd>lua parinfer.tab(true)<CR>
inoremap <Plug>(parinfer-backtab) <Cmd>lua parinfer.tab(false)<CR>
