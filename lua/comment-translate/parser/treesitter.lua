local M = {}

local config = require('comment-translate.config')

local comment_node_types = {
  'comment',
  'line_comment',
  'block_comment',
  'documentation_comment',
  'doc_comment',
}

-- Line comment types that should be merged when consecutive
local line_comment_types = {
  'comment',
  'line_comment',
}

local string_node_types = {
  'string',
  'string_literal',
  'string_content',
  'text',
}

---Check if node type is a line comment (not block comment)
---@param node_type string
---@return boolean
local function is_line_comment_type(node_type)
  for _, type_name in ipairs(line_comment_types) do
    if node_type == type_name then
      return true
    end
  end
  return false
end

---Check if node type is a comment
---@param node_type string
---@return boolean
local function is_comment_type(node_type)
  for _, type_name in ipairs(comment_node_types) do
    if node_type == type_name then
      return true
    end
  end
  return false
end

---Collect consecutive line comments starting from a node
---@param bufnr number
---@param start_node userdata
---@return string merged text of all consecutive comments
local function collect_consecutive_comments(bufnr, start_node)
  local start_type = start_node:type()
  
  -- For block comments, just return the node text directly
  if not is_line_comment_type(start_type) then
    return vim.treesitter.get_node_text(start_node, bufnr)
  end
  
  local comments = {}
  local start_row = start_node:start()
  
  -- Collect previous consecutive comments (going up)
  local prev = start_node:prev_sibling()
  local prev_row = start_row - 1
  while prev do
    local prev_type = prev:type()
    local prev_start_row, _, prev_end_row, _ = prev:range()
    
    -- Check if it's a line comment and is on the immediately previous line
    if is_line_comment_type(prev_type) and prev_end_row == prev_row then
      local text = vim.treesitter.get_node_text(prev, bufnr)
      if text and text ~= '' then
        table.insert(comments, 1, text) -- Insert at beginning
      end
      prev_row = prev_start_row - 1
      prev = prev:prev_sibling()
    else
      break
    end
  end
  
  -- Add current comment
  local current_text = vim.treesitter.get_node_text(start_node, bufnr)
  if current_text and current_text ~= '' then
    table.insert(comments, current_text)
  end
  
  -- Collect next consecutive comments (going down)
  local next_node = start_node:next_sibling()
  local _, _, end_row, _ = start_node:range()
  local next_row = end_row + 1
  while next_node do
    local next_type = next_node:type()
    local next_start_row, _, next_end_row, _ = next_node:range()
    
    -- Check if it's a line comment and is on the immediately next line
    if is_line_comment_type(next_type) and next_start_row == next_row then
      local text = vim.treesitter.get_node_text(next_node, bufnr)
      if text and text ~= '' then
        table.insert(comments, text)
      end
      next_row = next_end_row + 1
      next_node = next_node:next_sibling()
    else
      break
    end
  end
  
  return table.concat(comments, '\n')
end

---@param bufnr number
---@param row number
---@param col number
---@return string?, string?
function M.get_text_at_position(bufnr, row, col)

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil, nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil, nil
  end

  local root = tree:root()
  if not root then
    return nil, nil
  end

  local node = root:named_descendant_for_range(row, col, row, col)
  if not node then
    return nil, nil
  end

  local node_type = node:type()
  local is_comment = false
  local is_string = false

  for _, type_name in ipairs(comment_node_types) do
    if node_type == type_name then
      is_comment = true
      break
    end
  end

  for _, type_name in ipairs(string_node_types) do
    if node_type == type_name then
      is_string = true
      break
    end
  end

  if not is_comment and not is_string then
    local parent = node:parent()
    while parent do
      local parent_type = parent:type()
      for _, type_name in ipairs(comment_node_types) do
        if parent_type == type_name then
          is_comment = true
          node = parent
          node_type = parent_type
          break
        end
      end
      if is_comment then break end
      
      for _, type_name in ipairs(string_node_types) do
        if parent_type == type_name then
          is_string = true
          node = parent
          break
        end
      end
      if is_string then break end

      parent = parent:parent()
    end
  end

  if is_comment and not config.config.targets.comment then
    return nil, nil
  end
  if is_string and not config.config.targets.string then
    return nil, nil
  end

  if is_comment then
    -- For comments, try to merge consecutive line comments
    local text = collect_consecutive_comments(bufnr, node)
    if text and text ~= '' then
      return text, node_type
    end
  elseif is_string then
    local text = vim.treesitter.get_node_text(node, bufnr)
    if text and text ~= '' then
      return text, node_type
    end
  end

  return nil, nil
end

---@param bufnr number
---@return table<number, string>
function M.get_all_comments(bufnr)
  if not config.config.targets.comment then
    return {}
  end
  
  local comments = {}
  
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return {}
  end
  
  local tree = parser:parse()[1]
  if not tree then
    return {}
  end
  
  local root = tree:root()
  
  local function traverse(node)
    local node_type = node:type()
    
    for _, type_name in ipairs(comment_node_types) do
      if node_type == type_name then
        local text = vim.treesitter.get_node_text(node, bufnr)
        if text and text ~= '' then
          local start_row = node:start()
          comments[start_row] = text
        end
        return
      end
    end
    
    for child in node:iter_children() do
      traverse(child)
    end
  end
  
  traverse(root)
  
  return comments
end

return M
