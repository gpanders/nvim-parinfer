local api = vim.api
local diff = (vim.text.diff or vim.diff)
local modes
do
  local parinfer = require("parinfer")
  modes = {indent = parinfer.indentMode, paren = parinfer.parenMode, smart = parinfer.smartMode}
end
local ns = api.nvim_create_namespace("parinfer")
local state
local function _1_(t, k)
  t[k] = {}
  return t[k]
end
state = setmetatable({}, {__index = _1_})
local function true_3f(val)
  local and_2_ = (nil ~= val)
  if and_2_ then
    local n = val
    and_2_ = (type(n) == "boolean")
  end
  if and_2_ then
    local n = val
    return n
  elseif (nil ~= val) then
    local n = val
    return (n ~= 0)
  else
    return nil
  end
end
local function log(tag, data)
  if vim.g.parinfer_logfile then
    local f = io.open(vim.g.parinfer_logfile, "a")
    local function close_handlers_12_(ok_13_, ...)
      f:close()
      if ok_13_ then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _6_()
      return f:write(("%s: %s\n"):format(tag, vim.fn.json_encode(data)))
    end
    local _8_
    do
      local t_7_ = _G
      if (nil ~= t_7_) then
        t_7_ = t_7_.package
      else
      end
      if (nil ~= t_7_) then
        t_7_ = t_7_.loaded
      else
      end
      if (nil ~= t_7_) then
        t_7_ = t_7_.fennel
      else
      end
      _8_ = t_7_
    end
    local or_12_ = _8_ or _G.debug
    if not or_12_ then
      local function _13_()
        return ""
      end
      or_12_ = {traceback = _13_}
    end
    return close_handlers_12_(_G.xpcall(_6_, or_12_.traceback))
  else
    return nil
  end
end
local function get_option_2a(opt)
  local _15_ = vim.b[opt]
  if (nil ~= _15_) then
    local v = _15_
    return v
  elseif (_15_ == nil) then
    return vim.g[opt]
  else
    return nil
  end
end
local function expand_tab_stops(tabstops)
  if (tabstops and (#tabstops > 0)) then
    local xs = {}
    for _, stop in ipairs(tabstops) do
      table.insert(xs, (stop.x - 1))
      local function _17_()
        if (stop.ch == "(") then
          return (stop.x + 1)
        else
          return stop.x
        end
      end
      table.insert(xs, _17_())
      if stop.argX then
        table.insert(xs, (stop.argX - 1))
      else
      end
    end
    return xs
  else
    return nil
  end
end
local function next_stop(stops, col, forward)
  if (stops and (#stops > 0)) then
    local left = nil
    local right = nil
    for _, stop in ipairs(stops) do
      if right then break end
      if (col < stop) then
        right = stop
      else
      end
      if (col > stop) then
        left = stop
      else
      end
    end
    if forward then
      return right
    else
      return left
    end
  else
    return nil
  end
end
local function tab(forward)
  local bufnr = vim.api.nvim_get_current_buf()
  local stops = expand_tab_stops(state[bufnr].tabstops)
  local _let_24_ = api.nvim_win_get_cursor(0)
  local lnum = _let_24_[1]
  local col = _let_24_[2]
  local line = api.nvim_buf_get_lines(0, (lnum - 1), lnum, true)[1]
  local indent
  do
    local _25_ = line:match("^%s+")
    if (nil ~= _25_) then
      local s = _25_
      indent = #s
    elseif (_25_ == nil) then
      indent = 0
    else
      indent = nil
    end
  end
  local next_x = nil
  if (col == indent) then
    next_x = next_stop(stops, col, forward)
  else
  end
  if not next_x then
    local _28_
    if forward then
      _28_ = 2
    else
      _28_ = -2
    end
    next_x = math.max(0, (col + _28_))
  else
  end
  do
    local shift = (next_x - col)
    if (shift > 0) then
      api.nvim_buf_set_text(0, (lnum - 1), 0, (lnum - 1), 0, {string.rep(" ", shift)})
    else
      api.nvim_buf_set_text(0, (lnum - 1), 0, (lnum - 1), (-1 * shift), {""})
    end
  end
  return api.nvim_win_set_cursor(0, {lnum, next_x})
end
local function invoke_parinfer(bufnr, text, lnum, col)
  local _let_32_ = (state[bufnr]["prev-cursor"] or {})
  local prev_lnum = _let_32_[1]
  local prev_col = _let_32_[2]
  local changes = state[bufnr].changes
  local request = {commentChars = get_option_2a("parinfer_comment_chars"), prevCursorLine = prev_lnum, prevCursorX = prev_col, cursorLine = lnum, cursorX = (col + 1), changes = changes, forceBalance = true_3f(get_option_2a("parinfer_force_balance"))}
  local response = modes[get_option_2a("parinfer_mode")](text, request)
  log("request", request)
  state[bufnr]["changes"] = {}
  return response
end
local function update_buffer(bufnr, old_contents, new_contents)
  api.nvim_command("silent! undojoin")
  state[bufnr]["locked"] = true
  do
    local new_lines = vim.split(new_contents, "\n")
    local hunks = diff(old_contents, new_contents, {result_type = "indices"})
    for _, _33_ in ipairs(hunks) do
      local start_a = _33_[1]
      local count_a = _33_[2]
      local start_b = _33_[3]
      local count_b = _33_[4]
      local lines
      do
        local tbl_21_ = {}
        local i_22_ = 0
        for i = start_b, (start_b + count_b) do
          local val_23_ = new_lines[i]
          if (nil ~= val_23_) then
            i_22_ = (i_22_ + 1)
            tbl_21_[i_22_] = val_23_
          else
          end
        end
        lines = tbl_21_
      end
      api.nvim_buf_set_lines(bufnr, (start_a - 1), (start_a + count_a), false, lines)
    end
  end
  local function _35_()
    state[bufnr]["locked"] = false
    return nil
  end
  return vim.schedule(_35_)
end
local function highlight_error(bufnr, err)
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  if err then
    local lnum,col = (err.lineNo - 1), (err.x - 1)
    return vim.highlight.range(bufnr, ns, "Error", {lnum, col}, {lnum, (col + 1)}, "c")
  else
    return nil
  end
end
local function is_undo_leaf_3f()
  local _let_37_ = vim.fn.undotree()
  local seq_cur = _let_37_["seq_cur"]
  local seq_last = _let_37_["seq_last"]
  return (seq_cur == seq_last)
end
local function should_run_3f(bufnr)
  return (true_3f(get_option_2a("parinfer_enabled")) and not state[bufnr].locked and not vim.o.paste and not vim.bo.readonly and vim.bo.modifiable and (vim.b[bufnr].changedtick ~= state[bufnr].changedtick) and is_undo_leaf_3f())
end
local elapsed_times
local function _38_(t, k)
  t[k] = {}
  return rawget(t, k)
end
elapsed_times = setmetatable({}, {__index = _38_})
local function process_buffer(bufnr)
  if should_run_3f(bufnr) then
    local start = vim.loop.hrtime()
    local winnr = api.nvim_get_current_win()
    local _let_39_ = api.nvim_win_get_cursor(winnr)
    local lnum = _let_39_[1]
    local col = _let_39_[2]
    local contents = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local text = table.concat(contents, "\n")
    local response = invoke_parinfer(bufnr, text, lnum, col)
    local new_lnum = response["cursorLine"]
    local new_col = response["cursorX"]
    state[bufnr]["changedtick"] = vim.b[bufnr].changedtick
    state[bufnr]["tabstops"] = response.tabStops
    state[bufnr]["prev-cursor"] = {new_lnum, new_col}
    if (response.text ~= text) then
      log("change-response", response)
      local function _40_()
        update_buffer(bufnr, text, response.text)
        return api.nvim_win_set_cursor(winnr, {new_lnum, (new_col - 1)})
      end
      vim.schedule(_40_)
    else
    end
    highlight_error(bufnr, response.error)
    if response.error then
      log("error-response", response)
    else
    end
    return table.insert(elapsed_times[bufnr], (vim.loop.hrtime() - start))
  else
    return nil
  end
end
local function slice(lines, start_row, start_col, row_offset, col_offset)
  local start_row0 = (start_row + 1)
  local start_col0 = (start_col + 1)
  local first_line
  local function _44_()
    if (0 == row_offset) then
      return ((start_col0 + col_offset) - 1)
    else
      return -1
    end
  end
  first_line = string.sub(lines[start_row0], start_col0, _44_())
  local out = {first_line}
  for i = (start_row0 + 1), ((start_row0 + row_offset) - 1) do
    local line = lines[i]
    table.insert(out, line)
  end
  if (0 ~= row_offset) then
    local function _45_()
      if ((0 < col_offset) and lines[(start_row0 + row_offset)]) then
        return string.sub(lines[(start_row0 + row_offset)], 1, col_offset)
      else
        return ""
      end
    end
    table.insert(out, _45_())
  else
  end
  return out
end
local function on_bytes(_, bufnr, _0, start_row, start_col, _1, old_end_row, old_end_col, _2, new_end_row, new_end_col)
  if (true_3f(get_option_2a("parinfer_enabled")) and not state[bufnr].locked) then
    local _let_47_ = state[bufnr]
    local prev_contents = _let_47_["prev-contents"]
    local contents = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    if (start_row < #prev_contents) then
      local old_text = slice(prev_contents, start_row, start_col, old_end_row, old_end_col)
      local new_text
      if (start_row < #contents) then
        new_text = slice(contents, start_row, start_col, new_end_row, new_end_col)
      else
        new_text = {""}
      end
      if not state[bufnr].changes then
        state[bufnr]["changes"] = {}
      else
      end
      table.insert(state[bufnr].changes, {oldText = table.concat(old_text, "\n"), newText = table.concat(new_text, "\n"), lineNo = (start_row + 1), x = (start_col + 1)})
    else
    end
    state[bufnr]["prev-contents"] = contents
    return nil
  else
    return nil
  end
end
local function enter_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local contents = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  state[bufnr]["changedtick"] = -1
  state[bufnr]["prev-contents"] = contents
  vim.api.nvim_buf_attach(bufnr, false, {on_bytes = on_bytes})
  local mode = vim.g.parinfer_mode
  vim.g.parinfer_mode = "paren"
  process_buffer(bufnr)
  vim.g.parinfer_mode = mode
  return nil
end
local function cursor_moved(bufnr)
  local function _52_()
    local _let_53_ = vim.api.nvim_win_get_cursor(0)
    local lnum = _let_53_[1]
    local col = _let_53_[2]
    state[bufnr]["prev-cursor"] = {lnum, (col + 1)}
    return nil
  end
  return vim.schedule(_52_)
end
local function text_changed(bufnr)
  return process_buffer(bufnr)
end
local function stats()
  local bufnr = api.nvim_get_current_buf()
  local times = elapsed_times[bufnr]
  local n = #times
  if (n > 0) then
    local min = math.huge
    local max = 0
    local sum = 0
    local sumsq = 0
    for _, v in ipairs(times) do
      if (v < min) then
        min = v
      else
      end
      if (v > max) then
        max = v
      else
      end
      sum = (sum + v)
      sumsq = (sumsq + (v * v))
    end
    local avg = (sum / n)
    local sqsum = (sum * sum)
    local std = math.sqrt(((sumsq - (sqsum / n)) / (n - 1)))
    return print(("N: %d    Min: %0.6fms    Max: %0.6fms    Avg: %0.6fms    Std: %0.6fms"):format(n, (min / 1000000), (max / 1000000), (avg / 1000000), (std / 1000000)))
  else
    return nil
  end
end
parinfer = {enter_buffer = enter_buffer, cursor_moved = cursor_moved, text_changed = text_changed, stats = stats, tab = tab}
return nil
