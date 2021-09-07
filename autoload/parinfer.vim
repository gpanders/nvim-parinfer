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

function! parinfer#log(...) abort
    if a:0 > 0
        let g:parinfer_logfile = a:1
        echomsg 'Parinfer is now logging to '.a:1
    else
        unlet g:parinfer_logfile
        echomsg 'Parinfer is no longer logging'
    endif
endfunction

function! parinfer#init() abort
    if &previewwindow
        return
    endif

    lua require('parinfer.setup')

    augroup parinfer
        autocmd! BufEnter <buffer> call v:lua.parinfer.enter_buffer()
        autocmd! CursorMoved,InsertCharPre,InsertEnter,TextChanged,TextChangedI,TextChangedP <buffer> call v:lua.parinfer.process_buffer()
    augroup END

    if !get(g:, 'parinfer_no_maps', 0)
        if mapcheck('<Tab>', 'i') ==# ''
            imap <buffer> <Tab> <Plug>(parinfer-tab)
        endif

        if mapcheck('<S-Tab>', 'i') ==# ''
            imap <buffer> <S-Tab> <Plug>(parinfer-backtab)
        endif
    endif
endfunction
