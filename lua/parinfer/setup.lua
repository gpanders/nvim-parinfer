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
      return f:write(("%20s: %s"):format(tag, vim.fn.json_encode(data)))
    end
    return close_handlers_7_auto(xpcall(_2_, (package.loaded.fennel or debug).traceback))
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
    local function _5_()
      return f:write(diff)
    end
    return close_handlers_7_auto(xpcall(_5_, (package.loaded.fennel or debug).traceback))
  end
end
local function get_option(opt)
  local opt0 = ("parinfer_" .. opt)
  local _7_ = vim.b[opt0]
  if (nil ~= _7_) then
    local v = _7_
    return v
  elseif (_7_ == nil) then
    return vim.g[opt0]
  end
end
local function invoke_parinfer(text, lnum, col)
  local _let_9_ = vim.w.parinfer_prev_cursor
  local prev_lnum = _let_9_[1]
  local prev_col = _let_9_[2]
  local request = {commentChars = get_option("comment_chars"), cursorLine = lnum, cursorX = (col + 1), forceBalance = get_option("force_balance"), prevCursorLine = prev_lnum, prevCursorX = (prev_col + 1)}
  log("request", request)
  return (require("parinfer"))[(get_option("mode") .. "Mode")](text, request)
end
local function update_buffer(bufnr, lines)
  vim.api.nvim_command("silent! undojoin")
  return vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
end
local function process_buffer()
  if (get_option("enabled") and not vim.o.paste and vim.o.modifiable) then
    if (vim.b.changedtick ~= vim.b.parinfer_changedtick) then
      vim.b.parinfer_changedtick = vim.b.changedtick
      local _let_10_ = vim.api.nvim_win_get_cursor(0)
      local lnum = _let_10_[1]
      local col = _let_10_[2]
      local bufnr = vim.api.nvim_get_current_buf()
      local orig_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
      local text = table.concat(orig_lines, "\n")
      local response = invoke_parinfer(text, lnum, col)
      if response.success then
        if (response.text ~= text) then
          log("change-response", response)
          log_diff(text, response.text)
          local lines = vim.split(response.text, "\n")
          local lnum0 = response.cursorLine
          local col0 = (response.cursorX - 1)
          vim.api.nvim_win_set_cursor(0, {lnum0, col0})
          local function _11_()
            return update_buffer(bufnr, lines)
          end
          vim.schedule(_11_)
        end
      else
        log("error-response", response)
        vim.g.parinfer_last_error = response.error
      end
    end
    vim.w.parinfer_prev_cursor = vim.api.nvim_win_get_cursor(0)
    return nil
  end
end
local function enter_buffer()
  vim.w.parinfer_prev_cursor = vim.api.nvim_win_get_cursor(0)
  vim.b.parinfer_last_changedtick = -1
  local mode = vim.g.parinfer_mode
  vim.g.parinfer_mode = "paren"
  process_buffer()
  vim.g.parinfer_mode = mode
  return nil
end
parinfer = {enter_buffer = enter_buffer, process_buffer = process_buffer}
return enter_buffer()
