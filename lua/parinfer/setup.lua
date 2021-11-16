local modes
do
  local parinfer = require("parinfer")
  modes = {indent = parinfer.indentMode, paren = parinfer.parenMode, smart = parinfer.smartMode}
end
local function log(tag, data)
  if vim.g.parinfer_logfile then
    local f = io.open(vim.g.parinfer_logfile, "a")
    local function close_handlers_7_auto(ok_8_auto, ...)
      f:close()
      if ok_8_auto then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _2_()
      return f:write(("%s: %s\n"):format(tag, vim.fn.json_encode(data)))
    end
    return close_handlers_7_auto(xpcall(_2_, (package.loaded.fennel or debug).traceback))
  end
end
local function get_option_2a(opt)
  local _4_ = vim.b[opt]
  if (nil ~= _4_) then
    local v = _4_
    return v
  elseif (_4_ == nil) then
    return vim.g[opt]
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
      end
    end
    return xs
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
      end
      if (col > stop) then
        left = stop
      end
    end
    if forward then
      return right
    else
      return left
    end
  end
end
local function tab(forward)
  local stops = expand_tab_stops(vim.b.parinfer_tabstops)
  local _let_13_ = vim.api.nvim_win_get_cursor(0)
  local lnum = _let_13_[1]
  local col = _let_13_[2]
  local line = (vim.api.nvim_buf_get_lines(0, (lnum - 1), lnum, true))[1]
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
  end
  if not next_x then
    local _17_
    if forward then
      _17_ = 2
    else
      _17_ = -2
    end
    next_x = math.max(0, (col + _17_))
  end
  do
    local shift = (next_x - col)
    if (shift > 0) then
      vim.api.nvim_buf_set_text(0, (lnum - 1), 0, (lnum - 1), 0, {string.rep(" ", shift)})
    else
      vim.api.nvim_buf_set_text(0, (lnum - 1), 0, (lnum - 1), (-1 * shift), {""})
    end
  end
  return vim.api.nvim_win_set_cursor(0, {lnum, next_x})
end
local function invoke_parinfer(text, lnum, col)
  local _let_21_ = (vim.b.parinfer_prev_cursor or {})
  local prev_lnum = _let_21_[1]
  local prev_col = _let_21_[2]
  local request
  local _22_
  if prev_col then
    _22_ = (prev_col + 1)
  else
  _22_ = nil
  end
  request = {commentChars = get_option_2a("parinfer_comment_chars"), cursorLine = lnum, cursorX = (col + 1), forceBalance = get_option_2a("parinfer_force_balance"), prevCursorLine = prev_lnum, prevCursorX = _22_}
  log("request", request)
  return modes[get_option_2a("parinfer_mode")](text, request)
end
local function update_buffer(bufnr, lines)
  vim.api.nvim_command("silent! undojoin")
  return vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end
local function is_undo_leaf_3f()
  local _let_24_ = vim.fn.undotree()
  local seq_cur = _let_24_["seq_cur"]
  local seq_last = _let_24_["seq_last"]
  return (seq_cur == seq_last)
end
local function should_run_3f()
  return (get_option_2a("parinfer_enabled") and not vim.o.paste and not vim.bo.readonly and vim.bo.modifiable and (vim.bo.buftype ~= "prompt") and is_undo_leaf_3f() and (vim.b.changedtick ~= vim.b.parinfer_changedtick))
end
local elapsed_times = {}
local function process_buffer()
  local start = vim.loop.hrtime()
  if should_run_3f() then
    vim.b.parinfer_changedtick = vim.b.changedtick
    local _let_25_ = vim.api.nvim_win_get_cursor(0)
    local lnum = _let_25_[1]
    local col = _let_25_[2]
    local bufnr = vim.api.nvim_get_current_buf()
    local orig_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local text = table.concat(orig_lines, "\n")
    local response = invoke_parinfer(text, lnum, col)
    if response.success then
      local lnum0 = response.cursorLine
      local col0 = (response.cursorX - 1)
      vim.b.parinfer_tabstops = response.tabStops
      vim.b.parinfer_prev_cursor = {lnum0, col0}
      if (response.text ~= text) then
        log("change-response", response)
        local lines = vim.split(response.text, "\n")
        vim.api.nvim_win_set_cursor(0, {lnum0, col0})
        local function _26_()
          return update_buffer(bufnr, lines)
        end
        vim.schedule(_26_)
      end
    else
      log("error-response", response)
      vim.g.parinfer_last_error = response.error
    end
  end
  return table.insert(elapsed_times, (vim.loop.hrtime() - start))
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
  local n = #elapsed_times
  if (n > 0) then
    local min = math.huge
    local max = 0
    local sum = 0
    local sumsq = 0
    for _, v in ipairs(elapsed_times) do
      if (v < min) then
        min = v
      end
      if (v > max) then
        max = v
      end
      sum = (sum + v)
      sumsq = (sumsq + (v * v))
    end
    local avg = (sum / n)
    local sqsum = (sum * sum)
    local std = math.sqrt(((sumsq - (sqsum / n)) / (n - 1)))
    return print(("N: %d    Min: %0.6fms    Max: %0.6fms    Avg: %0.6fms    Std: %0.6fms"):format(n, (min / 1000000), (max / 1000000), (avg / 1000000), (std / 1000000)))
  end
end
parinfer = {enter_buffer = enter_buffer, process_buffer = process_buffer, stats = stats, tab = tab}
return vim.api.nvim_command("command! ParinferStats lua parinfer.stats()")
