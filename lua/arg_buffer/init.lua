local state = {
    buf = nil,
    namespace=nil,
    index = 0,
    window = nil,
    old_window= nil
};

local M = {}

local function set_args()
    local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
    local new_args = {}
    local newlines_signes = vim.fn.sign_getplaced(state.buf, {group="ARG_BUFFER_newlines"})
    local newline_set = {}
    for _i, nl_line in ipairs(newlines_signes[1].signs) do
        newline_set[nl_line.lnum] = true
    end

    local active_sign = vim.fn.sign_getplaced(state.buf, {group="ARG_BUFFER_active_file"})[1].signs[1].lnum

    -- reverse the lines since we need to add buttom newlines to 
    local i = #lines
    local active_pos
    while i > 0 do
        local current_file = lines[i]
        local start_line = i
        -- Loop while we have a newline sign for the current line
        while i > 0 and newline_set[i] == true do
            i = i - 1
            -- concat the current_file with the line before
            current_file = lines[i].. '\n' .. current_file
        end
        -- add file arg to the start of the new_args list
        table.insert(new_args, 1, vim.fn.fnameescape(current_file))
        -- test if the active line is between a file with newline
        if start_line >= active_sign and i <= active_sign then
            active_pos = #new_args
        end
        i = i -1
    end
    vim.api.nvim_cmd(
        {
            cmd='args',
            args=new_args,
        },
        {}
    )
    local active_index = #new_args -(active_pos-1)
    local old_win_number = vim.api.nvim_win_get_number(state.old_window)
    vim.api.nvim_cmd(
        {
            cmd='windo',
            range={old_win_number, old_win_number},
            args = {
                "argument",
                active_index,
            }
        },
        {}
    )
end

local function set_and_close()
    set_args()
    vim.api.nvim_win_close(state.window, true)
    state.window = nil
    state.old_window= nil
end

local function set_active(line)
    vim.fn.sign_unplace("ARG_BUFFER_active_file", {buffer=state.buf, id=1})
    vim.fn.sign_place(1, "ARG_BUFFER_active_file", "ARG_BUFFER_current_file", state.buf, {lnum=line, priority=100})
    state.index = line
end

local function set_newline(line)
    vim.fn.sign_place(0, "ARG_BUFFER_newlines", "ARG_BUFFER_newline_file", state.buf, {lnum=line, priority=1})
end
local function create()
    local buf = vim.api.nvim_create_buf(true, true)
    vim.keymap.set(
        "n",
        "q",
        set_and_close,
        {
            silent = true,
            buffer = buf
    
        }
    )
    vim.keymap.set(
        "n",
        "<ESC>",
        set_and_close,
        {
            silent = true,
            buffer = buf
        }
    )
    vim.keymap.set(
        "n",
        "<F3>",
        set_and_close,
        {
            silent = true,
            buffer = buf
        }
    )
    vim.keymap.set(
        "n",
        "<Enter>",
        function()
            local line, _column = unpack(vim.api.nvim_win_get_cursor(0))
            set_active(line)
        end,
        {
            silent = true,
            buffer = buf
        }
    )
    return buf
end


function M.setup()
    vim.fn.sign_define("ARG_BUFFER_current_file", {text = "✦", linehl="Search"})
    vim.fn.sign_define("ARG_BUFFER_newline_file", {text = "⤷", texthl="Search"})
end

function M.open()
    if state.buf == nil then 
        state.buf = create()
        state.namespace = vim.api.nvim_create_namespace('ArgBuffer')
    end
    -- OpenWindow
    local arg_count = vim.fn.argc()
    state.old_window = vim.api.nvim_get_current_win()
    state.window= vim.api.nvim_open_win(
        state.buf,
        true,
        {
            relative='editor',
            row=3,
            col=3,
            width=60,
            height=arg_count+3,
            border='rounded',
            title='Arglist'
        }
    )
    
    -- Fill the buffer
    local arg_list = vim.fn.argv()
    local index = vim.fn.argidx() + 1
    local lines = {}
    local line_numbers = {}
    local indicator
    for i, arg in ipairs(arg_list) do
        for sub_arg in string.gmatch(arg, "([^\n]+)") do
            table.insert(lines, sub_arg)
            table.insert(line_numbers, i)
        end
    end
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    local last_line_num = -1
    local offset = 0
    for i, n in ipairs(line_numbers) do
        if last_line_num == n then
            set_newline(i)
            if n <= index then
                offset = offset +1
            end
        end
        last_line_num = n
    end
    set_active(index + offset)
end

return M
