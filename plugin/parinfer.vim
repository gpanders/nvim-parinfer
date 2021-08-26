" ISC License
"
" Copyright (c) 2021 Jason Felice
"
" Permission to use, copy, modify, and/or distribute this software for any
" purpose with or without fee is hereby granted, provided that the above
" copyright notice and this permission notice appear in all copies.
"
" THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
" REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
" AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
" INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
" LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
" OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
" PERFORMANCE OF THIS SOFTWARE.

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

command! ParinferOn let g:parinfer_enabled = v:true
command! ParinferOff let g:parinfer_enabled = v:false
command! ParinferToggle let g:parinfer_enabled = !g:parinfer_enabled
command! -nargs=? ParinferLog call parinfer#log(<f-args>)

augroup parinfer
    autocmd!
    autocmd FileType clojure,scheme,lisp,racket,hy,fennel,janet,carp,wast,yuck call parinfer#init()

    " Common Lisp and Scheme: ignore parens in symbols enclosed by ||
    autocmd BufNewFile,BufRead *.lsp,*.lisp,*.cl,*.L,sbclrc,.sbclrc let b:parinfer_lisp_vline_symbols = 1
    autocmd BufNewFile,BufRead *.scm,*.sld,*.ss,*.rkt let b:parinfer_lisp_vline_symbols = 1

    " Common Lisp and Scheme: ignore parens in block comments
    autocmd BufNewFile,BufRead *.lsp,*.lisp,*.cl,*.L,sbclrc,.sbclrc let b:parinfer_lisp_block_comments = 1
    autocmd BufNewFile,BufRead *.scm,*.sld,*.ss,*.rkt let b:parinfer_lisp_block_comments = 1

    " Scheme (SRFI-62): S-expression comment
    autocmd BufNewFile,BufRead *.scm,*.sld,*.ss,*.rkt let b:parinfer_scheme_sexp_comments = 1

    " Comment settings
    autocmd BufNewFile,BufRead *.janet let b:parinfer_comment_char = '#'

    " Long strings settings
    autocmd BufNewFile,BufRead *.janet let b:parinfer_janet_long_strings = 1
augroup END
