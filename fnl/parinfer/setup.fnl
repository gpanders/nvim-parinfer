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

(fn get-option [opt]
  (let [opt (.. "parinfer_" opt)]
    (match (. vim.b opt)
      v v
      nil (. vim.g opt))))

(fn expand-tab-stops [tabstops]
  (when (and tabstops (> (length tabstops) 0))
    (let [xs []]
      (each [_ stop (ipairs tabstops)]
        (table.insert xs (- stop.x 1))
        (table.insert xs (if (= stop.ch "(") (+ stop.x 1) stop.x))
        (when stop.argX
          (table.insert xs (- stop.argX 1))))
      xs)))

(fn next-stop [stops col forward]
  (when (and stops (> (length stops) 0))
    (var left nil)
    (var right nil)
    (each [_ stop (ipairs stops) :until right]
      (when (< col stop)
        (set right stop))
      (when (> col stop)
        (set left stop)))
    (if forward
        right
        left)))

(fn tab [forward]
  (let [stops (expand-tab-stops vim.b.parinfer_tabstops)
        [lnum col] (vim.api.nvim_win_get_cursor 0)
        line (. (vim.api.nvim_buf_get_lines 0 (- lnum 1) lnum true) 1)
        indent (match (line:match "^%s+")
                 s (length s)
                 nil 0)]
    (var next-x nil)
    (when (= col indent)
      (set next-x (next-stop stops col forward)))
    (when (not next-x)
      (set next-x (math.max 0 (+ col (if forward 2 -2)))))
    (let [shift (- next-x col)]
      (if (> shift 0)
          (vim.api.nvim_buf_set_text 0 (- lnum 1) 0 (- lnum 1) 0 [(string.rep " " shift)])
          (vim.api.nvim_buf_set_text 0 (- lnum 1) 0 (- lnum 1) (* -1 shift) [""])))
    (vim.api.nvim_win_set_cursor 0 [lnum next-x])))

(fn invoke-parinfer [text lnum col]
  (let [[prev-lnum prev-col] vim.w.parinfer_prev_cursor
         request {:commentChars (get-option :comment_chars)
                  :prevCursorLine prev-lnum
                  :prevCursorX (+ prev-col 1)
                  :cursorLine lnum
                  :cursorX (+ col 1)
                  :forceBalance (get-option :force_balance)}]
    (log "request" request)
    ((. (require :parinfer) (.. (get-option :mode) :Mode)) text request)))

(fn update-buffer [bufnr lines]
  (vim.api.nvim_command "silent! undojoin")
  (vim.api.nvim_buf_set_lines bufnr 0 -1 true lines))

(fn is-undo-head? []
  (let [{: seq_cur : entries} (vim.fn.undotree)
        [newhead] (icollect [_ v (ipairs entries)] (if (= v.newhead 1) v))]
    (or (not newhead) (= newhead.seq seq_cur))))

(fn process-buffer []
  (when (and (get-option :enabled) (not vim.o.paste) (not vim.o.readonly) vim.o.modifiable)
    (when (and (is-undo-head?) (not= vim.b.changedtick vim.b.parinfer_changedtick))
      (set vim.b.parinfer_changedtick vim.b.changedtick)
      (let [[lnum col] (vim.api.nvim_win_get_cursor 0)
            bufnr (vim.api.nvim_get_current_buf)
            orig-lines (vim.api.nvim_buf_get_lines bufnr 0 -1 true)
            text (table.concat orig-lines "\n")
            response (invoke-parinfer text lnum col)]
        (if response.success
            (do
              (set vim.b.parinfer_tabstops response.tabStops)
              (when (not= response.text text)
                (log "change-response" response)
                (log-diff text response.text)
                (let [lines (vim.split response.text "\n")
                      lnum response.cursorLine
                      col (- response.cursorX 1)]
                  (vim.api.nvim_win_set_cursor 0 [lnum col])
                  (vim.schedule #(update-buffer bufnr lines)))))
            (do
              (log "error-response" response)
              (set vim.g.parinfer_last_error response.error)))))
    (set vim.w.parinfer_prev_cursor (vim.api.nvim_win_get_cursor 0))))

(fn enter-buffer []
  (set vim.w.parinfer_prev_cursor (vim.api.nvim_win_get_cursor 0))
  (set vim.b.parinfer_last_changedtick -1)
  (let [mode vim.g.parinfer_mode]
    (set vim.g.parinfer_mode :paren)
    (process-buffer)
    (set vim.g.parinfer_mode mode)))

(global parinfer {:enter_buffer enter-buffer
                  :process_buffer process-buffer
                  : tab})

(enter-buffer)
