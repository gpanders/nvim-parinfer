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
        changes (. state bufnr :changes)
        request {:commentChars (get-option :comment_chars)
                 :prevCursorLine prev-lnum
                 :prevCursorX prev-col
                 :cursorLine lnum
                 :cursorX (+ col 1)
                 : changes
                 :forceBalance (true? (get-option :force_balance))}
        response ((. modes (get-option :mode)) text request)]
    (log "request" request)
    (tset state bufnr :changes [])
    response))

(fn update-buffer [bufnr old-contents new-contents]
  (api.nvim_command "silent! undojoin")
  (tset state bufnr :locked true)
  (let [new-lines (vim.split new-contents "\n")
        hunks (vim.diff old-contents new-contents {:result_type :indices})]
    (each [_ [start-a count-a start-b count-b] (ipairs hunks)]
      (let [lines (fcollect [i start-b (+ start-b count-b)]
                    (. new-lines i))]
        (api.nvim_buf_set_lines bufnr (- start-a 1) (+ start-a count-a) false lines))))
  (vim.schedule #(tset state bufnr :locked false)))

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
       (not (. state bufnr :locked))
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
    (let [start (vim.loop.hrtime)
          winnr (api.nvim_get_current_win)
          [lnum col] (api.nvim_win_get_cursor winnr)
          contents (vim.api.nvim_buf_get_lines bufnr 0 -1 true)
          text (table.concat contents "\n")
          response (invoke-parinfer bufnr text lnum col)
          {:cursorLine new-lnum :cursorX new-col} response]
      (tset state bufnr :changedtick (. vim.b bufnr :changedtick))
      (tset state bufnr :tabstops response.tabStops)
      (tset state bufnr :prev-cursor [new-lnum new-col])
      (when (not= response.text text)
        (log "change-response" response)
        (vim.schedule #(do
                         (update-buffer bufnr text response.text)
                         (api.nvim_win_set_cursor winnr [new-lnum (- new-col 1)]))))
      (highlight-error bufnr response.error)
      (when response.error
        (log "error-response" response))
      (table.insert (. elapsed-times bufnr) (- (vim.loop.hrtime) start)))))

(fn slice [lines start-row start-col row-offset col-offset]
  "Return the range from lines between (start-row, start-col) and
  (start-row + row-offset, start-col + col-offset)."
  (let [start-row (+ start-row 1)
        start-col (+ start-col 1)
        first-line (string.sub (. lines start-row) start-col (if (= 0 row-offset) (- (+ start-col col-offset) 1) -1))
        out [first-line]]
    (for [i (+ start-row 1) (- (+ start-row row-offset) 1)]
      (let [line (. lines i)]
        (table.insert out line)))
    (when (not= 0 row-offset)
      (table.insert out (if (and (< 0 col-offset) (. lines (+ start-row row-offset)))
                            (string.sub (. lines (+ start-row row-offset)) 1 col-offset)
                            ; If col-offset is zero then the last row in the
                            ; range is just an empty string
                            "")))
    out))

(fn on-bytes [_ bufnr _ start-row start-col _ old-end-row old-end-col _ new-end-row new-end-col]
  (when (and (true? (get-option :enabled)) (not (. state bufnr :locked)))
    (let [{: prev-contents} (. state bufnr)
          contents (vim.api.nvim_buf_get_lines bufnr 0 -1 true)]
      ; If start row is greater than the length of prev-contents that means we
      ; are adding a new line to the end of the buffer, so there are no
      ; "changes"
      (when (< start-row (length prev-contents))
        (let [old-text (slice prev-contents start-row start-col old-end-row old-end-col)
              new-text (if (< start-row (length contents))
                           (slice contents start-row start-col new-end-row new-end-col)
                           ; If start row is greater than the length of
                           ; contents that means we are deleting a line from
                           ; the end of the buffer, so the new text is just an
                           ; empty string
                           [""])]
          (when (not (. state bufnr :changes))
            (tset state bufnr :changes []))
          (table.insert (. state bufnr :changes) {:oldText (table.concat old-text "\n")
                                                  :newText (table.concat new-text "\n")
                                                  :lineNo (+ start-row 1)
                                                  :x (+ start-col 1)})))
      (tset state bufnr :prev-contents contents))))

(fn enter-buffer []
  (let [bufnr (vim.api.nvim_get_current_buf)
        contents (vim.api.nvim_buf_get_lines bufnr 0 -1 true)]
    (tset state bufnr :changedtick -1)
    (tset state bufnr :prev-contents contents)
    (vim.api.nvim_buf_attach bufnr false {:on_bytes on-bytes})
    (let [mode vim.g.parinfer_mode]
      (set vim.g.parinfer_mode :paren)
      (process-buffer bufnr)
      (set vim.g.parinfer_mode mode))))

(fn cursor-moved [bufnr]
  (vim.schedule #(let [[lnum col] (vim.api.nvim_win_get_cursor 0)]
                   (tset state bufnr :prev-cursor [lnum (+ col 1)]))))

(fn text-changed [bufnr]
  (process-buffer bufnr))

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
                  :cursor_moved cursor-moved
                  :text_changed text-changed
                  : stats
                  : tab})
