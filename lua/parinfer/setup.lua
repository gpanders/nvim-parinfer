local api = vim.api
local modes
do
  local parinfer = require("parinfer")
  modes = {indent = parinfer.indentMode, paren = parinfer.parenMode, smart = parinfer.smartMode}
end
local ns = api.nvim_create_namespace("parinfer")
local function log(tag, data)
  if vim.g.parinfer_logfile then
    local f = io.open(vim.g.parinfer_logfile, "a")
    local function close_handlers_8_auto(ok_9_auto, ...)
      f:close()
      if ok_9_auto then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _2_()
      return f:write(("%s: %s\n"):format(tag, vim.fn.json_encode(data)))
    end
    return close_handlers_8_auto(_G.xpcall(_2_, (package.loaded.fennel or debug).traceback))
  else
    return nil
  end
end
local function get_option_2a(opt)
  local _4_ = vim.b[opt]
  if (nil ~= _4_) then
    local v = _4_
    return v
  elseif (_4_ == nil) then
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
      local function _6_()
        if (stop.ch == "(") then
          return (stop.x + 1)
        else
          return stop.x
        end
      end
      table.insert(xs, _6_())
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
  local stops = expand_tab_stops(vim.b.parinfer_tabstops)
  local _let_13_ = api.nvim_win_get_cursor(0)
  local lnum = _let_13_[1]
  local col = _let_13_[2]
  local line = (api.nvim_buf_get_lines(0, (lnum - 1), lnum, true))[1]
  local indent
  do
    local _14_ = line:match("^%s+")
    if (nil ~= _14_) then
      local s = _14_
      indent = #s
    elseif (_14_ == nil) then
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
    local function _17_()
      if forward then
        return 2
      else
        return -2
      end
    end
    next_x = math.max(0, (col + _17_()))
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
local function invoke_parinfer(text, lnum, col)
  local _let_20_ = (vim.b.parinfer_prev_cursor or {})
  local prev_lnum = _let_20_[1]
  local prev_col = _let_20_[2]
  local request = {commentChars = get_option_2a("parinfer_comment_chars"), prevCursorLine = prev_lnum, prevCursorX = prev_col, cursorLine = lnum, cursorX = (col + 1), forceBalance = get_option_2a("parinfer_force_balance")}
  log("request", request)
  return modes[get_option_2a("parinfer_mode")](text, request)
end
local function update_buffer(bufnr, lines)
  api.nvim_command("silent! undojoin")
  return api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end
local function highlight_error(bufnr, err)
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  if err then
    local _let_21_ = {(err.lineNo - 1), (err.x - 1)}
    local lnum = _let_21_[1]
    local col = _let_21_[2]
    return vim.highlight.range(bufnr, ns, "Error", {lnum, col}, {lnum, (col + 1)}, "c")
  else
    return nil
  end
end
local function is_undo_leaf_3f()
  local _let_23_ = vim.fn.undotree()
  local seq_cur = _let_23_["seq_cur"]
  local seq_last = _let_23_["seq_last"]
  return (seq_cur == seq_last)
end
local function should_run_3f()
  return (get_option_2a("parinfer_enabled") and not vim.o.paste and not vim.bo.readonly and vim.bo.modifiable and (vim.b.changedtick ~= vim.b.parinfer_changedtick) and is_undo_leaf_3f())
end
local elapsed_times
local function _24_(t, k)
  t[k] = {}
  return rawget(t, k)
end
elapsed_times = setmetatable({}, {__index = _24_})
local function process_buffer()
  local start = vim.loop.hrtime()
  local bufnr = api.nvim_get_current_buf()
  if should_run_3f() then
    vim.b.parinfer_changedtick = vim.b.changedtick
    local winnr = api.nvim_get_current_win()
    local _let_25_ = api.nvim_win_get_cursor(winnr)
    local lnum = _let_25_[1]
    local col = _let_25_[2]
    local orig_lines = api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local text = table.concat(orig_lines, "\n")
    local response = invoke_parinfer(text, lnum, col)
    local _let_26_ = response
    local new_lnum = _let_26_["cursorLine"]
    local new_col = _let_26_["cursorX"]
    vim.b.parinfer_tabstops = response.tabStops
    vim.b.parinfer_prev_cursor = {new_lnum, new_col}
    if (response.text ~= text) then
      log("change-response", response)
      local lines = vim.split(response.text, "\n")
      local function _27_()
        update_buffer(bufnr, lines)
        return api.nvim_win_set_cursor(winnr, {new_lnum, (new_col - 1)})
      end
      vim.schedule(_27_)
    else
    end
    highlight_error(bufnr, response.error)
    if response.error then
      log("error-response", response)
    else
    end
  else
  end
  return table.insert(elapsed_times[bufnr], (vim.loop.hrtime() - start))
end
local function enter_buffer()
  vim.b.parinfer_last_changedtick = -1
  local mode = vim.g.parinfer_mode
  vim.g.parinfer_mode = "paren"
  process_buffer()
  vim.g.parinfer_mode = mode
  return nil
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
parinfer = {enter_buffer = enter_buffer, process_buffer = process_buffer, stats = stats, tab = tab}
return nil
