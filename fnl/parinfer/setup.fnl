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
  "Log the diff between 'from' and 'to' the log file (requires Nvim 0.6.0 or later)."
  (when (and vim.g.parinfer_logfile (vim.fn.has "nvim-0.6.0"))
    (let [diff (vim.diff from to)]
      (with-open [f (io.open vim.g.parinfer_logfile :a)]
        (f:write diff)))))

(fn invoke-parinfer [text lnum col]
  (let [[prev-lnum prev-col] vim.w.parinfer_prev_cursor
         request {:commentChars vim.b.parinfer_comment_chars
                  :prevCursorLine prev-lnum
                  :prevCursorX (+ prev-col 1)
                  :cursorLine lnum
                  :cursorX (+ col 1)
                  :forceBalance vim.g.parinfer_force_balance}]
    (log "request" request)
    ((. (require :parinfer) (.. vim.g.parinfer_mode :Mode)) text request)))

(fn update-buffer [bufnr lines]
  (vim.api.nvim_command "undojoin")
  (vim.api.nvim_buf_set_lines bufnr 0 -1 true lines))

(fn process-buffer []
  (when (and vim.g.parinfer_enabled (not vim.o.paste) vim.o.modifiable)
    (when (not= vim.b.changedtick vim.b.parinfer_changedtick)
      (set vim.b.parinfer_changedtick vim.b.changedtick)
      (let [[lnum col] (vim.api.nvim_win_get_cursor 0)
            bufnr (vim.api.nvim_get_current_buf)
            orig-lines (vim.api.nvim_buf_get_lines bufnr 0 -1 true)
            text (table.concat orig-lines "\n")
            response (invoke-parinfer text lnum col)]
        (if response.success
            (when (not= response.text text)
              (log "change-response" response)
              (log-diff text response.text)
              (let [lines (vim.split response.text "\n")
                    lnum response.cursorLine
                    col (- response.cursorX 1)]
                (vim.api.nvim_win_set_cursor 0 [lnum col])
                (vim.schedule #(update-buffer bufnr lines))))
            (do
              (log "error-response" response)
              (set vim.g.parinfer_last_error response.error)))))
    (set vim.w.parinfer_prev_cursor (vim.api.nvim_win_get_cursor 0))))

(fn enter-buffer []
  (when (not vim.b.parinfer_comment_chars)
    (set vim.b.parinfer_comment_chars vim.g.parinfer_comment_chars))
  (set vim.w.parinfer_prev_cursor (vim.api.nvim_win_get_cursor 0))
  (set vim.b.parinfer_last_changedtick -1)
  (let [mode vim.g.parinfer_mode]
    (set vim.g.parinfer_mode :paren)
    (process-buffer)
    (set vim.g.parinfer_mode mode)))

(global parinfer {:enter_buffer enter-buffer
                  :process_buffer process-buffer})

(enter-buffer)
