local M = {}

local hover_bufnr = nil
local hover_winid = nil
local loading_timer = nil

function M.bufnr()
  return hover_bufnr
end

---Stop loading animation
local function stop_loading()
  if loading_timer then
    loading_timer:stop()
    loading_timer:close()
    loading_timer = nil
  end
end

function M.close()
  stop_loading()
  if hover_winid and vim.api.nvim_win_is_valid(hover_winid) then
    vim.api.nvim_win_close(hover_winid, true)
    hover_winid = nil
  end
  if hover_bufnr and vim.api.nvim_buf_is_valid(hover_bufnr) then
    vim.api.nvim_buf_delete(hover_bufnr, { force = true })
    hover_bufnr = nil
  end
end

---Show loading indicator
function M.show_loading()
  M.close()
  
  hover_bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[hover_bufnr].buftype = 'nofile'
  vim.bo[hover_bufnr].bufhidden = 'wipe'
  vim.bo[hover_bufnr].swapfile = false
  
  local frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
  local frame_idx = 1
  
  vim.api.nvim_buf_set_lines(hover_bufnr, 0, -1, false, { frames[1] .. ' Translating...' })
  
  hover_winid = vim.api.nvim_open_win(hover_bufnr, false, {
    relative = 'cursor',
    row = 1,
    col = 0,
    width = 18,
    height = 1,
    style = 'minimal',
    border = 'rounded',
    zindex = 50,
  })
  
  vim.wo[hover_winid].wrap = false
  vim.wo[hover_winid].winhighlight = 'Normal:NormalFloat'
  
  -- Animate loading spinner
  local uv = vim.uv or vim.loop
  loading_timer = uv.new_timer()
  loading_timer:start(100, 100, function()
    vim.schedule(function()
      if hover_bufnr and vim.api.nvim_buf_is_valid(hover_bufnr) then
        frame_idx = (frame_idx % #frames) + 1
        pcall(vim.api.nvim_buf_set_lines, hover_bufnr, 0, -1, false, { frames[frame_idx] .. ' Translating...' })
      end
    end)
  end)
end

---@param text string
---@param opts? table
function M.show(text, opts)
  opts = opts or {}
  
  stop_loading()
  M.close()
  
  if not text or text == '' then
    return
  end
  
  local lines = vim.split(text, '\n')
  if #lines == 0 then
    return
  end
  
  hover_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(hover_bufnr, 0, -1, false, lines)
  vim.bo[hover_bufnr].buftype = 'nofile'
  vim.bo[hover_bufnr].bufhidden = 'wipe'
  vim.bo[hover_bufnr].swapfile = false
  
  -- Use syntax highlighting directly without setting filetype
  -- This avoids triggering ftplugin and LSP
  vim.api.nvim_buf_call(hover_bufnr, function()
    vim.cmd('syntax clear')
    vim.cmd('runtime! syntax/markdown.vim')
  end)
  
  local max_width = math.min(60, vim.o.columns - 4)
  local max_height = math.min(15, vim.o.lines - 4)
  
  -- Calculate content width
  local content_width = 0
  for _, line in ipairs(lines) do
    content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
  end
  local width = math.min(content_width + 2, max_width)
  
  -- Calculate height considering wrap
  -- Each line may wrap to multiple display lines
  local display_lines = 0
  for _, line in ipairs(lines) do
    local line_width = vim.fn.strdisplaywidth(line)
    if line_width == 0 then
      display_lines = display_lines + 1
    else
      -- How many lines this text will occupy when wrapped
      display_lines = display_lines + math.ceil(line_width / width)
    end
  end
  
  local height = math.min(display_lines, max_height)
  
  -- Position relative to cursor
  local row = 1  -- 1 line below cursor
  local col = 0  -- Align with cursor column
  
  -- Check if there's enough space below, otherwise show above
  local cursor = vim.api.nvim_win_get_cursor(0)
  local win_height = vim.api.nvim_win_get_height(0)
  local cursor_row = cursor[1]
  local lines_below = win_height - cursor_row
  
  if lines_below < height + 2 then
    -- Not enough space below, show above cursor
    row = -height - 1
  end
  
  hover_winid = vim.api.nvim_open_win(hover_bufnr, false, {
    relative = 'cursor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = opts.border or 'rounded',
    zindex = 50,
  })
  
  vim.wo[hover_winid].wrap = true
  vim.wo[hover_winid].number = false
  vim.wo[hover_winid].relativenumber = false
  vim.wo[hover_winid].cursorline = false
  vim.wo[hover_winid].winhighlight = 'Normal:NormalFloat'
end

return M
