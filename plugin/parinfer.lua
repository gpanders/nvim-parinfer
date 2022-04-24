if vim.g.loaded_parinfer then
    return
end
vim.g.loaded_parinfer = true

local defaults = {
    mode = "smart",
    enabled = true,
    force_balance = false,
    comment_chars = {";"},
    filetypes = {
        "clojure",
        "scheme",
        "lisp",
        "racket",
        "hy",
        "fennel",
        "janet",
        "carp",
        "wast",
        "yuck",
    },
}

for k, v in pairs(defaults) do
    if not vim.g["parinfer_" .. k] then
        vim.g["parinfer_" .. k] = v
    end
end

local function set_enabled(bang, enable)
    if bang then
        vim.g.parinfer_enabled = enable
        vim.api.nvim_echo(
            {{string.format("Parinfer %s globally", enable and "enabled" or "disabled")}},
            false,
            {}
        )
    else
        vim.b.parinfer_enabled = enable
        vim.api.nvim_echo(
            {{string.format("Parinfer %s in the current buffer", enable and "enabled" or "disabled")}},
            false,
            {}
        )
    end
end

vim.api.nvim_create_user_command("ParinferOn", function(args)
    set_enabled(args.bang, true)
end, { bang = true, desc = "Enable parinfer" })

vim.api.nvim_create_user_command("ParinferOff", function(args)
    set_enabled(args.bang, false)
end, { bang = true, desc = "Disable parinfer" })

vim.api.nvim_create_user_command("ParinferToggle", function(args)
    if args.bang then
        set_enabled(true, not vim.g.parinfer_enabled)
    else
        set_enabled(false, not vim.b.parinfer_enabled)
    end
end, { bang = true, desc = "Toggle parinfer" })

vim.api.nvim_create_user_command("ParinferLog", function(args)
    local logfile = args.args
    if logfile then
        vim.g.parinfer_logfile = logfile
        vim.api.nvim_echo(
            {{string.format("Logging parinfer output to %s", logfile)}},
            false,
            {}
        )
    else
        vim.g.parinfer_logfile = nil
        vim.api.nvim_echo(
            {{"Disabled parinfer logging"}},
            false,
            {}
        )
    end
end, { nargs = "?", desc = "Log parinfer output to a file" })

vim.api.nvim_set_keymap("i", "<Plug>(parinfer-tab)", "", {
    noremap = true,
    callback = function()
        return require("parinfer.setup").tab(true)
    end,
    desc = "Move forward to the next tab stop",
})

vim.api.nvim_set_keymap("i", "<Plug>(parinfer-backtab)", "", {
    noremap = true,
    callback = function()
        return require("parinfer.setup").tab(false)
    end,
    desc = "Move backward to the previous tab stop",
})

vim.api.nvim_create_augroup("parinfer", {clear = true})
vim.api.nvim_create_autocmd("FileType", {
    group = "parinfer",
    pattern = "janet",
    callback = function(args)
        vim.b[args.buf].parinfer_comment_chars = {"#"}
    end,
})
vim.api.nvim_create_autocmd("FileType", {
    group = "parinfer",
    pattern = "*",
    callback = function(args)
        if vim.o.previewwindow or vim.bo[args.buf].buftype == "prompt" then
            return
        end

        local ft = vim.bo[args.buf].filetype
        local found = false
        for _, v in ipairs(vim.g.parinfer_filetypes) do
            if v == ft then
                found = true
                break
            end
        end

        if not found then
            return
        end

        local parinfer = require("parinfer.setup")

        parinfer.enter_buffer()

        vim.api.nvim_buf_create_user_command(args.buf, "ParinferStats", parinfer.stats, {
            desc = "Display parinfer runtime statistics",
        })

        vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI", "TextChangedP"}, {
            buffer = args.buf,
            callback = function(a) parinfer.text_changed(a.buf) end,
        })

        vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
            buffer = args.buf,
            callback = function(a) parinfer.cursor_moved(a.buf) end,
        })

        if vim.F.if_nil(vim.b.parinfer_no_maps, vim.g.parinfer_no_maps) ~= true then
            if vim.fn.mapcheck("<Tab>", "i") == "" then
                vim.api.nvim_buf_set_keymap(args.buf, "i", "<Tab>", "<Plug>(parinfer-tab)", {})
            end

            if vim.fn.mapcheck("<S-Tab>", "i") == "" then
                vim.api.nvim_buf_set_keymap(args.buf, "i", "<S-Tab>", "<Plug>(parinfer-backtab)", {})
            end
        end

    end,
})
