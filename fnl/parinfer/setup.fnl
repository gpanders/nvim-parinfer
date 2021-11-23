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

; Use a table lookup to translate between mode names and functions
; This saves us from having to do a string concatenation on every invocation of
; parinfer, which can be wasteful
(local modes (let [parinfer (require :parinfer)]
               {:indent parinfer.indentMode
                :paren parinfer.parenMode
                :smart parinfer.smartMode}))

(local ns (vim.api.nvim_create_namespace :parinfer))

(fn log [tag data]
  "Log a message to the log file."
  (when vim.g.parinfer_logfile
    (with-open [f (io.open vim.g.parinfer_logfile :a)]
      (f:write (: "%s: %s\n" :format tag (vim.fn.json_encode data))))))

(fn get-option* [opt]
  (match (. vim.b opt)
    v v
    nil (. vim.g opt)))

(macro get-option [opt]
  `(get-option* ,(.. "parinfer_" opt)))

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
  (let [[prev-lnum prev-col] (or vim.b.parinfer_prev_cursor [])
         request {:commentChars (get-option :comment_chars)
                  :prevCursorLine prev-lnum
                  :prevCursorX prev-col
                  :cursorLine lnum
                  :cursorX (+ col 1)
                  :forceBalance (get-option :force_balance)}]
    (log "request" request)
    ((. modes (get-option :mode)) text request)))

(fn update-buffer [bufnr lines]
  (vim.api.nvim_command "silent! undojoin")
  (vim.api.nvim_buf_set_lines bufnr 0 -1 true lines))

(fn highlight-error [bufnr err]
  (vim.api.nvim_buf_clear_namespace bufnr ns 0 -1)
  (when err
    (let [[lnum col] [(- err.lineNo 1) (- err.x 1)]]
      (vim.highlight.range bufnr ns :Error [lnum col] [lnum (+ col 1)] :c))))

(fn is-undo-leaf? []
  (let [{: seq_cur : seq_last} (vim.fn.undotree)]
    (= seq_cur seq_last)))

(fn should-run? []
  (and (get-option :enabled)
       (not vim.o.paste)
       (not vim.bo.readonly)
       vim.bo.modifiable
       (not= vim.b.changedtick vim.b.parinfer_changedtick)
       (is-undo-leaf?)))

(local elapsed-times [])

(fn process-buffer []
  (local start (vim.loop.hrtime))
  (when (should-run?)
    (set vim.b.parinfer_changedtick vim.b.changedtick)
    (let [winnr (vim.api.nvim_get_current_win)
          bufnr (vim.api.nvim_get_current_buf)
          [lnum col] (vim.api.nvim_win_get_cursor winnr)
          orig-lines (vim.api.nvim_buf_get_lines bufnr 0 -1 true)
          text (table.concat orig-lines "\n")
          response (invoke-parinfer text lnum col)
          {:cursorLine new-lnum :cursorX new-col} response]
      (set vim.b.parinfer_tabstops response.tabStops)
      (set vim.b.parinfer_prev_cursor [new-lnum new-col])
      (when (not= response.text text)
        (log "change-response" response)
        (let [lines (vim.split response.text "\n")]
          (vim.schedule #(do
                           (update-buffer bufnr lines)
                           (vim.api.nvim_win_set_cursor winnr [new-lnum (- new-col 1)])))))
      (highlight-error bufnr response.error)
      (when response.error
        (log "error-response" response))))
  (table.insert elapsed-times (- (vim.loop.hrtime) start)))

(fn enter-buffer []
  (set vim.b.parinfer_last_changedtick -1)
  (let [mode vim.g.parinfer_mode]
    (set vim.g.parinfer_mode :paren)
    (process-buffer)
    (set vim.g.parinfer_mode mode)))

(fn stats []
  (local n (length elapsed-times))
  (when (> n 0)
    (var min math.huge)
    (var max 0)
    (var sum 0)
    (var sumsq 0)
    (each [_ v (ipairs elapsed-times)]
      (when (< v min)
        (set min v))
      (when (> v max)
        (set max v))
      (set sum (+ sum v))
      (set sumsq (+ sumsq (* v v))))
    (local avg (/ sum n))
    (local sqsum (* sum sum))
    (local std (math.sqrt (/ (- sumsq (/ sqsum n)) (- n 1))))
    (print (: "N: %d    Min: %0.6fms    Max: %0.6fms    Avg: %0.6fms    Std: %0.6fms"
              :format
              n
              (/ min 1000000) (/ max 1000000) (/ avg 1000000) (/ std 1000000)))))

(global parinfer {:enter_buffer enter-buffer
                  :process_buffer process-buffer
                  : stats
                  : tab})

(vim.api.nvim_command "command! ParinferStats lua parinfer.stats()")
