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

(local api vim.api)

; Use a table lookup to translate between mode names and functions
; This saves us from having to do a string concatenation on every invocation of
; parinfer, which can be wasteful
(local modes (let [parinfer (require :parinfer)]
               {:indent parinfer.indentMode
                :paren parinfer.parenMode
                :smart parinfer.smartMode}))

(local ns (api.nvim_create_namespace :parinfer))

(local state (setmetatable {} {:__index (fn [t k]
                                          (tset t k {})
                                          (. t k))}))

(fn true? [val]
  (match val
    (where n (= (type n) :boolean)) n
    n (not= n 0)))

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
  (let [bufnr (vim.api.nvim_get_current_buf)
        stops (expand-tab-stops (. state bufnr :tabstops))
        [lnum col] (api.nvim_win_get_cursor 0)
        line (. (api.nvim_buf_get_lines 0 (- lnum 1) lnum true) 1)
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
          (api.nvim_buf_set_text 0 (- lnum 1) 0 (- lnum 1) 0 [(string.rep " " shift)])
          (api.nvim_buf_set_text 0 (- lnum 1) 0 (- lnum 1) (* -1 shift) [""])))
    (api.nvim_win_set_cursor 0 [lnum next-x])))

(fn invoke-parinfer [bufnr text lnum col]
  (let [[prev-lnum prev-col] (or (. state bufnr :prev-cursor) [])
         request {:commentChars (get-option :comment_chars)
                  :prevCursorLine prev-lnum
                  :prevCursorX prev-col
                  :cursorLine lnum
                  :cursorX (+ col 1)
                  :forceBalance (true? (get-option :force_balance))}]
    (log "request" request)
    ((. modes (get-option :mode)) text request)))

(fn update-buffer [bufnr lines]
  (api.nvim_command "silent! undojoin")
  (api.nvim_buf_set_lines bufnr 0 -1 true lines))

(fn highlight-error [bufnr err]
  (api.nvim_buf_clear_namespace bufnr ns 0 -1)
  (when err
    (let [[lnum col] [(- err.lineNo 1) (- err.x 1)]]
      (vim.highlight.range bufnr ns :Error [lnum col] [lnum (+ col 1)] :c))))

(fn is-undo-leaf? []
  (let [{: seq_cur : seq_last} (vim.fn.undotree)]
    (= seq_cur seq_last)))

(fn should-run? [bufnr]
  (and (true? (get-option :enabled))
       (not vim.o.paste)
       (not vim.bo.readonly)
       vim.bo.modifiable
       (not= (. vim.b bufnr :changedtick) (. state bufnr :changedtick))
       (is-undo-leaf?)))

(local elapsed-times (setmetatable {}
                                   {:__index (fn [t k]
                                               (tset t k [])
                                               (rawget t k))}))

(fn process-buffer [bufnr]
  (when (should-run? bufnr)
    (tset state bufnr :changedtick (. vim.b bufnr :changedtick))
    (let [start (vim.loop.hrtime)
          winnr (api.nvim_get_current_win)
          [lnum col] (api.nvim_win_get_cursor winnr)
          contents (vim.api.nvim_buf_get_lines bufnr 0 -1 true)
          text (table.concat contents "\n")
          response (invoke-parinfer bufnr text lnum col)
          {:cursorLine new-lnum :cursorX new-col} response]
      (tset state bufnr :tabstops response.tabStops)
      (tset state bufnr :prev-cursor [new-lnum new-col])
      (when (not= response.text text)
        (log "change-response" response)
        (let [lines (vim.split response.text "\n")]
          (vim.schedule #(do
                           (update-buffer bufnr lines)
                           (api.nvim_win_set_cursor winnr [new-lnum (- new-col 1)])))))
      (highlight-error bufnr response.error)
      (when response.error
        (log "error-response" response))
      (table.insert (. elapsed-times bufnr) (- (vim.loop.hrtime) start)))))

(fn enter-buffer []
  (let [bufnr (vim.api.nvim_get_current_buf)]
    (tset state bufnr :changedtick -1)
    (let [mode vim.g.parinfer_mode]
      (set vim.g.parinfer_mode :paren)
      (process-buffer bufnr)
      (set vim.g.parinfer_mode mode))))

(fn stats []
  (let [bufnr (api.nvim_get_current_buf)
        times (. elapsed-times bufnr)
        n (length times)]
    (when (> n 0)
      (var min math.huge)
      (var max 0)
      (var sum 0)
      (var sumsq 0)
      (each [_ v (ipairs times)]
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
                (/ min 1000000) (/ max 1000000) (/ avg 1000000) (/ std 1000000))))))

(global parinfer {:enter_buffer enter-buffer
                  :process_buffer process-buffer
                  : stats
                  : tab})
