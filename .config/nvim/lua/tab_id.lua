local function render()
    local segments = {}

    for index = 1, vim.fn.tabpagenr('$') do
        local window_number = vim.fn.tabpagewinnr(index)
        local buffer_list = vim.fn.tabpagebuflist(index)
        local buffer_number = buffer_list[window_number]
        local buffer_name = vim.fn.bufname(buffer_number)
        local buffer_modified = vim.fn.getbufvar(buffer_number, '&mod') == 1

        segments[#segments + 1] = '%' .. index .. 'T'
        -- Use a different highlight for the active tab.
        segments[#segments + 1] = index == vim.fn.tabpagenr() and '%#TabLineSel#' or '%#TabLine#'
        segments[#segments + 1] = ' [' .. index .. '] '
        segments[#segments + 1] = buffer_name ~= '' and (vim.fn.fnamemodify(buffer_name, ':t') .. ' ') or '[No Name] '

        if buffer_modified then
            segments[#segments + 1] = '• '
        end
    end

    segments[#segments + 1] = '%#TabLineFill#'

    if vim.g.tablineclosebutton ~= nil then
        -- Keep the old optional close button hook.
        segments[#segments + 1] = '%=%999XX'
    end

    return table.concat(segments)
end

return render
