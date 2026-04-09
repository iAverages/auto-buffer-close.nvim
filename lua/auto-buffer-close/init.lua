local M = {}

local function debug(...)
    if not vim.g.auto_buffer_close_debug then
        return
    end

    print(vim.inspect(...))
end

-- store the state of the buffer when first opened
---@type table<string, string>
local buffer_states = {}
---@type table<string, boolean>
local edited_buffers = {}

---@class abc.Options
---@field ignore_blank_lines boolean

---@type abc.Options
local options = {
    ignore_blank_lines = true,
}

local ignored_buffer_starts_with = { "term://" }
local ignored_filetypes = { ["neo-tree"] = true }

---@param lines string[]
---@return string
local function prepare_buffer_state(lines)
    return table.concat(lines, options.ignore_blank_lines and "" or "\n")
end

---@param str string
---@param start string
---@return boolean
local function starts_with(str, start)
    return string.sub(str, 1, #start) == start
end

---@param str string
---@param substr string
---@return boolean
local function string_contains(str, substr)
    return string.find(string.lower(str), string.lower(substr), 1, true) ~= nil
end

---@param array string[]
---@param str string
---@return boolean
local function contains_starts_with(array, str)
    for _, v in pairs(array) do
        if starts_with(str, v) then
            return true
        end
    end
    return false
end

---@param bufnr number
---@return boolean
local function is_trackable_buffer(bufnr)
    -- dont track special buffers
    local buftype = vim.api.nvim_buf_get_option(bufnr, "buftype")
    if buftype ~= "" then
        return false
    end

    -- dont track buffers with no name
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname == "" then
        return false
    end

    if contains_starts_with(ignored_buffer_starts_with, bufname) then
        return false
    end

    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
    if ignored_filetypes[filetype] then
        return false
    end

    if string_contains(bufname, "neotree") then
        return false
    end

    return true
end

---@param bufnr number
---@return boolean
local function is_buffer_visible(bufnr)
    return #vim.fn.win_findbuf(bufnr) > 0
end

local function on_buf_enter(arg)
    local bufnr = arg.buf
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local key = tostring(bufnr)

    if buffer_states[key] ~= nil then
        return
    end

    if not is_trackable_buffer(bufnr) then
        return
    end

    debug("entered buffer: " .. vim.inspect(vim.fn.getbufinfo(bufnr)))
    buffer_states[key] = prepare_buffer_state(lines)
    edited_buffers[key] = false
end

local function on_buf_del(args)
    local key = tostring(args.buf)
    buffer_states[key] = nil
    edited_buffers[key] = nil
end

local function on_buf_modified_set(args)
    local key = tostring(args.buf)
    if buffer_states[key] == nil then
        return
    end

    if vim.api.nvim_buf_get_option(args.buf, "modified") then
        edited_buffers[key] = true
    end
end

local function maybe_close_buffer(bufnr)
    local key = tostring(bufnr)

    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    if not is_trackable_buffer(bufnr) then
        return
    end

    if is_buffer_visible(bufnr) then
        return
    end

    -- ignore buffers that were edited at any point after first enter
    if edited_buffers[key] then
        return
    end

    -- dont close if we only have one buffer
    local buffers = vim.fn.getbufinfo({ buflisted = 1 })
    if #buffers <= 1 then
        return
    end

    local stored_lines = buffer_states[key]
    if stored_lines == nil then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    if lines == nil then
        return
    end

    if stored_lines == prepare_buffer_state(lines) then
        debug("closing buffer", bufnr)
        pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
    end
end

local function on_buf_leave(args)
    local bufnr = args.buf
    vim.schedule(function()
        maybe_close_buffer(bufnr)
    end)
end

M._tests = {
    get_buffer_states = function()
        return buffer_states
    end,
    get_edited_buffers = function()
        return edited_buffers
    end,
    clean = function()
        buffer_states = {}
        edited_buffers = {}
    end,
}

---@param opts abc.Options
function M.setup(opts)
    options = vim.tbl_deep_extend("force", options, opts or {})
    local group = vim.api.nvim_create_augroup("auto-buffer-close", { clear = true })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = group,
        callback = on_buf_enter,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
        group = group,
        callback = on_buf_del,
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        callback = on_buf_del,
    })

    vim.api.nvim_create_autocmd("BufModifiedSet", {
        group = group,
        callback = on_buf_modified_set,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        callback = on_buf_leave,
    })

    vim.api.nvim_create_user_command("AutoBufferCloseDebug", function()
        debug(buffer_states)
    end, {})
end

return M
