local M = {}

---@class TranslateContext
---@field file_name? string File name (without path)
---@field file_type? string File type (e.g., 'go', 'lua', 'python')
---@field function_name? string Name of the function the comment belongs to
---@field function_signature? string Function signature
---@field struct_or_class? string Struct/class name if inside one
---@field package_or_module? string Package or module name
---@field imports? string[] Related imports
---@field surrounding_code? string Code around the comment
---@field node_type? string Type of the node (comment, string, etc.)

-- Function node types for different languages
local function_types = {
  'function_declaration',
  'method_declaration',
  'function_definition',
  'method_definition',
  'function',
  'arrow_function',
  'func_literal',
  'function_item',        -- Rust
  'function_definition',  -- Python
}

-- Struct/class node types
local struct_types = {
  'type_declaration',     -- Go
  'type_spec',            -- Go
  'struct_type',          -- Go
  'class_declaration',    -- JS/TS
  'class_definition',     -- Python
  'struct_item',          -- Rust
  'impl_item',            -- Rust
}

-- Package/module node types
local package_types = {
  'package_clause',       -- Go
  'module',               -- Various
  'namespace',            -- Various
}

---Get the function name at or near the cursor position using Tree-sitter
---@param bufnr number
---@param row number 0-indexed row
---@return string?, string? function_name, function_signature
local function get_function_at_position(bufnr, row)
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

  local function find_function(node, target_row)
    local node_start_row = node:start()
    local node_end_row = node:end_()
    local node_type = node:type()

    for _, ft in ipairs(function_types) do
      if node_type == ft then
        if node_start_row >= target_row or (node_start_row <= target_row and node_end_row >= target_row) then
          return node
        end
      end
    end

    for child in node:iter_children() do
      local child_end = child:end_()
      if child_end >= target_row then
        local result = find_function(child, target_row)
        if result then
          return result
        end
      end
    end

    return nil
  end

  local func_node = nil
  for offset = 0, 5 do
    func_node = find_function(root, row + offset)
    if func_node then
      break
    end
  end

  if not func_node then
    return nil, nil
  end

  local name = nil
  local name_node = func_node:field('name')[1]
  if name_node then
    name = vim.treesitter.get_node_text(name_node, bufnr)
  end

  local func_text = vim.treesitter.get_node_text(func_node, bufnr)
  local signature = nil
  if func_text then
    local lines = vim.split(func_text, '\n', { plain = true })
    signature = lines[1]
    -- For Go, include receiver if exists
    if signature and signature:match('^func%s*%(') then
      -- Already has receiver
    end
    if signature and #signature > 150 then
      signature = signature:sub(1, 150) .. '...'
    end
  end

  return name, signature
end

---Get struct/class name if cursor is inside one
---@param bufnr number
---@param row number 0-indexed row
---@return string?
local function get_struct_or_class(bufnr, row)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local root = tree:root()
  if not root then
    return nil
  end

  local function find_struct(node, target_row)
    local node_start_row = node:start()
    local node_end_row = node:end_()
    local node_type = node:type()

    for _, st in ipairs(struct_types) do
      if node_type == st then
        if node_start_row <= target_row and node_end_row >= target_row then
          -- Try to get name
          local name_node = node:field('name')[1]
          if name_node then
            return vim.treesitter.get_node_text(name_node, bufnr)
          end
          -- For Go type_spec
          for child in node:iter_children() do
            if child:type() == 'type_identifier' then
              return vim.treesitter.get_node_text(child, bufnr)
            end
          end
        end
      end
    end

    for child in node:iter_children() do
      local result = find_struct(child, target_row)
      if result then
        return result
      end
    end

    return nil
  end

  return find_struct(root, row)
end

---Get package/module name
---@param bufnr number
---@return string?
local function get_package_or_module(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local root = tree:root()
  if not root then
    return nil
  end

  -- Only check first few children (package is usually at top)
  for child in root:iter_children() do
    local child_type = child:type()
    
    if child_type == 'package_clause' then
      -- Go package
      local pkg_id = child:field('name')[1]
      if pkg_id then
        return vim.treesitter.get_node_text(pkg_id, bufnr)
      end
    end
    
    -- Stop after first 10 nodes to avoid scanning whole file
    if child:start() > 20 then
      break
    end
  end

  return nil
end

---Get surrounding code lines (smart extraction)
---@param bufnr number
---@param row number 0-indexed row
---@param context_lines? number Number of lines before and after (default 3)
---@return string?
local function get_surrounding_code(bufnr, row, context_lines)
  context_lines = context_lines or 3
  local total_lines = vim.api.nvim_buf_line_count(bufnr)
  
  -- Focus more on code after comment (what it describes)
  local start_line = math.max(0, row - 1)
  local end_line = math.min(total_lines, row + context_lines + 3)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  if #lines == 0 then
    return nil
  end
  
  -- Trim empty lines at start and end
  while #lines > 0 and lines[1]:match('^%s*$') do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines]:match('^%s*$') do
    table.remove(lines)
  end
  
  local result = table.concat(lines, '\n')
  
  -- Limit total length
  if #result > 500 then
    result = result:sub(1, 500) .. '\n...'
  end
  
  return result
end

---Collect context information for translation
---@param bufnr? number
---@param row? number 0-indexed row
---@param col? number 0-indexed column
---@param node_type? string
---@return TranslateContext
function M.collect(bufnr, row, col, node_type)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not row or not col then
    local cursor = vim.api.nvim_win_get_cursor(0)
    row = cursor[1] - 1
    col = cursor[2]
  end

  local ctx = {}

  -- File info
  local full_path = vim.api.nvim_buf_get_name(bufnr)
  ctx.file_name = vim.fn.fnamemodify(full_path, ':t')  -- Just filename
  ctx.file_type = vim.bo[bufnr].filetype
  ctx.node_type = node_type

  -- Package/module (for context)
  ctx.package_or_module = get_package_or_module(bufnr)

  -- Struct/class context
  ctx.struct_or_class = get_struct_or_class(bufnr, row)

  -- Function info
  local func_name, func_sig = get_function_at_position(bufnr, row)
  ctx.function_name = func_name
  ctx.function_signature = func_sig

  -- Surrounding code (reduced to focus on relevant parts)
  ctx.surrounding_code = get_surrounding_code(bufnr, row, 3)

  return ctx
end

---Format context for prompt (concise version)
---@param ctx TranslateContext
---@return string
function M.format_for_prompt(ctx)
  local parts = {}

  -- Language is most important
  if ctx.file_type then
    table.insert(parts, string.format('Language: %s', ctx.file_type))
  end

  -- Package context helps understand naming conventions
  if ctx.package_or_module then
    table.insert(parts, string.format('Package: %s', ctx.package_or_module))
  end

  -- Struct/class context
  if ctx.struct_or_class then
    table.insert(parts, string.format('Type: %s', ctx.struct_or_class))
  end

  -- Function signature is crucial for understanding the comment
  if ctx.function_signature then
    table.insert(parts, string.format('Function: %s', ctx.function_signature))
  elseif ctx.function_name then
    table.insert(parts, string.format('Function: %s', ctx.function_name))
  end

  -- Code context (concise)
  if ctx.surrounding_code then
    table.insert(parts, string.format('Code:\n```\n%s\n```', ctx.surrounding_code))
  end

  if #parts == 0 then
    return ''
  end

  return table.concat(parts, '\n')
end

return M
