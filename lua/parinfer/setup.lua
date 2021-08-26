local function log(tag, data)
  if vim.g.parinfer_logfile then
    local f = io.open(vim.g.parinfer_logfile, "a")
    local function close_handlers_0_(ok_0_, ...)
      f:close()
      if ok_0_ then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _0_()
      return f:write(("%20s: %s"):format(tag, vim.fn.json_encode(data)))
    end
    return close_handlers_0_(xpcall(_0_, (package.loaded.fennel or debug).traceback))
  end
end
local function log_diff(from, to)
  if (vim.g.parinfer_logfile and vim.fn.has("nvim-0.6.0")) then
    local diff = vim.diff(from, to)
    local f = io.open(vim.g.parinfer_logfile, "a")
    local function close_handlers_0_(ok_0_, ...)
      f:close()
      if ok_0_ then
        return ...
      else
        return error(..., 0)
      end
    end
    local function _0_()
      return f:write(diff)
    end
    return close_handlers_0_(xpcall(_0_, (package.loaded.fennel or debug).traceback))
  end
end
local function get_cursor_position()
  local _let_0_ = vim.api.nvim_win_get_cursor(0)
  local lnum = _let_0_[1]
  local col = _let_0_[2]
  local line = vim.api.nvim_get_current_line()
  local col0 = vim.fn.strdisplaywidth(string.sub(vim.api.nvim_get_current_line(), 1, (col - 1)))
  return {lnum, col0}
end
local function set_cursor_position(lnum, col)
  local _let_0_ = vim.api.nvim_buf_get_lines(0, (lnum - 1), lnum, true)
  local line = _let_0_[1]
  local head = vim.fn.matchstr(line, (".\\+\\%<" .. (col + 2) .. "v"))
  return vim.api.nvim_win_set_cursor(0, {lnum, (#head + 1)})
end
local function enter_window()
  vim.w.parinfer_previous_cursor = get_cursor_position()
  return nil
end
local function process_buffer()
  if (vim.g.parinfer_enabled and not vim.o.paste and vim.o.modifiable) then
    if (vim.b.parinfer_last_changedtick ~= vim.b.changedtick) then
      local _let_0_ = get_cursor_position()
      local lnum = _let_0_[1]
      local col = _let_0_[2]
      local _let_1_ = vim.w.parinfer_previous_cursor
      local prev_lnum = _let_1_[1]
      local prev_col = _let_1_[2]
      local orig_lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
      local text = table.concat(orig_lines, "\n")
      local request = {commentChar = vim.b.parinfer_comment_char, cursorLine = lnum, cursorX = col, forceBalance = vim.g.parinfer_force_balance, guileBlockComments = vim.b.parinfer_guile_block_comments, janetLongStrings = vim.b.parinfer_janet_long_strings, lispBlockComments = vim.b.parinfer_lisp_block_comments, lispVlineSymbols = vim.b.parinfer_lisp_vline_symbols, prevCursorLine = prev_lnum, prevCursorX = prev_col, prevText = vim.b.parinfer_previous_text, schemeSexpComments = vim.b.parinfer_scheme_sexp_comments, stringDelimiters = vim.b.parinfer_string_delimiters}
      local response = (require("parinfer"))[(vim.g.parinfer_mode .. "Mode")](text, request)
      if response.success then
        if (response.text ~= text) then
          log("change-request", request)
          log("change-response", response)
          log_diff(text, response.text)
          local lines = vim.split(response.text, "\n")
          vim.api.nvim_command("undojoin")
          vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
        end
        set_cursor_position(response.cursorLine, response.cursorX)
        vim.b.parinfer_previous_text = response.text
      else
        log("error-response", response)
        vim.g.parinfer_last_error = response.error
        vim.b.parinfer_previous_text = text
      end
      vim.b.parinfer_last_changedtick = vim.b.changedtick
    end
    vim.w.parinfer_previous_cursor = get_cursor_position()
    return nil
  end
end
local function enter_buffer()
  enter_window()
  if not vim.b.parinfer_last_changedtick then
    vim.b.parinfer_last_changedtick = -10
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local text = table.concat(lines, "\n")
    vim.b.parinfer_previous_text = text
  end
  local orig_mode = vim.g.parinfer_mode
  vim.g.parinfer_mode = "paren"
  process_buffer()
  vim.g.parinfer_mode = orig_mode
  return nil
end
parinfer = {enter_buffer = enter_buffer, enter_window = enter_window, process_buffer = process_buffer}
return nil
