local M = {}

local function debug(...)
    print(vim.inspect(...))
    return arg
end

-- store the state of the buffer when first opened
---@type table<string, string>
local buffer_states = {}

---@class abc.Options
---@field ignore_blank_lines boolean

---@type abc.Options
local options = {
    ignore_blank_lines = true,
}

local ignored_buffer_starts_with = { "term://" }

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

    return true
end

---@param bufnr number
---@return boolean
local function is_buffer_visible(bufnr)
    return vim.fn.bufwinnr(bufnr) ~= -1
end

local function on_buf_enter(arg)
    local bufnr = arg.buf
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    if buffer_states[tostring(bufnr)] ~= nil then
        return
    end

    if not is_trackable_buffer(bufnr) then
        return
    end

    buffer_states[tostring(bufnr)] = prepare_buffer_state(lines)
end

local function on_buf_del(args)
    if buffer_states[tostring(args.buf)] ~= nil then
        buffer_states[tostring(args.buf)] = nil
    end
end

local function on_buf_leave(args)
    local bufnr = args.buf

    if not is_trackable_buffer(bufnr) then
        return
    end

    if not is_buffer_visible(bufnr) then
        return
    end
    -- ignore modified buffers
    if vim.api.nvim_buf_get_option(bufnr, "modified") then
        return
    end

    -- dont close if we only have one buffer
    local buffers = vim.fn.getbufinfo({ buflisted = 1 })
    if #buffers <= 1 then
        return
    end

    local stored_lines = buffer_states[tostring(bufnr)]
    if stored_lines == nil then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    if lines == nil then
        return
    end

    if stored_lines == prepare_buffer_state(lines) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
    end
end

M._tests = {
    get_buffer_states = function()
        return buffer_states
    end,
    clean = function()
        buffer_states = {}
    end,
}

---@param opts abc.Options
function M.setup(opts)
    options = vim.tbl_deep_extend("force", options, opts or {})

    vim.api.nvim_create_autocmd("BufEnter", {
        callback = on_buf_enter,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
        callback = on_buf_del,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        callback = on_buf_leave,
    })

    vim.api.nvim_create_user_command("AutoBufferCloseDebug", function()
        debug(buffer_states)
    end, {})
end

return M
