local M = {}
local layout = require 'sidebar_layout'
local group = vim.api.nvim_create_augroup('FileTabs', { clear = true })
local icons = require 'git_icons'
local redraw_pending = false

function M.list()
    return vim.tbl_filter(function(tab) return not vim.t[tab].project_search end, vim.api.nvim_list_tabpages())
end

function M.go(index)
    local tab = M.list()[index]
    if tab then vim.api.nvim_set_current_tabpage(tab) end
end

function M.cycle(delta)
    local tabs, current = M.list(), vim.api.nvim_get_current_tabpage()
    if #tabs == 0 then return end
    local index = delta > 0 and 0 or 1
    for i, tab in ipairs(tabs) do if tab == current then index = i; break end end
    vim.api.nvim_set_current_tabpage(tabs[(index - 1 + delta) % #tabs + 1])
end

local function redraw()
    if redraw_pending then return end
    redraw_pending = true
    vim.schedule(function()
        redraw_pending = false
        vim.cmd 'redrawtabline'
    end)
end

local function file_window(tab)
    local current = vim.api.nvim_tabpage_get_win(tab)
    return layout.editor(tab, current) or current
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'TabEnter', 'BufModifiedSet', 'BufWinEnter',
    'WinResized', 'VimResized', 'WinClosed', 'TabClosed' }, {
    group = group,
    callback = redraw,
})

local function editor_area(tab)
    local left, right, fallback_left, fallback_right
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        local config = vim.api.nvim_win_get_config(win)
        local filetype = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
        if config.relative == '' and not config.external and filetype ~= 'gitstatus' and filetype ~= 'NvimTree' then
            local column = vim.api.nvim_win_get_position(win)[2]
            local edge = column + vim.api.nvim_win_get_width(win)
            if layout.is_editor(win) then
                left, right = math.min(left or column, column), math.max(right or edge, edge)
            else
                -- Commit-diff, help, and terminal tabs are content too. Use them
                -- only if there are no ordinary file windows (not a bottom qf).
                fallback_left = math.min(fallback_left or column, column)
                fallback_right = math.max(fallback_right or edge, edge)
            end
        end
    end
    return left or fallback_left, right or fallback_right
end

local function clip(text, width)
    if vim.fn.strdisplaywidth(text) <= width then return text end
    if width <= 0 then return '' end
    local low, high = 0, vim.fn.strchars(text)
    while low < high do
        local middle = math.floor((low + high + 1) / 2)
        if vim.fn.strdisplaywidth(vim.fn.strcharpart(text, 0, middle) .. '…') <= width then
            low = middle
        else
            high = middle - 1
        end
    end
    return vim.fn.strcharpart(text, 0, low) .. '…'
end

local function viewport(tabs, active, width)
    if width <= 0 then return 1, 0, 0, false end
    local total = 0
    for _, tab in ipairs(tabs) do total = total + tab.width end
    if total <= width then return 1, #tabs, total, false end
    local markers = width >= 7
    local function margin(first, last)
        return markers and ((first > 1 and 2 or 0) + (last < #tabs and 2 or 0)) or 0
    end
    local first, last = active, active
    local selected = tabs[active]
    selected.text = clip(selected.text, width - margin(first, last))
    selected.width = vim.fn.strdisplaywidth(selected.text)
    local used = selected.width
    while true do
        local expanded = false
        if first > 1 and used + tabs[first - 1].width + margin(first - 1, last) <= width then
            first, used, expanded = first - 1, used + tabs[first - 1].width, true
        end
        if last < #tabs and used + tabs[last + 1].width + margin(first, last + 1) <= width then
            last, used, expanded = last + 1, used + tabs[last + 1].width, true
        end
        if not expanded then break end
    end
    return first, last, used + margin(first, last), markers
end

function M.render()
    local current = vim.api.nvim_get_current_tabpage()
    local left, right = editor_area(current)
    if not left then return '%T%#TabLineFill#' .. string.rep(' ', vim.o.columns) end
    local tabs, active = {}, 1

    for index, tab in ipairs(M.list()) do
        local buffer_number = vim.api.nvim_win_get_buf(file_window(tab))
        local buffer_name = vim.api.nvim_buf_get_name(buffer_number)
        local base = tab == current and 'TabLineSel' or 'TabLine'
        local label = buffer_name ~= '' and vim.fn.fnamemodify(buffer_name, ':t') or '[No Name]'
        if vim.bo[buffer_number].filetype == 'gitstatus' then label = 'Git Changes' end
        if vim.bo[buffer_number].filetype == 'NvimTree' then label = 'Files' end
        local git_title = vim.t[tab].git_view_title
        label = git_title or label

        local text = ' [' .. index .. '] '
        local icon = not git_title and icons[vim.b[buffer_number].git_file_status]
        if icon then text = text .. icon .. ' ' end
        if not git_title and vim.bo[buffer_number].modified and vim.bo[buffer_number].filetype ~= 'projectsearch' then text = text .. '• ' end
        text = text .. vim.fn.strtrans(label) .. ' '
        tabs[index] = { text = text, width = vim.fn.strdisplaywidth(text), base = base,
            number = vim.api.nvim_tabpage_get_number(tab) }
        if tab == current or tab == vim.t[current].project_search_origin then active = index end
    end
    if #tabs == 0 then return '%T%#TabLineFill#' .. string.rep(' ', vim.o.columns) end

    local close = vim.g.tablineclosebutton ~= nil and right > left
    local width = math.max(right - left - (close and 1 or 0), 0)
    local first, last, used, markers = viewport(tabs, active, width)
    local segments = { '%T%#TabLineFill#', string.rep(' ', left) }
    if markers and first > 1 then segments[#segments + 1] = '< ' end
    for index = first, last do
        local tab = tabs[index]
        segments[#segments + 1] = '%' .. tab.number .. 'T%#' .. tab.base .. '#'
        segments[#segments + 1] = tab.text:gsub('%%', '%%%%')
    end
    segments[#segments + 1] = '%T%#TabLineFill#'
    if markers and last < #tabs then segments[#segments + 1] = '> ' end
    segments[#segments + 1] = string.rep(' ', math.max(width - used, 0))
    -- Keep the optional close button inside the editor's right edge.
    if close then segments[#segments + 1] = '%999XX%X%T%#TabLineFill#' end
    segments[#segments + 1] = string.rep(' ', math.max(vim.o.columns - right, 0))

    return table.concat(segments)
end

return M
