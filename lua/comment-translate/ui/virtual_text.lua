local M = {}

local ns_id = vim.api.nvim_create_namespace('comment_translate_immersive')
local extmarks = {}

---@param bufnr number
function M.clear_buf(bufnr)
  -- Guard against nil bufnr to prevent table index errors
  if not bufnr then
    return
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    -- Buffer is invalid, just cleanup our tracking table
    if extmarks[bufnr] then
      extmarks[bufnr] = nil
    end
    return
  end

  if extmarks[bufnr] then
    for _, mark_id in pairs(extmarks[bufnr]) do
      pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, mark_id)
    end
    extmarks[bufnr] = {}
  end
end

function M.clear_all()
  for bufnr, _ in pairs(extmarks) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      M.clear_buf(bufnr)
    end
  end
  extmarks = {}
end

---@param bufnr number
---@param line number
---@param translated_text string
function M.show_inline(bufnr, line, translated_text)
  if not translated_text or translated_text == '' then
    return
  end

  -- Check buffer validity
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Check line number validity (line is 0-indexed)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if not line or line < 0 or line >= line_count then
    return
  end

  if extmarks[bufnr] and extmarks[bufnr][line] then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, ns_id, extmarks[bufnr][line])
  end

  local line_content = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ''
  local col = #line_content

  local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line, col, {
    virt_text = { { ' → ' .. translated_text, 'Comment' } },
    virt_text_pos = 'eol',
    hl_mode = 'combine',
  })
  
  if not ok then
    return
  end

  if not extmarks[bufnr] then
    extmarks[bufnr] = {}
  end
  extmarks[bufnr][line] = mark_id
end

---@param bufnr number
---@param line number
---@param translated_text string
function M.show(bufnr, line, translated_text)
  M.show_inline(bufnr, line, translated_text)
end

return M
