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
local function invoke_parinfer(text, lnum, col)
  local _let_7_ = vim.w.parinfer_prev_cursor
  local prev_lnum = _let_7_[1]
  local prev_col = _let_7_[2]
  local request = {commentChars = vim.b.parinfer_comment_chars, cursorLine = lnum, cursorX = (col + 1), forceBalance = vim.g.parinfer_force_balance, prevCursorLine = prev_lnum, prevCursorX = (prev_col + 1)}
  log("request", request)
  return (require("parinfer"))[(vim.g.parinfer_mode .. "Mode")](text, request)
end
local function process_buffer()
  if (vim.g.parinfer_enabled and not vim.o.paste and vim.o.modifiable) then
    if (vim.b.changedtick ~= vim.b.parinfer_changedtick) then
      vim.b.parinfer_changedtick = vim.b.changedtick
      local _let_8_ = vim.api.nvim_win_get_cursor(0)
      local lnum = _let_8_[1]
      local col = _let_8_[2]
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
          local function _9_()
            return vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
          end
          vim.schedule(_9_)
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
  if not vim.b.parinfer_comment_chars then
    vim.b.parinfer_comment_chars = vim.g.parinfer_comment_chars
  end
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
