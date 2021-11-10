local modes
local function _1_()
  local parinfer = require("parinfer")
  return {indent = parinfer.indentMode, paren = parinfer.parenMode, smart = parinfer.smartMode}
end
modes = _1_()
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
    local function _3_()
      return f:write(("%20s: %s"):format(tag, vim.fn.json_encode(data)))
    end
    return close_handlers_7_auto(xpcall(_3_, (package.loaded.fennel or debug).traceback))
  end
end
local function log_diff(from, to)
  if (vim.g.parinfer_logfile and vim.fn.has("nvim-0.6.0")) then
    local diff = vim.diff(from, to)
    local f = io.open(vim.g.parinfer_logfile, "a")
    local function close_handlers_7_auto(ok_8_auto, ...)
      f:close()
      if ok_8_auto then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _6_()
      return f:write(diff)
    end
    return close_handlers_7_auto(xpcall(_6_, (package.loaded.fennel or debug).traceback))
  end
end
local function get_option_2a(opt)
  local _8_ = vim.b[opt]
  if (nil ~= _8_) then
    local v = _8_
    return v
  elseif (_8_ == nil) then
    return vim.g[opt]
  end
end
local function expand_tab_stops(tabstops)
  if (tabstops and (#tabstops > 0)) then
    local xs = {}
    for _, stop in ipairs(tabstops) do
      table.insert(xs, (stop.x - 1))
      local function _10_()
        if (stop.ch == "(") then
          return (stop.x + 1)
        else
          return stop.x
        end
      end
      table.insert(xs, _10_())
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
  local _let_17_ = vim.api.nvim_win_get_cursor(0)
  local lnum = _let_17_[1]
  local col = _let_17_[2]
  local line = (vim.api.nvim_buf_get_lines(0, (lnum - 1), lnum, true))[1]
  local indent
  do
    local _18_ = line:match("^%s+")
    if (nil ~= _18_) then
      local s = _18_
      indent = #s
    elseif (_18_ == nil) then
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
    local _21_
    if forward then
      _21_ = 2
    else
      _21_ = -2
    end
    next_x = math.max(0, (col + _21_))
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
  local _let_25_ = (vim.b.parinfer_prev_cursor or {})
  local prev_lnum = _let_25_[1]
  local prev_col = _let_25_[2]
  local request
  local _26_
  if prev_col then
    _26_ = (prev_col + 1)
  else
  _26_ = nil
  end
  request = {commentChars = get_option_2a("parinfer_comment_chars"), cursorLine = lnum, cursorX = (col + 1), forceBalance = get_option_2a("parinfer_force_balance"), prevCursorLine = prev_lnum, prevCursorX = _26_}
  log("request", request)
  return modes[get_option_2a("parinfer_mode")](text, request)
end
local function update_buffer(bufnr, lines)
  vim.api.nvim_command("silent! undojoin")
  return vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end
local function is_undo_leaf_3f()
  local _let_28_ = vim.fn.undotree()
  local seq_cur = _let_28_["seq_cur"]
  local seq_last = _let_28_["seq_last"]
  return (seq_cur == seq_last)
end
local function should_run_3f()
  return (get_option_2a("parinfer_enabled") and not vim.o.paste and not vim.bo.readonly and vim.bo.modifiable and (vim.bo.buftype ~= "prompt") and is_undo_leaf_3f() and (vim.b.changedtick ~= vim.b.parinfer_changedtick))
end
local function process_buffer()
  if should_run_3f() then
    vim.b.parinfer_changedtick = vim.b.changedtick
    local _let_29_ = vim.api.nvim_win_get_cursor(0)
    local lnum = _let_29_[1]
    local col = _let_29_[2]
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
        log_diff(text, response.text)
        local lines = vim.split(response.text, "\n")
        vim.api.nvim_win_set_cursor(0, {lnum0, col0})
        local function _30_()
          return update_buffer(bufnr, lines)
        end
        return vim.schedule(_30_)
      end
    else
      log("error-response", response)
      vim.g.parinfer_last_error = response.error
      return nil
    end
  end
end
local function enter_buffer()
  vim.b.parinfer_last_changedtick = -1
  local mode = vim.g.parinfer_mode
  vim.g.parinfer_mode = "paren"
  process_buffer()
  vim.g.parinfer_mode = mode
  return nil
end
parinfer = {enter_buffer = enter_buffer, process_buffer = process_buffer, tab = tab}
return nil
