local M = {}
local diff, files, revert = require 'mini.diff', require 'git_files', require 'git_revert'
local reviews = {}
local opening, normal_opening = false, false
local group = vim.api.nvim_create_augroup('GitReview', { clear = true })
local namespaces = { vim.api.nvim_create_namespace('MiniDiffViz'), vim.api.nvim_create_namespace('MiniDiffOverlay') }

diff.setup {
    source = { name = 'git_review', attach = function(buf) return reviews[buf] ~= nil and not reviews[buf].binary end },
    delay = { text_change = 100 },
    view = { style = 'sign', signs = { add = '+', change = '~', delete = '-' } },
    mappings = { apply = '', reset = '', textobject = '', goto_first = '', goto_prev = '', goto_next = '', goto_last = '' },
}

local function changed()
    vim.api.nvim_exec_autocmds('User', { pattern = 'GitReviewChanged', modeline = false })
end

function M.valid(review)
    return review and reviews[review.buf] == review and vim.api.nvim_win_is_valid(review.win)
        and vim.api.nvim_win_get_buf(review.win) == review.buf
end

function M.current()
    local win = vim.api.nvim_get_current_win()
    local review = reviews[vim.api.nvim_win_get_buf(win)]
    if M.valid(review) and review.win == win and not vim.w[win].history_pane then return review end
end

local function scope()
    local wins = {}
    for _, review in pairs(reviews) do if M.valid(review) then wins[#wins + 1] = review.win end end
    for _, ns in ipairs(namespaces) do vim.api.nvim__ns_set(ns, { wins = wins }) end
end

local function local_map(buf, mode, lhs)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do if map.lhs == lhs then return map end end
end

local function restore_maps(review)
    for _, saved in pairs(review.maps or {}) do
        local mode, lhs = saved.mode, saved.lhs
        local current = local_map(review.buf, mode, lhs)
        if current and current.callback == saved.callback then
            vim.keymap.del(mode, lhs, { buffer = review.buf })
            local old = saved.previous
            if old then
                vim.keymap.set(mode, lhs, old.callback or old.rhs, {
                    buffer = review.buf, noremap = old.noremap == 1, expr = old.expr == 1,
                    silent = old.silent == 1, nowait = old.nowait == 1, desc = old.desc,
                })
            end
        end
    end
end

function M.clear(buf, owner)
    buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
    local review = reviews[buf]
    if not review or (owner and review.win ~= owner) then return end
    if vim.api.nvim_buf_is_valid(buf) then
        restore_maps(review)
        vim.b[buf].git_diff_base = nil
        diff.disable(buf)
    end
    reviews[buf] = nil
    scope()
    changed()
end

-- A normal file open also exits review when it only focuses an existing window.
function M.normal_open(action)
    local previous = normal_opening
    normal_opening = true
    local ok, err = pcall(action)
    if ok then M.clear(vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()) end
    normal_opening = previous
    if not ok then error(err) end
end

local function overlay(review, text)
    text = files.normalize(text, review.buf)
    review.binary = text:find('\0', 1, true) ~= nil or vim.bo[review.buf].binary
    if review.binary then diff.disable(review.buf); return end
    local data = diff.get_buf_data(review.buf)
    if not data or not data.ref_text or text ~= review.text then
        diff.set_ref_text(review.buf, text)
        review.text = text
        data = diff.get_buf_data(review.buf)
    end
    if data and not data.overlay then diff.toggle_overlay(review.buf) end
end

local function refresh(review)
    if review.busy or review.binary or not vim.api.nvim_buf_is_loaded(review.buf) then return end
    review.busy = true
    local revision = review.revision
    files.reference(review.root, review, function(text, err)
        review.busy = false
        if reviews[review.buf] ~= review or not vim.api.nvim_buf_is_loaded(review.buf) or review.revision ~= revision then return end
        if err then
            if review.error ~= err then files.error(err) end
        else
            overlay(review, text)
        end
        review.error = err
    end, review.reference)
end

function M.refresh()
    local tab = vim.api.nvim_get_current_tabpage()
    for _, review in pairs(reviews) do
        if M.valid(review) and vim.api.nvim_win_get_tabpage(review.win) == tab then refresh(review) end
    end
end

local function reset_lines(review)
    if M.current() ~= review or review.resetting then return end
    if review.section == 'staged' then files.error('Cannot revert staged changes'); return end
    if review.conflict or review.binary then
        files.error(review.binary and 'Cannot revert lines in a binary file' or 'Cannot revert conflicted changes')
        return
    end
    local first, last = vim.fn.line('.'), vim.fn.line('.')
    if vim.fn.mode():match('^[vV\22]') then
        first = vim.fn.line('v')
        vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    end
    first, last = math.min(first, last), math.max(first, last)
    review.resetting, review.revision = true, review.revision + 1
    local buf, tick = review.buf, vim.api.nvim_buf_get_changedtick(review.buf)
    files.read(review.root, review.path, '', function(text, err, present)
        review.resetting = false
        if reviews[buf] ~= review or not vim.api.nvim_buf_is_loaded(buf) then return end
        if err then files.error(err); return end
        if not present then files.error('Cannot revert lines in an untracked file'); return end
        if vim.api.nvim_buf_get_changedtick(buf) ~= tick then files.error('Buffer changed; try X again'); return end
        if text:find('\0', 1, true) then files.error('Cannot revert lines in a binary file'); return end
        local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local restored = revert.lines(files.normalize(text, buf), current, first, last)
        local from, old_end, new_end = 0, #current, #restored
        while from < old_end and from < new_end and current[from + 1] == restored[from + 1] do from = from + 1 end
        while old_end > from and new_end > from and current[old_end] == restored[new_end] do
            old_end, new_end = old_end - 1, new_end - 1
        end
        if from < old_end or from < new_end then
            vim.api.nvim_buf_set_lines(buf, from, old_end, false, vim.list_slice(restored, from + 1, new_end))
        end
        overlay(review, text)
    end, review.reference.current)
end

local function goto_group(review, direction)
    if M.current() ~= review or review.binary then return end
    local data = diff.get_buf_data(review.buf)
    if data and #data.hunks > 0 then diff.goto_hunk(direction, { wrap = false }) end
end

local function bind_maps(review)
    local mappings = {
        { 'n', 'X', function() reset_lines(review) end, 'Revert current / selected diff lines' },
        { 'x', 'X', function() reset_lines(review) end, 'Revert current / selected diff lines' },
        { 'n', '[', function() goto_group(review, 'prev') end, 'Previous changed group' },
        { 'n', ']', function() goto_group(review, 'next') end, 'Next changed group' },
    }
    for _, mapping in ipairs(mappings) do
        local mode, lhs, callback, desc = unpack(mapping)
        local key = mode .. lhs
        local current = local_map(review.buf, mode, lhs)
        local saved = review.maps[key]
        if not saved then
            saved = { mode = mode, lhs = lhs, callback = callback }
            review.maps[key] = saved
        end
        if not current or current.callback ~= saved.callback then
            saved.previous = current
            vim.keymap.set(mode, lhs, saved.callback,
                { buffer = review.buf, silent = true, nowait = lhs == '[' or lhs == ']', desc = desc })
        end
    end
end

function M.open(root, entry, win)
    local buf = vim.fn.bufadd(vim.fs.joinpath(root, entry.path))
    local previous = vim.api.nvim_win_get_buf(win)
    local origin = vim.api.nvim_get_current_win()
    opening = true
    local ok, err = pcall(function()
        vim.api.nvim_set_current_win(win)
        -- Open from disk without a swap prompt, but reuse any loaded buffer and its edits.
        vim.cmd.buffer({ buf, mods = { hide = true, noswapfile = not vim.api.nvim_buf_is_loaded(buf) } })
    end)
    opening = false
    if not ok then
        if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
        error(err)
    end
    vim.bo[buf].buflisted = true
    M.clear(previous, win)
    M.clear(buf)
    local review = vim.tbl_extend('force', entry, { root = root, win = win, buf = buf, reference = {}, maps = {},
        revision = 0, jump_pending = true })
    reviews[buf] = review
    vim.b[buf].git_diff_base = files.base(entry) == 'HEAD' and 'HEAD' or 'index'
    bind_maps(review)
    scope()
    review.binary = files.contents(buf):find('\0', 1, true) ~= nil or vim.bo[buf].binary
    if review.binary then diff.disable(buf) else refresh(review) end
    changed()
    return review
end

-- Reference loading and MiniDiff's hunk calculation are asynchronous. Jump
-- once after the initial calculation, including in an unfocused preview pane.
vim.api.nvim_create_autocmd('User', { group = group, pattern = 'MiniDiffUpdated', callback = function(event)
    local review = reviews[event.buf]
    if not review or not review.jump_pending or not review.text or not M.valid(review) then return end
    review.jump_pending = nil
    local data = diff.get_buf_data(review.buf)
    if not data or #data.hunks == 0 then return end
    vim.api.nvim_win_call(review.win, function() diff.goto_hunk('first', { wrap = false, n_times = 1 }) end)
end })

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, { group = group, callback = function()
    local review = reviews[vim.api.nvim_get_current_buf()]
    if not review then return end
    if review.win ~= vim.api.nvim_get_current_win() then restore_maps(review)
    elseif normal_opening then M.clear(review.buf)
    else bind_maps(review); scope() end
end })
vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufWinLeave' }, { group = group, callback = function(event)
    if not opening and not vim.w.history_pane then M.clear(event.buf, vim.api.nvim_get_current_win()) end
end })
vim.api.nvim_create_autocmd('BufWinEnter', { group = group, callback = function(event)
    local review = reviews[event.buf]
    if opening or not review or vim.w.history_pane then return end
    local win = vim.api.nvim_get_current_win()
    -- A new sidebar split briefly duplicates the editor buffer. Wait for its
    -- actual buffer before treating this as a normal file open.
    vim.schedule(function()
        if M.valid(review) and review.win == win then M.clear(event.buf) end
    end)
end })
vim.api.nvim_create_autocmd('WinClosed', { group = group, callback = function(event)
    for buf, review in pairs(reviews) do if review.win == tonumber(event.match) then M.clear(buf) end end
end })
vim.api.nvim_create_autocmd('BufWipeout', { group = group, callback = function(event) M.clear(event.buf) end })

return M
