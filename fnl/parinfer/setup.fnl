; Copyright (C) 2021 Gregory Anders
;
; SPDX-License-Identifier: GPL-3.0-or-later
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.

(fn log [tag data]
  "Log a message to the log file."
  (when vim.g.parinfer_logfile
    (with-open [f (io.open vim.g.parinfer_logfile :a)]
      (f:write (: "%20s: %s" :format tag (vim.fn.json_encode data))))))

(fn log-diff [from to]
  "Log the diff between 'from' and 'to' the log file.

Requires Nvim 0.6.0 or later."
  (when (and vim.g.parinfer_logfile (vim.fn.has "nvim-0.6.0"))
    (let [diff (vim.diff from to)]
      (with-open [f (io.open vim.g.parinfer_logfile :a)]
        (f:write diff)))))

(fn get-cursor-position []
  "Get the current cursor position, taking into account display widths."
  (let [[lnum col] (vim.api.nvim_win_get_cursor 0)
        line (vim.api.nvim_get_current_line)
        col (-> (vim.api.nvim_get_current_line)
                (string.sub 1 (- col 1))
                (vim.fn.strdisplaywidth))]
    [lnum col]))

(fn set-cursor-position [lnum col]
  "Set the current cursor position, taking into account displaly widths."
  (let [[line] (vim.api.nvim_buf_get_lines 0 (- lnum 1) lnum true)
        head (vim.fn.matchstr line (.. ".\\+\\%<" (+ col 2) "v"))]
    (vim.api.nvim_win_set_cursor 0 [lnum (+ (length head) 1)])))

(fn enter-window []
  (set vim.w.parinfer_previous_cursor (get-cursor-position)))

(macro set-default-buffer-opts [opts]
  (each [_ opt (pairs opts)]
    (let [opt (.. "parinfer_" opt)]
     `(when (not (. vim.b ,opt))
        (tset vim.b ,opt (. vim.g ,opt))))))

(fn process-buffer []
  (when (and vim.g.parinfer_enabled (not vim.o.paste) vim.o.modifiable)
    (set-default-buffer-opts [:last_changedtick
                              :comment_char
                              :string_delimiters
                              :lisp_vline_symbols
                              :lisp_block_comments
                              :guile_block_comments
                              :scheme_sexp_comments
                              :janet_long_strings])
    (when (not= vim.b.parinfer_last_changedtick vim.b.changedtick)
      (let [[lnum col] (get-cursor-position)
            [prev-lnum prev-col] vim.w.parinfer_previous_cursor
            orig-lines (vim.api.nvim_buf_get_lines 0 0 -1 true)
            text (table.concat orig-lines "\n")
            request {:commentChar vim.b.parinfer_comment_char
                     :stringDelimiters vim.b.parinfer_string_delimiters
                     :cursorX col
                     :cursorLine lnum
                     :forceBalance vim.g.parinfer_force_balance
                     :lispVlineSymbols vim.b.parinfer_lisp_vline_symbols
                     :lispBlockComments vim.b.parinfer_lisp_block_comments
                     :guileBlockComments vim.b.parinfer_guile_block_comments
                     :schemeSexpComments vim.b.parinfer_scheme_sexp_comments
                     :janetLongStrings vim.b.parinfer_janet_long_strings
                     :prevCursorX prev-col
                     :prevCursorLine prev-lnum
                     :prevText vim.b.parinfer_previous_text}
            response ((. (require :parinfer) (.. vim.g.parinfer_mode :Mode)) text request)]
        (if response.success
            (do
              (when (not= response.text text)
                (log "change-request" request)
                (log "change-response" response)
                (log-diff text response.text)
                (let [lines (vim.split response.text "\n")]
                  (vim.api.nvim_command "undojoin")
                  (vim.api.nvim_buf_set_lines 0 0 -1 true lines)))
              (set-cursor-position response.cursorLine response.cursorX)
              (set vim.b.parinfer_previous_text response.text))
            (do
              (log "error-response" response)
              (set vim.g.parinfer_last_error response.error)
              (set vim.b.parinfer_previous_text text)))
        (set vim.b.parinfer_last_changedtick vim.b.changedtick)))
    (set vim.w.parinfer_previous_cursor (get-cursor-position))))

(fn enter-buffer []
  (enter-window)
  (when (not vim.b.parinfer_last_changedtick)
    (set vim.b.parinfer_last_changedtick -10)
    (let [lines (vim.api.nvim_buf_get_lines 0 0 -1 true)
          text (table.concat lines "\n")]
      (set vim.b.parinfer_previous_text text)))
  (let [orig-mode vim.g.parinfer_mode]
    (set vim.g.parinfer_mode :paren)
    (process-buffer)
    (set vim.g.parinfer_mode orig-mode)))

(global parinfer {:enter_buffer enter-buffer
                  :process_buffer process-buffer
                  :enter_window enter-window})
