local M = {}

local function debug(...)
    print(vim.inspect(...))
    return arg
end

-- store the state of the buffer when first opened
---@type table<string, string>
local buffer_states = {}

local function on_buf_enter()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    if buffer_states[tostring(bufnr)] ~= nil then
        return
    end

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

    buffer_states[tostring(bufnr)] = table.concat(lines)
end

local function on_buf_del(args)
    if buffer_states[tostring(args.buf)] ~= nil then
        buffer_states[tostring(args.buf)] = nil
    end
end

local function on_buf_leave(args)
    local bufnr = args.buf
    local stored_lines = buffer_states[tostring(bufnr)]
    if stored_lines == nil then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    if lines == nil then
        return
    end

    if stored_lines == table.concat(lines) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
    end
end

function M.setup()
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
