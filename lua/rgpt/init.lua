local M = {}

-- Aliases
local fn = vim.fn
local api = vim.api
local notify = vim.notify


-- Variables
local const_flags = "--no-spinner"
M.defaults = {
    --- Set default flags which are always set
    --- See the wiki for a list of flags https://github.com/NewDawn0/rgpt
    --- note: Unable to be overridden in the prompt
    default_flags = "--no-timeout",
    --- Choose where to display the response:
    ---     new_buf: Display in new buffer
    ---     replace_sel: Replace the current selection
    ---     insert_below: Insert below the current selection
    response_return = "new_buf"
}
M.options = M.defaults

-- =========================== Helper functions =========================== -- 
-- Split by newline into table
local function spit_newline(str)
    local tbl = {}
    for line in str:gmatch("[^\r\n]+") do
        table.insert(tbl, line)
    end
    return tbl
end
-- Extend table
local function extend_table(t1, t2)
    for i=1, #t2 do
        t1[#t1+1] = t2[i]
    end
    return t1
end
-- Check if response buffer exists
local function response_exists()
    for _, win in ipairs(api.nvim_list_wins()) do
        local buf = api.nvim_win_get_buf(win)
        if api.nvim_buf_get_name(buf):match("[^/]+$") == 'RGPT' then
            return win
        end
    end
    return false
end

-- Return response 
local function ret(prompt, response)
    local qa = extend_table(spit_newline(prompt), spit_newline(response))
    if M.options.response_return == "new_buf" then
        local win = response_exists()
        if win then
            api.nvim_set_current_win(win)
            api.nvim_buf_set_lines(0, -1, -1, true, {prompt, response})
        else
            api.nvim_command('vsplit | enew')
            api.nvim_buf_set_option(0, 'buftype', 'nofile')
            api.nvim_buf_set_option(0, 'bufhidden', 'wipe')
            api.nvim_buf_set_lines(0, -1, -1, true, qa)
            api.nvim_buf_set_name(0, 'RGPT')
            vim.opt_local.wrap = true
        end
        fn.bufadd(response)
    elseif M.options.response_return == "replace_sel" then
        fn.setreg('"', response)
    else
        fn.append(fn.line('.'), response)
    end
end
-- Get selection
local function get_visual_sel()
    local sstart = fn.getpos("'<")
    local send = fn.getpos("'>")
    local nlines = math.abs(send[2] - sstart[2]) + 1
    local lines = api.nvim_buf_get_lines(0, sstart[2] -1, send[2], false)
    if next(lines) == nil then
        return nil
    end
    lines[1] = string.sub(lines[1], sstart[3], - 1)
    if nlines == 1 then
        lines[nlines] = string.sub(lines[nlines], 1, send[3] - sstart[3] + 1)
    else
        lines[nlines] = string.sub(lines[nlines], 1, send[3])
    end
    return table.concat(lines, '\n')
end
-- Propmt
local function get_prompt()
    local input = fn.input("Prompt: ")
    if input == '' then
        return nil
    else
        return input
    end
end
-- Run
local function run(prompt, flags)
    local str = fn.system(string.format('rgpt %s %s %s', prompt, M.options.default_flags, flags))
    return str:sub(5)
end

-- =========================== Module functions =========================== -- 
-- Config function
function M.setup(options)
    if options.default_flags then
        M.defaults.default_flags = options.default_flags
    end
    if not (options.response_return == "new_buf" or
        options.response_return == "replace_sel" or
        options.response_return == "insert_below") then
        error("Invalid value at response_return in rgpt config")
        return nil
    else
        M.defaults.response_return = options.response_return
    end
end

-- Query
function M.query()
    local input = get_prompt()
    if input == nil then
        notify("Fill out prompt", vim.log.levels.ERROR)
    else
        local res = run(input)
        ret(input, res)
    end
end
-- Explain
function M.explain_region()
    local input = get_visual_sel()
    if input == nil then
        vim.notify("Nothing in selection", vim.log.levels.ERROR)
    else
        local prompt = string.format("Please explain the following code: %s", input)
        local res = run(prompt)
        ret(prompt, res)
    end

end

return M
