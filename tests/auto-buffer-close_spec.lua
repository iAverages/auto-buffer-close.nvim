---@diagnostic disable: undefined-field

local abc = require("auto-buffer-close.init")

describe("buffer tracking logic", function()
    local test_counter = 0

    before_each(function()
        test_counter = test_counter + 1
        abc._tests.clean()
        abc.setup({ ignore_blank_lines = true })
    end)

    after_each(function()
        vim.cmd("autocmd! BufEnter")
        vim.cmd("autocmd! BufDelete")
        vim.cmd("autocmd! BufLeave")
        -- Clean up any remaining buffers
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match("^/tmp/test") then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end)

    describe("is_trackable_buffer", function()
        it("tracks normal file buffers", function()
            local buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(buf, "/tmp/test_" .. test_counter .. "_1.txt")
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
            local buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_name(buf, "term://test_" .. test_counter)
            vim.api.nvim_set_current_buf(buf)

            -- Should not be tracked
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)

        it("ignores nofile buffers (like file trees)", function()
            local buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
            vim.api.nvim_buf_set_name(buf, "NvimTree_" .. test_counter)
            vim.api.nvim_set_current_buf(buf)

            -- Should not be tracked
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)

        it("ignores prompt buffers (like telescope)", function()
            local buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
            vim.api.nvim_buf_set_name(buf, "Telescope_" .. test_counter)
            vim.api.nvim_set_current_buf(buf)

            -- Should not be tracked
            assert.is_nil(abc._tests.get_buffer_states()[tostring(buf)])
        end)
    end)

    describe("buffer visibility and auto-close", function()
        it("does not close buffer visible in split", function()
            -- Create two normal buffers with unique names
            local buf1 = vim.api.nvim_create_buf(true, false)
            local buf2 = vim.api.nvim_create_buf(true, false)

            vim.api.nvim_buf_set_name(buf1, "/tmp/test_" .. test_counter .. "_split1.txt")
            vim.api.nvim_buf_set_name(buf2, "/tmp/test_" .. test_counter .. "_split2.txt")

            -- Set some content
            vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "line1" })
            vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "line2" })

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

        it("does not close modified buffer", function()
            local buf1 = vim.api.nvim_create_buf(true, false)
            local buf2 = vim.api.nvim_create_buf(true, false)

            vim.api.nvim_buf_set_name(buf1, "/tmp/test_" .. test_counter .. "_mod1.txt")
            vim.api.nvim_buf_set_name(buf2, "/tmp/test_" .. test_counter .. "_mod2.txt")

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
    end)
end)
