---@diagnostic disable: undefined-field

local abc = require("auto-buffer-close.init")

describe("buffer tracking logic", function()
    local test_counter = 0

    local function named_buffer(name)
        local buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf, name)
        return buf
    end

    local function wait_for(condition)
        local ok = vim.wait(1000, condition, 20)
        assert.True(ok)
    end

    before_each(function()
        test_counter = test_counter + 1
        abc._tests.clean()
        abc.setup({ ignore_blank_lines = true })
    end)

    after_each(function()
        pcall(vim.api.nvim_del_augroup_by_name, "auto-buffer-close")
        -- Clean up any remaining buffers
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match("^/tmp/test") then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end)

    describe("is_trackable_buffer", function()
        it("tracks normal file buffers", function()
            local buf = named_buffer("/tmp/test_" .. test_counter .. "_1.txt")
            vim.api.nvim_set_current_buf(buf)

            -- Should be tracked
            assert.is_not_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)

        it("ignores buffers with no name", function()
            local buf = vim.api.nvim_create_buf(true, false)
            -- No name set
            vim.api.nvim_set_current_buf(buf)

            -- Should not be tracked
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)

        it("ignores quickfix buffers", function()
            vim.cmd("copen")
            local buf = vim.api.nvim_get_current_buf()

            -- Should not be tracked (buftype = "quickfix")
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
            vim.cmd("cclose")
        end)

        it("ignores help buffers", function()
            vim.cmd("help")
            local buf = vim.api.nvim_get_current_buf()

            -- Should not be tracked (buftype = "help")
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
            vim.cmd("close")
        end)

        it("ignores terminal buffers", function()
            -- Create actual terminal buffer
            local buf = named_buffer("term://test_" .. test_counter)
            vim.api.nvim_set_current_buf(buf)

            -- Should not be tracked
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)

        it("ignores nofile buffers (like file trees)", function()
            local buf = named_buffer("NvimTree_" .. test_counter)
            vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
            vim.api.nvim_set_current_buf(buf)

            -- Should not be tracked
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)

        it("ignores prompt buffers (like telescope)", function()
            local buf = named_buffer("Telescope_" .. test_counter)
            vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
            vim.api.nvim_set_current_buf(buf)

            -- Should not be tracked
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)

        it("ignores neo-tree filetype buffers", function()
            local buf = named_buffer("/tmp/test_" .. test_counter .. "_neotree.txt")
            vim.api.nvim_buf_set_option(buf, "filetype", "neo-tree")
            vim.api.nvim_set_current_buf(buf)

            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)
    end)

    describe("buffer visibility and auto-close", function()
        it("closes unchanged hidden buffer", function()
            local buf1 = named_buffer("/tmp/test_" .. test_counter .. "_close1.txt")
            local buf2 = named_buffer("/tmp/test_" .. test_counter .. "_close2.txt")

            vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "initial" })
            vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "other" })
            vim.api.nvim_buf_set_option(buf1, "modified", false)
            vim.api.nvim_buf_set_option(buf2, "modified", false)

            vim.api.nvim_set_current_buf(buf1)
            vim.api.nvim_set_current_buf(buf2)

            wait_for(function()
                return not vim.api.nvim_buf_is_valid(buf1)
            end)
        end)

        it("does not close buffer visible in split", function()
            -- Create two normal buffers with unique names
            local buf1 = named_buffer("/tmp/test_" .. test_counter .. "_split1.txt")
            local buf2 = named_buffer("/tmp/test_" .. test_counter .. "_split2.txt")

            -- Set some content
            vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "line1" })
            vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "line2" })
            vim.api.nvim_buf_set_option(buf1, "modified", false)
            vim.api.nvim_buf_set_option(buf2, "modified", false)

            -- Enter buf1 to track it
            vim.api.nvim_set_current_buf(buf1)

            -- Create split and show buf1 in both windows
            vim.cmd("split")
            vim.api.nvim_set_current_buf(buf1)

            -- Switch to buf2 (should trigger BufLeave on buf1)
            vim.api.nvim_set_current_buf(buf2)

            -- buf1 should still exist (visible in split)
            assert.True(vim.api.nvim_buf_is_valid(buf1))

            vim.cmd("close") -- Close split
        end)

        it("does not close a file buffer when moving focus to a sidebar window", function()
            local buf1 = named_buffer("/tmp/test_" .. test_counter .. "_sidebar1.txt")
            local sidebar = named_buffer("neo-tree filesystem [1]")

            vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "line1" })
            vim.api.nvim_buf_set_option(buf1, "modified", false)
            vim.api.nvim_buf_set_option(sidebar, "buftype", "nofile")
            vim.api.nvim_buf_set_option(sidebar, "filetype", "neo-tree")

            vim.api.nvim_set_current_buf(buf1)

            vim.cmd("vsplit")
            local sidebar_win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(sidebar_win, sidebar)

            wait_for(function()
                return vim.api.nvim_buf_is_valid(buf1)
            end)

            assert.True(vim.api.nvim_buf_is_valid(buf1))
            assert.are.same(1, #vim.fn.win_findbuf(buf1))

            vim.cmd("close")
        end)

        it("does not close modified buffer", function()
            local buf1 = named_buffer("/tmp/test_" .. test_counter .. "_mod1.txt")
            local buf2 = named_buffer("/tmp/test_" .. test_counter .. "_mod2.txt")

            -- Enter buf1 and track initial state
            vim.api.nvim_set_current_buf(buf1)
            vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "initial" })

            -- Modify buffer
            vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "modified" })
            vim.api.nvim_buf_set_option(buf1, "modified", true)

            -- Switch away
            vim.api.nvim_set_current_buf(buf2)

            -- buf1 should still exist (it's modified)
            assert.True(vim.api.nvim_buf_is_valid(buf1))
        end)

        it("does not close a buffer that was edited and then saved", function()
            local buf1 = named_buffer("/tmp/test_" .. test_counter .. "_saved1.txt")
            local buf2 = named_buffer("/tmp/test_" .. test_counter .. "_saved2.txt")

            vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "initial" })
            vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "other" })
            vim.api.nvim_buf_set_option(buf1, "modified", false)
            vim.api.nvim_buf_set_option(buf2, "modified", false)

            vim.api.nvim_set_current_buf(buf1)
            vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "changed" })
            vim.api.nvim_buf_set_option(buf1, "modified", true)
            vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = buf1 })
            vim.api.nvim_buf_set_option(buf1, "modified", false)

            assert.True(abc._tests.get_edited_buffers()[tostring(buf1)])

            vim.api.nvim_set_current_buf(buf2)

            wait_for(function()
                return vim.api.nvim_buf_is_valid(buf1)
            end)

            assert.True(vim.api.nvim_buf_is_valid(buf1))
        end)
    end)

    describe("setup", function()
        it("replaces its autocmds when setup is called multiple times", function()
            abc.setup({})
            abc.setup({})

            local autocmds = vim.api.nvim_get_autocmds({ group = "auto-buffer-close" })

            assert.are.same(5, #autocmds)
        end)
    end)
end)
