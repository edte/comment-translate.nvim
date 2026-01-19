local M = {}
local cache = require('comment-translate.translate.cache')
local utils = require('comment-translate.utils')

---@return boolean, table?
local function get_plenary_job()
  local ok, Job = pcall(require, 'plenary.job')
  if not ok then
    return false, nil
  end
  return true, Job
end

---@return boolean
local codebuddy_available = nil
local function check_codebuddy()
  if codebuddy_available == nil then
    codebuddy_available = vim.fn.executable('codebuddy') == 1
  end
  return codebuddy_available
end

---Get language name for prompt
---@param lang_code string
---@return string
local function get_language_name(lang_code)
  local lang_map = {
    zh = 'Chinese',
    en = 'English',
    ja = 'Japanese',
    ko = 'Korean',
    fr = 'French',
    de = 'German',
    es = 'Spanish',
    pt = 'Portuguese',
    ru = 'Russian',
    it = 'Italian',
    vi = 'Vietnamese',
    th = 'Thai',
    ar = 'Arabic',
  }
  return lang_map[lang_code] or lang_code
end

---Build prompt with context
---@param text string
---@param target_lang string
---@param context? TranslateContext
---@return string
local function build_prompt(text, target_lang, context)
  local target_name = get_language_name(target_lang)
  local parts = {}

  -- System instruction
  table.insert(parts, string.format('Translate this code comment to %s. Output ONLY the translation.', target_name))

  -- Add compact context if available
  if context then
    local ctx_parts = {}
    
    if context.file_type then
      table.insert(ctx_parts, context.file_type)
    end
    
    if context.package_or_module then
      table.insert(ctx_parts, 'pkg:' .. context.package_or_module)
    end
    
    if context.struct_or_class then
      table.insert(ctx_parts, 'type:' .. context.struct_or_class)
    end
    
    if #ctx_parts > 0 then
      table.insert(parts, '[' .. table.concat(ctx_parts, ', ') .. ']')
    end

    -- Function signature is most useful
    if context.function_signature then
      table.insert(parts, 'Function: ' .. context.function_signature)
    end

    -- Code context (concise)
    if context.surrounding_code then
      table.insert(parts, '```')
      table.insert(parts, context.surrounding_code)
      table.insert(parts, '```')
    end
  end

  table.insert(parts, '')
  table.insert(parts, 'Comment: ' .. text)

  return table.concat(parts, '\n')
end

---Translate text using codebuddy CLI
---@param text string
---@param target_lang string
---@param source_lang? string
---@param callback fun(result: string?)
---@param context? TranslateContext
function M.translate(text, target_lang, source_lang, callback, context)
  if not callback then
    error('callback is required')
  end

  local cached = cache.get(text, target_lang, source_lang)
  if cached then
    vim.schedule(function()
      callback(cached)
    end)
    return
  end

  if utils.is_empty(text) then
    vim.schedule(function()
      callback('')
    end)
    return
  end

  local config = require('comment-translate.config')
  if #text > config.config.max_length then
    vim.schedule(function()
      callback(nil)
    end)
    return
  end

  if not check_codebuddy() then
    vim.schedule(function()
      vim.notify('comment-translate: codebuddy is required for translation', vim.log.levels.ERROR)
      callback(nil)
    end)
    return
  end

  local ok, Job = get_plenary_job()
  if not ok then
    vim.schedule(function()
      vim.notify('comment-translate: plenary.nvim is required for translation', vim.log.levels.ERROR)
      callback(nil)
    end)
    return
  end

  local prompt = build_prompt(text, target_lang, context)

  local stdout_output = {}
  local stderr_output = {}

  Job:new({
    command = 'codebuddy',
    args = { '-p', '-y', prompt },
    on_stdout = function(_, data)
      if data and data ~= '' then
        table.insert(stdout_output, data)
      end
    end,
    on_stderr = function(_, data)
      if data and data ~= '' then
        table.insert(stderr_output, data)
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          local err_msg = 'comment-translate: Translation failed (codebuddy error)'
          if #stderr_output > 0 then
            err_msg = err_msg .. ': ' .. table.concat(stderr_output, ' ')
          end
          vim.notify(err_msg, vim.log.levels.WARN)
          callback(nil)
          return
        end

        local result = table.concat(stdout_output, '\n')
        if not result or result == '' then
          callback(nil)
          return
        end

        -- Filter out plugin error messages from codebuddy output
        local lines = vim.split(result, '\n', { plain = true })
        local filtered = {}
        for _, line in ipairs(lines) do
          -- Skip lines that contain plugin error notices
          if not line:match('plugin error') and not line:match('Run /plugin') then
            table.insert(filtered, line)
          end
        end
        result = table.concat(filtered, '\n')

        -- Trim whitespace
        result = utils.trim(result)

        if result == '' then
          callback(nil)
          return
        end

        cache.set(text, result, target_lang, source_lang)
        callback(result)
      end)
    end,
  }):start()
end

return M
