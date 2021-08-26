-- parinfer.lua - a Parinfer implementation in Lua
-- v0.1.0
-- https://github.com/oakmac/parinfer-lua
--
-- More information about Parinfer can be found here:
-- http://shaunlebron.github.io/parinfer/
--
-- Copyright (c) 2021, Chris Oakman
-- Released under the ISC license
-- https://github.com/oakmac/parinfer-lua/blob/master/LICENSE.md

local M = {}

-- forward declarations
local resetParenTrail, rememberParenTrail, updateRememberedParenTrail

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Constants

local UINT_NULL = -999

local INDENT_MODE = "INDENT_MODE"
local PAREN_MODE = "PAREN_MODE"

local BACKSLASH = "\\"
local BLANK_SPACE = " "
local DOUBLE_SPACE = "  "
local DOUBLE_QUOTE = '"'
local NEWLINE = "\n"
local TAB = "\t"

-- local LINE_ENDING_REGEX = /\r?\n/

local MATCH_PAREN = {}
MATCH_PAREN["{"] = "}"
MATCH_PAREN["}"] = "{"
MATCH_PAREN["["] = "]"
MATCH_PAREN["]"] = "["
MATCH_PAREN["("] = ")"
MATCH_PAREN[")"] = "("

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Development Helpers

-- NOTE: this is useful for development and debugging purposes
-- not required for the core library
-- local inspect = require("libs/inspect")

-- toggle this to check the asserts during development
local RUN_ASSERTS = false

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Type Predicates

local function isBoolean(x)
    return x == true or x == false
end

local function isTable(t)
    return type(t) == "table"
end

local function isInteger(i)
    return type(i) == "number" and i == math.floor(i)
end

if RUN_ASSERTS then
    assert(isInteger(1))
    assert(isInteger(-97))
    assert(not isInteger(3.14))
    assert(not isInteger())
    assert(not isInteger({}))
    assert(not isInteger("6"))
end

local function isPositiveInt(i)
    return isInteger(i) and i >= 0
end

local function isString(s)
    return type(s) == "string"
end

if RUN_ASSERTS then
    assert(isString("s"))
    assert(not isString(true))
end

local function isChar(c)
    return isString(c) and string.len(c) == 1
end

if RUN_ASSERTS then
    assert(isChar("s"))
    assert(not isChar("xx"))
    assert(not isChar(true))
end

local function isTableOfChars(t)
    if not isTable(t) then
        return false
    end

    for _key, ch in pairs(t) do
        if not isChar(ch) then
            return false
        end
    end

    return true
end

if RUN_ASSERTS then
    assert(isTableOfChars({}))
    assert(isTableOfChars({"a", "b", "c"}))
    assert(not isTableOfChars({"a", "b", "ccc"}))
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Language Helpers

local function isTableEmpty(t)
    for _key, _val in pairs(t) do
        return false
    end
    return true
end

if RUN_ASSERTS then
    assert(isTableEmpty({}))
    assert(not isTableEmpty({"a", "b"}))
end

local function tableSize(t)
    if RUN_ASSERTS then
        assert(isTable(t), "used tableSize with not an Table")
    end

    local count = 0
    for _key, _val in pairs(t) do
        count = count + 1
    end
    return count
end

if RUN_ASSERTS then
    assert(tableSize({}) == 0)
    assert(tableSize({"a", "b"}) == 2)
    assert(tableSize({"a", "b", "c", "d", "e"}) == 5)
    assert(tableSize({a = "a", b = "b"}) == 2)
end

local function strLen(s)
    if RUN_ASSERTS then
        assert(isString(s), "used strLen with not a String")
    end
    return string.len(s)
end

local function strConcat(s1, s2)
    if RUN_ASSERTS then
        assert(isString(s1), "strConcat argument s1 is not a String")
        assert(isString(s2), "strConcat argument s2 is not a String")
    end
    return s1 .. s2
end

local function getCharFromString(s, idx)
    if RUN_ASSERTS then
        assert(isString(s), "getCharFromString argument s is not a String")
        assert(isInteger(idx), "getCharFromString argument idx is not an Integer")
    end
    return string.sub(s, idx, idx)
end

if RUN_ASSERTS then
    assert(getCharFromString("abc", 1) == "a")
    assert(getCharFromString("abc", 2) == "b")
end

local function strJoin(tbl, delimiter)
    if RUN_ASSERTS then
        assert(isTable(tbl), "strJoin argument tbl is not a Table")
        assert(isString(delimiter), "strJoin argument delimiter is not a String")
    end

    return table.concat(tbl, delimiter)
end

if RUN_ASSERTS then
    assert(strJoin({"a", "b", "c"}, "") == "abc")
    assert(strJoin({"a", "b", "c"}, "x") == "axbxc")
    assert(strJoin({"a", "b", "c"}, "\n") == "a\nb\nc")
    assert(strJoin({"a", "b", "c", "dd"}, "zz") == "azzbzzczzdd")
    assert(strJoin({}, "z") == "")
    assert(strJoin({}, "") == "")
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- String Operations

local function replaceWithinString(orig, startIdx, endIdx, replace)
    local head = string.sub(orig, 1, startIdx - 1)
    local tail = string.sub(orig, endIdx, -1)
    return head .. replace .. tail
end

if RUN_ASSERTS then
    assert(replaceWithinString("abc", 1, 3, "") == "c")
    assert(replaceWithinString("abc", 1, 2, "x") == "xbc")
    assert(replaceWithinString("abc", 1, 3, "x") == "xc")
    assert(replaceWithinString("abcdef", 4, 26, "") == "abc")
end

local function repeatString(text, n)
    return string.rep(text, n)
end

if RUN_ASSERTS then
    assert(repeatString("a", 2) == "aa")
    assert(repeatString("aa", 3) == "aaaaaa")
    assert(repeatString("aa", 0) == "")
    assert(repeatString("", 0) == "")
    assert(repeatString("", 5) == "")
end

local function getLineEnding(text)
    -- TODO: allow for "\r\n" as well as "\n" here
    return "\n"
end

-- modified from penlight: https://tinyurl.com/37fqwxy8
local function splitLines(s)
    if s == "" then
        return {""}
    end

    local res = {}
    local pos = 1
    while true do
        local line_end_pos = string.find(s, "[\r\n]", pos)
        if not line_end_pos then
            break
        end

        local line_end = string.sub(s, line_end_pos, line_end_pos)
        if line_end == "\r" and string.sub(s, line_end_pos + 1, line_end_pos + 1) == "\n" then
            line_end = "\r\n"
        end

        local line = string.sub(s, pos, line_end_pos - 1)
        table.insert(res, line)

        pos = line_end_pos + #line_end
    end

    if pos <= #s then
        table.insert(res, string.sub(s, pos))
    end

    local len = strLen(s)
    local lastCh = getCharFromString(s, len)
    if lastCh == "\n" then
        table.insert(res, "")
    end

    return res
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Stack Operations

local function isStackEmpty(t)
    if RUN_ASSERTS then
        assert(isTable(t), "used isStackEmpty with not a Table")
    end

    for _key, _val in pairs(t) do
        return false
    end
    return true
end

if RUN_ASSERTS then
    assert(isStackEmpty({}))
    assert(not isStackEmpty({"a"}))
    assert(not isStackEmpty({"a", "b"}))
end

local function peek(arr, idxFromBack)
    idxFromBack = idxFromBack + 1
    local maxIdx = tableSize(arr)
    if (idxFromBack > maxIdx) then
        return nil
    end
    return arr[maxIdx - idxFromBack + 1]
end

if RUN_ASSERTS then
    assert(peek({"a"}, 0) == "a")
    assert(peek({"a"}, 1) == nil)
    assert(peek({"a", "b", "c"}, 0) == "c")
    assert(peek({"a", "b", "c"}, 1) == "b")
    assert(peek({"a", "b", "c"}, 5) == nil)
    assert(peek({}, 0) == nil)
    assert(peek({}, 1) == nil)
end

local function stackPop(s)
    if RUN_ASSERTS then
        assert(isTable(s), "used stackPop with not an Table")
    end

    return table.remove(s)
end

if RUN_ASSERTS then
    assert(stackPop({"a"}) == "a")
    assert(stackPop({"a", "b", "c"}) == "c")
    local testTable1 = {"a", "b"}
    assert(stackPop(testTable1) == "b")
    assert(tableSize(testTable1) == 1)
    assert(stackPop(testTable1) == "a")
    assert(tableSize(testTable1) == 0)
    stackPop(testTable1)
    assert(tableSize(testTable1) == 0)
end

local function stackPush(s, itm)
    if RUN_ASSERTS then
        assert(isTable(s), "used stackPush with not an Table")
        assert(isString(itm) or itm, "used stackPush without a second itm")
    end

    table.insert(s, itm)
    return nil
end

if RUN_ASSERTS then
    local testTable2 = {"a", "b"}
    stackPush(testTable2, "c")
    assert(tableSize(testTable2) == 3)
    assert(peek(testTable2, 0) == "c")
    assert(peek(testTable2, 1) == "b")
end

-- returns a new table with elements of tbl
-- startIdx and endIdx are both inclusive
local function sliceTable(tbl, startIdx, endIdx)
    local newTable = {}

    for idx, v in pairs(tbl) do
        if idx >= startIdx and idx <= endIdx then
            table.insert(newTable, v)
        end
    end

    return newTable
end

if RUN_ASSERTS then
    assert(strJoin(sliceTable({"a", "b", "c"}, 1, 1), "") == strJoin({"a"}, ""))
    assert(strJoin(sliceTable({"a", "b", "c"}, 2, 2), "") == strJoin({"b"}, ""))
    assert(strJoin(sliceTable({"a", "b", "c", "d", "e"}, 2, 3), "") == strJoin({"b", "c"}, ""))
    assert(strJoin(sliceTable({"a", "b", "c", "d", "e"}, 3, 25), "") == strJoin({"c", "d", "e"}, ""))
    assert(strJoin(sliceTable({}, 2, 3), "") == strJoin({}, ""))
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Options Structure

local function transformChange(change)
    if not change then
        return nil
    end

    local newLines = splitLines(change.newText)
    local oldLines = splitLines(change.oldText)

    -- single line case:
    --     (defn foo| [])
    --              ^ newEndX, newEndLineNo
    --           +++

    -- multi line case:
    --     (defn foo
    --           ++++
    --        "docstring."
    --     ++++++++++++++++
    --       |[])
    --     ++^ newEndX, newEndLineNo

    local prevOldLine = peek(oldLines, 0)
    local lastOldLineLen = strLen(prevOldLine)

    local prevNewLine = peek(newLines, 0)
    local lastNewLineLen = strLen(prevNewLine)

    local carryOverOldX = 1 -- Lua ONE INDEX
    if tableSize(oldLines) == 1 then
        carryOverOldX = change.x
    end
    local oldEndX = carryOverOldX + lastOldLineLen

    local carryOverNewX = 1 -- Lua ONE INDEX
    if tableSize(newLines) == 1 then
        carryOverNewX = change.x
    end
    local newEndX = carryOverNewX + lastNewLineLen

    local newEndLineNo = change.lineNo + tableSize(newLines) - 1

    return {
        x = change.x,
        lineNo = change.lineNo,
        oldText = change.oldText,
        newText = change.newText,
        oldEndX = oldEndX,
        newEndX = newEndX,
        newEndLineNo = newEndLineNo,
        lookupLineNo = newEndLineNo,
        lookupX = newEndX
    }
end

local function transformChanges(changes)
    if tableSize(changes) == 0 then
        return nil
    else
        local lines = {}
        local changesLen = tableSize(changes)
        local i = 1 -- Lua ONE INDEX
        while i <= changesLen do
            local change = transformChange(changes[i])
            local line = lines[change.lookupLineNo]
            if not line then
                line = {}
                lines[change.lookupLineNo] = line
            end
            line[change.lookupX] = change

            i = i + 1
        end
        return lines
    end
end

local function parseOptions(options)
    if (not isTable(options)) then
        options = {}
    end

    return {
        changes = options.changes,
        commentChars = options.commentChars,
        cursorLine = options.cursorLine,
        cursorX = options.cursorX,
        forceBalance = options.forceBalance,
        partialResult = options.partialResult,
        prevCursorLine = options.prevCursorLine,
        prevCursorX = options.prevCursorX,
        returnParens = options.returnParens,
        selectionStartLine = options.selectionStartLine
    }
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Result Structure

local function initialParenTrail()
    return {
        lineNo = UINT_NULL,
        startX = UINT_NULL,
        endX = UINT_NULL,
        openers = {},
        clamped = {
            startX = UINT_NULL,
            endX = UINT_NULL,
            openers = {}
        }
    }
end

local function getInitialResult(text, options, mode, smart)
    local result = {
        mode = mode,
        smart = smart,
        origText = text,
        origCursorX = UINT_NULL,
        origCursorLine = UINT_NULL,
        inputLines = splitLines(text),
        inputLineNo = 0, -- Lua ONE INDEX
        inputX = 0, -- Lua ONE INDEX
        lines = {},
        lineNo = 0, -- Lua ONE INDEX
        ch = "",
        x = 0, -- Lua ONE INDEX
        indentX = UINT_NULL,
        parenStack = {},
        tabStops = {},
        parenTrail = initialParenTrail(),
        parenTrails = {},
        returnParens = false,
        parens = {},
        cursorX = UINT_NULL,
        cursorLine = UINT_NULL,
        prevCursorX = UINT_NULL,
        prevCursorLine = UINT_NULL,
        commentChars = {";"},
        selectionStartLine = UINT_NULL,
        changes = nil,
        isInCode = true,
        isEscaping = false,
        isEscaped = false,
        isInStr = false,
        isInComment = false,
        commentX = UINT_NULL,
        quoteDanger = false,
        trackingIndent = false,
        skipChar = false,
        success = false,
        partialResult = false,
        forceBalance = false,
        maxIndent = UINT_NULL,
        indentDelta = 0,
        trackingArgTabStop = nil,
        ["error"] = {
            name = nil,
            message = nil,
            lineNo = nil,
            x = nil,
            extra = {
                name = nil,
                lineNo = nil,
                x = nil
            }
        },
        errorPosCache = {}
    }

    -- merge user options if they are valid
    if (options) then
        if isInteger(options.cursorX) then
            result.cursorX = options.cursorX
            result.origCursorX = options.cursorX
        end

        if isInteger(options.cursorLine) then
            result.cursorLine = options.cursorLine
            result.origCursorLine = options.cursorLine
        end

        if isInteger(options.prevCursorX) then
            result.prevCursorX = options.prevCursorX
        end
        if isInteger(options.prevCursorLine) then
            result.prevCursorLine = options.prevCursorLine
        end
        if isInteger(options.selectionStartLine) then
            result.selectionStartLine = options.selectionStartLine
        end
        if isTable(options.changes) then
            result.changes = transformChanges(options.changes)
        end
        if isBoolean(options.partialResult) then
            result.partialResult = options.partialResult
        end
        if isBoolean(options.forceBalance) then
            result.forceBalance = options.forceBalance
        end
        if isBoolean(options.returnParens) then
            result.returnParens = options.returnParens
        end
        if isChar(options.commentChars) then
            result.commentChars = {options.commentChars}
        end
        if isTableOfChars(options.commentChars) then
            result.commentChars = options.commentChars
        end
    end

    return result
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Possible Errors

-- `result.error.name` is set to any of these
local ERROR_QUOTE_DANGER = "quote-danger"
local ERROR_EOL_BACKSLASH = "eol-backslash"
local ERROR_UNCLOSED_QUOTE = "unclosed-quote"
local ERROR_UNCLOSED_PAREN = "unclosed-paren"
local ERROR_UNMATCHED_CLOSE_PAREN = "unmatched-close-paren"
local ERROR_UNMATCHED_OPEN_PAREN = "unmatched-open-paren"
local ERROR_LEADING_CLOSE_PAREN = "leading-close-paren"
local ERROR_UNHANDLED = "unhandled"

local errorMessages = {}
errorMessages[ERROR_QUOTE_DANGER] = "Quotes must balanced inside comment blocks."
errorMessages[ERROR_EOL_BACKSLASH] = "Line cannot end in a hanging backslash."
errorMessages[ERROR_UNCLOSED_QUOTE] = "String is missing a closing quote."
errorMessages[ERROR_UNCLOSED_PAREN] = "Unclosed open-paren."
errorMessages[ERROR_UNMATCHED_CLOSE_PAREN] = "Unmatched close-paren."
errorMessages[ERROR_UNMATCHED_OPEN_PAREN] = "Unmatched open-paren."
errorMessages[ERROR_LEADING_CLOSE_PAREN] = "Line cannot lead with a close-paren."
errorMessages[ERROR_UNHANDLED] = "Unhandled error."

local function cacheErrorPos(result, errorName)
    local e = {
        lineNo = result.lineNo,
        x = result.x,
        inputLineNo = result.inputLineNo,
        inputX = result.inputX
    }
    result.errorPosCache[errorName] = e
    return e
end

local function createError(result, name)
    local cache = result.errorPosCache[name]

    local keyLineNo = "inputLineNo"
    local keyX = "inputX"
    if result.partialResult then
        keyLineNo = "lineNo"
        keyX = "x"
    end

    local lineNo = 0
    local x = 0
    if cache then
        lineNo = cache[keyLineNo]
        x = cache[keyX]
    else
        lineNo = result[keyLineNo]
        x = result[keyX]
    end

    local err = {
        parinferError = true,
        name = name,
        message = errorMessages[name],
        lineNo = lineNo,
        x = x
    }
    local opener = peek(result.parenStack, 0)

    if name == ERROR_UNMATCHED_CLOSE_PAREN then
        -- extra error info for locating the open-paren that it should've matched
        local cache2 = result.errorPosCache[ERROR_UNMATCHED_OPEN_PAREN]
        if cache2 or opener then
            local lineNo2 = 0
            local x2 = 0
            if cache2 then
                lineNo2 = cache2[keyLineNo]
                x2 = cache2[keyX]
            else
                lineNo2 = opener[keyLineNo]
                x2 = opener[keyX]
            end

            err.extra = {
                name = ERROR_UNMATCHED_OPEN_PAREN,
                lineNo = lineNo2,
                x = x2
            }
        end
    elseif name == ERROR_UNCLOSED_PAREN then
        err.lineNo = opener[keyLineNo]
        err.x = opener[keyX]
    end

    return err
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Line Operations

local function isCursorAffected(result, startIdx, endIdx)
    if (result.cursorX == startIdx and result.cursorX == endIdx) then
        return result.cursorX == 1 -- Lua ONE INDEX
    end
    return result.cursorX >= endIdx
end

local function shiftCursorOnEdit(result, lineNo, startIdx, endIdx, replaceTxt)
    local oldLength = endIdx - startIdx
    local newLength = strLen(replaceTxt)
    local dx = newLength - oldLength

    if
        (dx ~= 0 and result.cursorLine == lineNo and result.cursorX ~= UINT_NULL and
            isCursorAffected(result, startIdx, endIdx))
     then
        result.cursorX = result.cursorX + dx
    end
end

local function replaceWithinLine(result, lineNo, startIdx, endIdx, replaceTxt)
    local line = result.lines[lineNo]

    local newLine = replaceWithinString(line, startIdx, endIdx, replaceTxt)
    result.lines[lineNo] = newLine

    shiftCursorOnEdit(result, lineNo, startIdx, endIdx, replaceTxt)
end

local function insertWithinLine(result, lineNo, idx, insert)
    replaceWithinLine(result, lineNo, idx, idx, insert)
end

local function initLine(result)
    result.x = 1 -- Lua ONE INDEX
    result.lineNo = result.lineNo + 1

    -- reset line-specific state
    result.indentX = UINT_NULL
    result.commentX = UINT_NULL
    result.indentDelta = 0
    result.errorPosCache[ERROR_UNMATCHED_CLOSE_PAREN] = nil
    result.errorPosCache[ERROR_UNMATCHED_OPEN_PAREN] = nil
    result.errorPosCache[ERROR_LEADING_CLOSE_PAREN] = nil

    result.trackingArgTabStop = nil
    result.trackingIndent = not result.isInStr
end

-- if the current character has changed, commit its change to the current line.
local function commitChar(result, origCh)
    local ch = result.ch
    local origChLength = strLen(origCh)
    local chLength = strLen(ch)

    if origCh ~= ch then
        replaceWithinLine(result, result.lineNo, result.x, result.x + origChLength, ch)
        result.indentDelta = result.indentDelta - origChLength - chLength
    end

    result.x = result.x + chLength
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Misc Util

local function clamp(val, minN, maxN)
    if (minN ~= UINT_NULL) then
        val = math.max(minN, val)
    end
    if (maxN ~= UINT_NULL) then
        val = math.min(maxN, val)
    end
    return val
end

if RUN_ASSERTS then
    assert(clamp(1, 3, 5) == 3)
    assert(clamp(9, 3, 5) == 5)
    assert(clamp(1, 3, UINT_NULL) == 3)
    assert(clamp(5, 3, UINT_NULL) == 5)
    assert(clamp(1, UINT_NULL, 5) == 1)
    assert(clamp(9, UINT_NULL, 5) == 5)
    assert(clamp(1, UINT_NULL, UINT_NULL) == 1)
end

-- concat the elements in t2 onto t1
-- returns a new table
local function concatTables(t1, t2)
    local newTable = {}

    for k, v in pairs(t1) do
        table.insert(newTable, v)
    end

    for k, v in pairs(t2) do
        table.insert(newTable, v)
    end

    return newTable
end

if RUN_ASSERTS then
    assert(strJoin(concatTables({}, {}), "") == strJoin({}, ""))
    assert(strJoin(concatTables({"a"}, {}), "") == strJoin({"a"}, ""))
    assert(strJoin(concatTables({}, {"a"}), "") == strJoin({"a"}, ""))
    assert(strJoin(concatTables({"a", "b", "c"}, {"d", "e"}), "") == strJoin({"a", "b", "c", "d", "e"}, ""))
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Character Predicates

local function isOpenParen(ch)
    return ch == "{" or ch == "(" or ch == "["
end

local function isCloseParen(ch)
    return ch == "}" or ch == ")" or ch == "]"
end

if RUN_ASSERTS then
    assert(isOpenParen("(") == true)
    assert(isOpenParen("]") == false)
    assert(isCloseParen("}") == true)
    assert(isCloseParen("a") == false)
end

local function isValidCloseParen(parenStack, ch)
    if isStackEmpty(parenStack) then
        return false
    end

    local lastOnStack = peek(parenStack, 0)
    return lastOnStack.ch == MATCH_PAREN[ch]
end

local function isWhitespace(result)
    local ch = result.ch
    return (not result.isEscaped) and (ch == BLANK_SPACE or ch == DOUBLE_SPACE)
end

-- can this be the last code character of a list?
local function isClosable(result)
    local ch = result.ch
    local isCloser = isCloseParen(ch) and not result.isEscaped
    return result.isInCode and not isWhitespace(result) and ch ~= "" and not isCloser
end

local function isCommentChar(ch, commentChars)
    for _key, commentCh in pairs(commentChars) do
        if ch == commentCh then
            return true
        end
    end
    return false
end

if RUN_ASSERTS then
    assert(isCommentChar(";", {";"}))
    assert(isCommentChar(";", {";", "#"}))
    assert(isCommentChar("#", {";", "#"}))
    assert(not isCommentChar("x", {";"}))
    assert(not isCommentChar("", {";"}))
    assert(not isCommentChar("#", {";", "a"}))
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Advanced Character Operations

local function checkCursorHolding(result)
    local opener = peek(result.parenStack, 0)
    local parent = peek(result.parenStack, 1)
    local holdMinX = 1 -- Lua ONE INDEX
    if parent then
        holdMinX = parent.x + 1
    end
    local holdMaxX = opener.x

    local holding = result.cursorLine == opener.lineNo and holdMinX <= result.cursorX and result.cursorX <= holdMaxX
    local shouldCheckPrev = not result.changes and result.prevCursorLine ~= UINT_NULL
    if shouldCheckPrev then
        local prevHolding =
            result.prevCursorLine == opener.lineNo and holdMinX <= result.prevCursorX and result.prevCursorX <= holdMaxX
        if prevHolding and not holding then
            error({releaseCursorHold = true})
        end
    end

    return holding
end

local function trackArgTabStop(result, state)
    if state == "space" then
        if result.isInCode and isWhitespace(result) then
            result.trackingArgTabStop = "arg"
        end
    elseif state == "arg" then
        if not isWhitespace(result) then
            local opener = peek(result.parenStack, 0)
            opener.argX = result.x
            result.trackingArgTabStop = nil
        end
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Literal Character Events

local function onOpenParen(result)
    if result.isInCode then
        local opener = {
            inputLineNo = result.inputLineNo,
            inputX = result.inputX,
            lineNo = result.lineNo,
            x = result.x,
            ch = result.ch,
            indentDelta = result.indentDelta,
            maxChildIndent = UINT_NULL
        }

        if result.returnParens then
            opener.children = {}
            opener.closer = {
                lineNo = UINT_NULL,
                x = UINT_NULL,
                ch = ""
            }

            local parent1 = peek(result.parenStack, 0)
            local parent2 = result.parens
            if parent1 then
                parent2 = parent1.children
            end

            stackPush(parent2, opener)
        end

        stackPush(result.parenStack, opener)
        result.trackingArgTabStop = "space"
    end
end

local function setCloser(opener, lineNo, x, ch)
    opener.closer.lineNo = lineNo
    opener.closer.x = x
    opener.closer.ch = ch
end

local function onMatchedCloseParen(result)
    local opener = peek(result.parenStack, 0)
    if result.returnParens then
        setCloser(opener, result.lineNo, result.x, result.ch)
    end

    result.parenTrail.endX = result.x + 1
    stackPush(result.parenTrail.openers, opener)

    if (result.mode == INDENT_MODE and result.smart and checkCursorHolding(result)) then
        local origStartX = result.parenTrail.startX
        local origEndX = result.parenTrail.endX
        local origOpeners = result.parenTrail.openers
        resetParenTrail(result, result.lineNo, result.x + 1)
        result.parenTrail.clamped.startX = origStartX
        result.parenTrail.clamped.endX = origEndX
        result.parenTrail.clamped.openers = origOpeners
    end
    stackPop(result.parenStack)
    result.trackingArgTabStop = nil
end

local function onUnmatchedCloseParen(result)
    if (result.mode == PAREN_MODE) then
        local trail = result.parenTrail
        local inLeadingParenTrail = (trail.lineNo == result.lineNo) and (trail.startX == result.indentX)
        local canRemove = result.smart and inLeadingParenTrail
        if not canRemove then
            error(createError(result, ERROR_UNMATCHED_CLOSE_PAREN))
        end
    elseif (result.mode == INDENT_MODE and not result.errorPosCache[ERROR_UNMATCHED_CLOSE_PAREN]) then
        cacheErrorPos(result, ERROR_UNMATCHED_CLOSE_PAREN)
        local opener = peek(result.parenStack, 0)
        if opener then
            local e = cacheErrorPos(result, ERROR_UNMATCHED_OPEN_PAREN)
            e.inputLineNo = opener.inputLineNo
            e.inputX = opener.inputX
        end
    end
    result.ch = ""
end

local function onCloseParen(result)
    if result.isInCode then
        if isValidCloseParen(result.parenStack, result.ch) then
            onMatchedCloseParen(result)
        else
            onUnmatchedCloseParen(result)
        end
    end
end

local function onTab(result)
    if result.isInCode then
        result.ch = DOUBLE_SPACE
    end
end

local function onCommentChar(result)
    if result.isInCode then
        result.isInComment = true
        result.commentX = result.x
        result.trackingArgTabStop = nil
    end
end

local function onNewline(result)
    result.isInComment = false
    result.ch = ""
end

local function onQuote(result)
    if result.isInStr then
        result.isInStr = false
    elseif result.isInComment then
        result.quoteDanger = not result.quoteDanger
        if result.quoteDanger then
            cacheErrorPos(result, ERROR_QUOTE_DANGER)
        end
    else
        result.isInStr = true
        cacheErrorPos(result, ERROR_UNCLOSED_QUOTE)
    end
end

local function onBackslash(result)
    result.isEscaping = true
end

local function afterBackslash(result)
    result.isEscaping = false
    result.isEscaped = true

    if result.ch == NEWLINE then
        if result.isInCode then
            error(createError(result, ERROR_EOL_BACKSLASH))
        end
        onNewline(result)
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Character Dispatch

local function onChar(result)
    local ch = result.ch
    result.isEscaped = false

    if result.isEscaping then
        afterBackslash(result)
    elseif isOpenParen(ch) then
        onOpenParen(result)
    elseif isCloseParen(ch) then
        onCloseParen(result)
    elseif ch == DOUBLE_QUOTE then
        onQuote(result)
    elseif isCommentChar(ch, result.commentChars) then
        onCommentChar(result)
    elseif ch == BACKSLASH then
        onBackslash(result)
    elseif ch == TAB then
        onTab(result)
    elseif ch == NEWLINE then
        onNewline(result)
    end

    ch = result.ch

    result.isInCode = (not result.isInComment) and (not result.isInStr)

    if isClosable(result) then
        resetParenTrail(result, result.lineNo, result.x + strLen(ch))
    end

    local state = result.trackingArgTabStop
    if state then
        trackArgTabStop(result, state)
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Cursor Functions

local function isCursorLeftOf(cursorX, cursorLine, x, lineNo)
    return cursorLine == lineNo and x ~= UINT_NULL and cursorX ~= UINT_NULL and cursorX <= x
end

local function isCursorRightOf(cursorX, cursorLine, x, lineNo)
    return cursorLine == lineNo and x ~= UINT_NULL and cursorX ~= UINT_NULL and cursorX > x
end

local function isCursorInComment(result, cursorX, cursorLine)
    return isCursorRightOf(cursorX, cursorLine, result.commentX, result.lineNo)
end

local function handleChangeDelta(result)
    if (result.changes and (result.smart or result.mode == PAREN_MODE)) then
        local line = result.changes[result.inputLineNo]
        if (line) then
            local change = line[result.inputX]
            if (change) then
                result.indentDelta = result.indentDelta + change.newEndX - change.oldEndX
            end
        end
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Paren Trail Functions

resetParenTrail = function(result, lineNo, x)
    result.parenTrail.lineNo = lineNo
    result.parenTrail.startX = x
    result.parenTrail.endX = x
    result.parenTrail.openers = {}
    result.parenTrail.clamped.startX = UINT_NULL
    result.parenTrail.clamped.endX = UINT_NULL
    result.parenTrail.clamped.openers = {}
end

local function isCursorClampingParenTrail(result, cursorX, cursorLine)
    return (isCursorRightOf(cursorX, cursorLine, result.parenTrail.startX, result.lineNo) and
        not isCursorInComment(result, cursorX, cursorLine))
end

local function clampParenTrailToCursor(result)
    local startX = result.parenTrail.startX
    local endX = result.parenTrail.endX

    local clamping = isCursorClampingParenTrail(result, result.cursorX, result.cursorLine)

    if clamping then
        local newStartX = math.max(startX, result.cursorX)
        local newEndX = math.max(endX, result.cursorX)

        local line = result.lines[result.lineNo]
        local removeCount = 0

        local i = startX
        while i <= newStartX do -- Lua ONE INDEX
            local ch = getCharFromString(line, i)
            if isCloseParen(ch) then
                removeCount = removeCount + 1
            end
            i = i + 1
        end

        local openers = result.parenTrail.openers

        local openersLen = tableSize(openers)
        result.parenTrail.openers = sliceTable(openers, removeCount, openersLen)
        result.parenTrail.startX = newStartX
        result.parenTrail.endX = newEndX

        result.parenTrail.clamped.openers = sliceTable(openers, 1, removeCount) -- Lua ONE INDEX
        result.parenTrail.clamped.startX = startX
        result.parenTrail.clamped.endX = endX
    end
end

local function popParenTrail(result)
    local startX = result.parenTrail.startX
    local endX = result.parenTrail.endX

    if (startX == endX) then
        return
    else
        local openers = result.parenTrail.openers
        while not isStackEmpty(openers) do
            local itm = stackPop(openers)
            stackPush(result.parenStack, itm)
        end
    end
end

local function getParentOpenerIndex(result, indentX)
    local parenStackLength = tableSize(result.parenStack)
    local i = 0
    while i < parenStackLength do
        local opener = peek(result.parenStack, i)
        local currOutside = (opener.x < indentX)
        local prevIndentX = indentX - result.indentDelta
        local prevOutside = (opener.x - opener.indentDelta < prevIndentX)

        local isParent = false

        if (prevOutside and currOutside) then
            isParent = true
        elseif (not prevOutside and not currOutside) then
            isParent = false
        elseif (prevOutside and not currOutside) then
            -- 1. PREVENT FRAGMENTATION
            if (result.indentDelta == 0) then
                -- 2. ALLOW FRAGMENTATION
                isParent = true
            elseif (opener.indentDelta == 0) then
                isParent = false
            else
                isParent = false
            end
        elseif (not prevOutside and currOutside) then
            local nextOpener = peek(result.parenStack, i + 1)

            -- 1. DISALLOW ADOPTION
            if (nextOpener and nextOpener.indentDelta <= opener.indentDelta) then
                -- 2. ALLOW ADOPTION
                if (indentX + nextOpener.indentDelta > opener.x) then
                    isParent = true
                else
                    isParent = false
                end
            elseif (nextOpener and nextOpener.indentDelta > opener.indentDelta) then
                -- 3. ALLOW ADOPTION
                isParent = true
            elseif (result.indentDelta > opener.indentDelta) then
                isParent = true
            end

            -- if new parent
            if isParent then
                opener.indentDelta = 0
            end
        end

        if isParent then
            break
        end

        i = i + 1
    end

    return i
end

local function correctParenTrail(result, indentX)
    local openerIdx = getParentOpenerIndex(result, indentX)
    local parens = ""
    local i = 0
    while i < openerIdx do
        local opener = stackPop(result.parenStack)
        stackPush(result.parenTrail.openers, opener)
        local closeCh = MATCH_PAREN[opener.ch]
        parens = strConcat(parens, closeCh)

        if result.returnParens then
            setCloser(opener, result.parenTrail.lineNo, result.parenTrail.startX + i, closeCh)
        end

        i = i + 1
    end

    if result.parenTrail.lineNo ~= UINT_NULL then
        replaceWithinLine(result, result.parenTrail.lineNo, result.parenTrail.startX, result.parenTrail.endX, parens)
        result.parenTrail.endX = result.parenTrail.startX + strLen(parens)
        rememberParenTrail(result)
    end
end

-- PAREN MODE: remove spaces from the paren trail
local function cleanParenTrail(result)
    local startX = result.parenTrail.startX
    local endX = result.parenTrail.endX

    if (startX == endX or result.lineNo ~= result.parenTrail.lineNo) then
        return
    end

    local line = result.lines[result.lineNo]
    local newTrail = ""
    local spaceCount = 0
    local i = startX
    while i < endX do
        local lineCh = getCharFromString(line, i)
        if (isCloseParen(lineCh)) then
            newTrail = strConcat(newTrail, lineCh)
        else
            spaceCount = spaceCount + 1
        end

        i = i + 1
    end

    if spaceCount > 0 then
        replaceWithinLine(result, result.lineNo, startX, endX, newTrail)
        result.parenTrail.endX = result.parenTrail.endX - spaceCount
    end
end

local function setMaxIndent(result, opener)
    if opener then
        local parent = peek(result.parenStack, 0)
        if parent then
            parent.maxChildIndent = opener.x
        else
            result.maxIndent = opener.x
        end
    end
end

local function appendParenTrail(result)
    local opener = stackPop(result.parenStack)
    local closeCh = MATCH_PAREN[opener.ch]
    if (result.returnParens) then
        setCloser(opener, result.parenTrail.lineNo, result.parenTrail.endX, closeCh)
    end

    setMaxIndent(result, opener)
    insertWithinLine(result, result.parenTrail.lineNo, result.parenTrail.endX, closeCh)

    result.parenTrail.endX = result.parenTrail.endX + 1
    stackPush(result.parenTrail.openers, opener)
    updateRememberedParenTrail(result)
end

local function invalidateParenTrail(result)
    result.parenTrail = initialParenTrail()
end

local function checkUnmatchedOutsideParenTrail(result)
    local cache = result.errorPosCache[ERROR_UNMATCHED_CLOSE_PAREN]
    if (cache and cache.x < result.parenTrail.startX) then
        error(createError(result, ERROR_UNMATCHED_CLOSE_PAREN))
    end
end

rememberParenTrail = function(result)
    local trail = result.parenTrail
    local openers = concatTables(trail.clamped.openers, trail.openers)
    if not isTableEmpty(openers) then
        local isClamped = trail.clamped.startX ~= UINT_NULL
        local allClamped = isTableEmpty(trail.openers)

        local startX = trail.startX
        if isClamped then
            startX = trail.clamped.startX
        end

        local endX = trail.endX
        if allClamped then
            endX = trail.clamped.endX
        end

        local shortTrail = {
            lineNo = trail.lineNo,
            startX = startX,
            endX = endX
        }
        stackPush(result.parenTrails, shortTrail)

    -- TODO: this almost certainly is not working due to openers
    -- being a deep copy here and then not being returned anywhere
    -- possibly a bug in parinfer.js as well
    --if result.returnParens then
    --  local i
    --  for (i = 0; i < openers.length; i++) {
    --    openers[i].closer.trail = shortTrail
    --  }
    --end
    end
end

updateRememberedParenTrail = function(result)
    local trail = peek(result.parenTrails, 0)
    if not trail or trail.lineNo ~= result.parenTrail.lineNo then
        rememberParenTrail(result)
    else
        trail.endX = result.parenTrail.endX
        if result.returnParens then
            -- this is almost certainly buggy
            -- commenting this out has no effect on the test suite
            -- -- C. Oakman, 19 Feb 2021
            local opener = peek(result.parenTrail.openers, 0)
            opener.closer.trail = trail
        end
    end
end

local function finishNewParenTrail(result)
    if (result.isInStr) then
        invalidateParenTrail(result)
    elseif (result.mode == INDENT_MODE) then
        clampParenTrailToCursor(result)
        popParenTrail(result)
    elseif (result.mode == PAREN_MODE) then
        setMaxIndent(result, peek(result.parenTrail.openers, 0))
        if (result.lineNo ~= result.cursorLine) then
            cleanParenTrail(result)
        end
        rememberParenTrail(result)
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Indentation Functions

local function addIndent(result, delta)
    local origIndent = result.x
    local newIndent = origIndent + delta
    local indentStr = repeatString(BLANK_SPACE, newIndent - 1) -- Lua ONE INDEX
    replaceWithinLine(result, result.lineNo, 1, origIndent, indentStr) -- Lua ONE INDEX
    result.x = newIndent
    result.indentX = newIndent
    result.indentDelta = result.indentDelta + delta
end

local function shouldAddOpenerIndent(result, opener)
    -- Don't add opener.indentDelta if the user already added it.
    -- (happens when multiple lines are indented together)
    return opener.indentDelta ~= result.indentDelta
end

local function correctIndent(result)
    local origIndent = result.x
    local newIndent = origIndent
    local minIndent = 0
    local maxIndent = result.maxIndent

    local opener = peek(result.parenStack, 0)
    if opener then
        minIndent = opener.x + 1
        maxIndent = opener.maxChildIndent
        if shouldAddOpenerIndent(result, opener) then
            newIndent = newIndent + opener.indentDelta
        end
    end

    newIndent = clamp(newIndent, minIndent, maxIndent)

    if newIndent ~= origIndent then
        addIndent(result, newIndent - origIndent)
    end
end

local function onIndent(result)
    result.indentX = result.x
    result.trackingIndent = false

    if (result.quoteDanger) then
        error(createError(result, ERROR_QUOTE_DANGER))
    end

    if result.mode == INDENT_MODE then
        correctParenTrail(result, result.x)

        local opener = peek(result.parenStack, 0)
        if opener and shouldAddOpenerIndent(result, opener) then
            addIndent(result, opener.indentDelta)
        end
    elseif result.mode == PAREN_MODE then
        correctIndent(result)
    end
end

local function checkLeadingCloseParen(result)
    if result.errorPosCache[ERROR_LEADING_CLOSE_PAREN] and result.parenTrail.lineNo == result.lineNo then
        error(createError(result, ERROR_LEADING_CLOSE_PAREN))
    end
end

local function onLeadingCloseParen(result)
    if result.mode == INDENT_MODE then
        if not result.forceBalance then
            if result.smart then
                error({leadingCloseParen = true})
            end
            if not result.errorPosCache[ERROR_LEADING_CLOSE_PAREN] then
                cacheErrorPos(result, ERROR_LEADING_CLOSE_PAREN)
            end
        end
        result.skipChar = true
    end

    if result.mode == PAREN_MODE then
        if not isValidCloseParen(result.parenStack, result.ch) then
            if result.smart then
                result.skipChar = true
            else
                error(createError(result, ERROR_UNMATCHED_CLOSE_PAREN))
            end
        elseif isCursorLeftOf(result.cursorX, result.cursorLine, result.x, result.lineNo) then
            resetParenTrail(result, result.lineNo, result.x)
            onIndent(result)
        else
            appendParenTrail(result)
            result.skipChar = true
        end
    end
end

local function onCommentLine(result)
    local parenTrailLen = tableSize(result.parenTrail.openers)

    -- restore the openers matching the previous paren trail
    if result.mode == PAREN_MODE then
        local i = 0
        while i < parenTrailLen do
            local opener = peek(result.parenTrail.openers, i)
            stackPush(result.parenStack, opener)
            i = i + 1
        end
    end

    local openerIdx = getParentOpenerIndex(result, result.x)
    local opener = peek(result.parenStack, openerIdx)
    if opener then
        -- shift the comment line based on the parent open paren
        if shouldAddOpenerIndent(result, opener) then
            addIndent(result, opener.indentDelta)
        end
    -- TODO: store some information here if we need to place close-parens after comment lines
    end

    -- repop the openers matching the previous paren trail
    if result.mode == PAREN_MODE then
        local i2 = 0
        while i2 < parenTrailLen do
            stackPop(result.parenStack)
            i2 = i2 + 1
        end
    end
end

local function checkIndent(result)
    if isCloseParen(result.ch) then
        onLeadingCloseParen(result)
    elseif isCommentChar(result.ch, result.commentChars) then
        -- comments don't count as indentation points
        onCommentLine(result)
        result.trackingIndent = false
    elseif result.ch ~= NEWLINE and result.ch ~= BLANK_SPACE and result.ch ~= TAB then
        onIndent(result)
    end
end

local function makeTabStop(result, opener)
    local tabStop = {
        ch = opener.ch,
        x = opener.x,
        lineNo = opener.lineNo
    }
    if isPositiveInt(opener.argX) then
        tabStop.argX = opener.argX
    end
    return tabStop
end

local function getTabStopLine(result)
    if result.selectionStartLine ~= UINT_NULL then
        return result.selectionStartLine
    end
    return result.cursorLine
end

local function setTabStops(result)
    if getTabStopLine(result) ~= result.lineNo then
        return
    end

    local parenStackLen = tableSize(result.parenStack)
    local i = 1
    while (i <= parenStackLen) do -- Lua ONE INDEX
        local ts = makeTabStop(result, result.parenStack[i])
        stackPush(result.tabStops, ts)
        i = i + 1
    end

    if result.mode == PAREN_MODE then
        local parenTrailOpenersLen = tableSize(result.parenTrail.openers)
        local i2 = parenTrailOpenersLen -- Lua ONE INDEX
        while (i2 > 0) do
            local ts2 = makeTabStop(result, result.parenTrail.openers[i2])
            stackPush(result.tabStops, ts2)
            i2 = i2 - 1
        end
    end

    -- remove argX if it falls to the right of the next stop
    local tabStopsLen = tableSize(result.tabStops)
    local i3 = 1
    while i3 <= tabStopsLen do -- Lua ONE INDEX
        local currentX = result.tabStops[i3].x
        local prevTabStop = result.tabStops[i3 - 1]
        if prevTabStop then
            local prevArgX = prevTabStop.argX
            if isInteger(prevArgX) and prevArgX >= currentX then
                prevTabStop.argX = nil
            end
        end
        i3 = i3 + 1
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- High-level processing functions

local function processChar(result, ch)
    local origCh = ch

    result.ch = ch
    result.skipChar = false

    handleChangeDelta(result)

    if result.trackingIndent then
        checkIndent(result)
    end

    if result.skipChar then
        result.ch = ""
    else
        onChar(result)
    end
    commitChar(result, origCh)
end

local function processLine(result, lineNo)
    initLine(result)

    local line = result.inputLines[lineNo]
    stackPush(result.lines, line)

    setTabStops(result)

    local lineLength = strLen(line)
    local x = 1 -- Lua ONE INDEX
    while x <= lineLength do
        result.inputX = x
        local line2 = result.inputLines[lineNo]
        local ch = getCharFromString(line2, x)
        processChar(result, ch)

        x = x + 1
    end
    processChar(result, NEWLINE)

    if not result.forceBalance then
        checkUnmatchedOutsideParenTrail(result)
        checkLeadingCloseParen(result)
    end

    if result.lineNo == result.parenTrail.lineNo then
        finishNewParenTrail(result)
    end
end

local function finalizeResult(result)
    if result.quoteDanger then
        error(createError(result, ERROR_QUOTE_DANGER))
    end
    if result.isInStr then
        error(createError(result, ERROR_UNCLOSED_QUOTE))
    end

    if not isStackEmpty(result.parenStack) then
        if (result.mode == PAREN_MODE) then
            error(createError(result, ERROR_UNCLOSED_PAREN))
        end
    end
    if result.mode == INDENT_MODE then
        initLine(result)
        onIndent(result)
    end

    result.success = true
end

local function processError(result, err)
    result.success = false
    if err.parinferError then
        err.parinferError = nil
        result.error = err
    else
        result.error.name = ERROR_UNHANDLED
        result.error.message = err.stack
        error(err)
    end
end

local function processTextInternal(result)
    for idx, line in pairs(result.inputLines) do
        result.inputLineNo = idx
        processLine(result, idx)
    end
    finalizeResult(result)
end

local doThePcall = true

local function processText(text, options, mode, smart)
    local result = getInitialResult(text, options, mode, smart)

    if doThePcall then
        local status, err =
            pcall(
            function()
                return processTextInternal(result)
            end
        )

        if status then
            return result
        else
            if err.leadingCloseParen or err.releaseCursorHold then
                return processText(text, options, PAREN_MODE, smart)
            end

            processError(result, err)
            return result
        end
    else
        processTextInternal(result)
        return result
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Public API

local function publicResult(result)
    local lineEnding = getLineEnding(result.origText)
    local final = {}
    if result.success then
        final.text = strJoin(result.lines, lineEnding)
        final.cursorX = result.cursorX
        final.cursorLine = result.cursorLine
        final.success = true
        final.tabStops = result.tabStops
        final.parenTrails = result.parenTrails
        if result.returnParens then
            final.parens = result.parens
        end
    else
        final.success = false
        final["error"] = result["error"]

        if result.partialResult then
            final.text = strJoin(result.lines, lineEnding)
            final.cursorX = result.cursorX
            final.cursorLine = result.cursorLine
            final.parenTrails = result.parenTrails
        else
            final.text = result.origText
            final.cursorX = result.origCursorX
            final.cursorLine = result.origCursorLine
            final.parenTrails = nil
        end

        if result.partialResult and result.returnParens then
            final.parens = result.parens
        end
    end

    if final.cursorX == UINT_NULL then
        final.cursorX = nil
    end
    if final.cursorLine == UINT_NULL then
        final.cursorLine = nil
    end
    if final.tabStops and isTableEmpty(final.tabStops) then
        final.tabStops = nil
    end

    return final
end

local function indentMode(text, options)
    options = parseOptions(options)
    return publicResult(processText(text, options, INDENT_MODE))
end

local function parenMode(text, options)
    options = parseOptions(options)
    return publicResult(processText(text, options, PAREN_MODE))
end

local function smartMode(text, options)
    options = parseOptions(options)
    local smart = options.selectionStartLine == nil
    return publicResult(processText(text, options, INDENT_MODE, smart))
end

M.version = "0.1.0"
M.indentMode = indentMode
M.parenMode = parenMode
M.smartMode = smartMode

return M
