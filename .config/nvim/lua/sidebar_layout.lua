local M = {}
local pending, snapshots, owned, last_editor = {}, {}, {}, {}
local changing = false
local group = vim.api.nvim_create_augroup('SidebarLayout', { clear = true })

local function sidebar(win)
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    return ft == 'gitstatus' or ft == 'NvimTree'
end

function M.is_editor(win, tab)
    return win and vim.api.nvim_win_is_valid(win) and (not tab or vim.api.nvim_win_get_tabpage(win) == tab)
        and vim.api.nvim_win_get_config(win).relative == '' and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ''
end

function M.editor(tab, preferred)
    tab = tab or vim.api.nvim_get_current_tabpage()
    for _, win in ipairs({ preferred or 0, last_editor[tab] or 0 }) do
        if win ~= 0 and M.is_editor(win, tab) then return win end
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do if M.is_editor(win, tab) then return win end end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.w[win].history_pane == 'diff' then return win end
    end
end

local function capture(tab)
    local s = { windows = {} }
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.api.nvim_win_get_config(win).relative == '' then
            if sidebar(win) then
                owned[win] = tab
            else
                owned[win] = nil
                local left = vim.api.nvim_win_get_position(win)[2]
                local width = vim.api.nvim_win_get_width(win)
                s.left, s.right = math.min(s.left or left, left), math.max(s.right or left + width, left + width)
                s.windows[win] = { width = width, height = vim.api.nvim_win_get_height(win),
                    view = vim.api.nvim_win_call(win, vim.fn.winsaveview) }
            end
        end
    end
    return s
end

local function targets(tab, extra)
    local bars, columns, total = {}, {}, 0
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.api.nvim_win_get_config(win).relative == '' then
            if sidebar(win) then
                local desired = vim.w[win].sidebar_width or 40
                local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
                bars[#bars + 1] = { win = win, kind = ft, width = desired }
                total = total + desired
                if extra == ft then extra = nil end
            else
                columns[vim.api.nvim_win_get_position(win)[2]] = true
            end
        end
    end
    if extra then bars[#bars + 1] = { kind = extra, width = 40 }; total = total + 40 end
    local cols = vim.tbl_count(columns)
    local budget = math.max(#bars, vim.o.columns - math.max(40, cols * 20) - math.max(0, cols - 1) - #bars)
    for _, bar in ipairs(bars) do bar.width = math.max(1, math.floor(bar.width * math.min(1, budget / math.max(1, total)))) end
    return bars
end

function M.width(kind)
    for _, bar in ipairs(targets(vim.api.nvim_get_current_tabpage(), kind)) do if bar.kind == kind then return bar.width end end
    return 40
end

local function resize(tab, saved, extra)
    if not vim.api.nvim_tabpage_is_valid(tab) then return end
    changing = true
    for _, bar in ipairs(targets(tab, extra)) do
        if bar.win then
            vim.api.nvim_win_set_width(bar.win, bar.width)
            vim.w[bar.win].sidebar_applied = bar.width
            vim.wo[bar.win].winfixwidth = true
        end
    end
    local now = capture(tab)
    if saved and saved.left and now.left then
        local scale = (now.right - now.left) / math.max(1, saved.right - saved.left)
        for win, size in pairs(saved.windows) do
            if now.windows[win] then
                if not vim.wo[win].winfixwidth then vim.api.nvim_win_set_width(win, math.max(1, math.floor(size.width * scale + 0.5))) end
                vim.api.nvim_win_set_height(win, size.height)
            end
        end
        for win, size in pairs(saved.windows) do
            if now.windows[win] then vim.api.nvim_win_call(win, function() vim.fn.winrestview(size.view) end) end
        end
    end
    changing = false
    snapshots[tab] = capture(tab)
end

function M.prepare(tab, kind, preferred)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if sidebar(win) then
            local width = vim.api.nvim_win_get_width(win)
            if not vim.w[win].sidebar_width or width ~= vim.w[win].sidebar_applied then vim.w[win].sidebar_width = width end
        end
    end
    local saved = capture(tab)
    saved.editor = M.editor(tab, preferred)
    pending[tab] = saved
    if kind then resize(tab, saved, kind) end
    return saved.editor
end

function M.finish(tab)
    tab = tab or vim.api.nvim_get_current_tabpage()
    local saved = pending[tab]
    pending[tab] = nil
    resize(tab, saved)
    if saved and M.is_editor(saved.editor, tab) then last_editor[tab] = saved.editor end
end

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, { group = group, callback = function()
    local win, tab = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_tabpage()
    if M.is_editor(win, tab) then
        owned[win] = nil
        if vim.api.nvim_buf_get_name(0) ~= '' then last_editor[tab] = win end
    end
end })
vim.api.nvim_create_autocmd('WinResized', { group = group, callback = function()
    if changing then return end
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do snapshots[tab] = capture(tab) end
end })
vim.api.nvim_create_autocmd('WinClosed', { group = group, callback = function(event)
    local win = tonumber(event.match)
    local tab = owned[win]
    if not tab then return end
    owned[win] = nil
    local saved = pending[tab] or snapshots[tab]
    vim.schedule(function() resize(tab, saved) end)
end })
vim.api.nvim_create_autocmd('VimResized', { group = group, callback = function()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do resize(tab) end
end })
vim.api.nvim_create_autocmd('TabClosed', { group = group, callback = function()
    for tab in pairs(snapshots) do
        if not vim.api.nvim_tabpage_is_valid(tab) then snapshots[tab], pending[tab], last_editor[tab] = nil, nil, nil end
    end
end })

return M
