---@diagnostic disable: undefined-global
describe('config', function()
  local config

  before_each(function()
    -- Reset module cache
    package.loaded['comment-translate.config'] = nil
    config = require('comment-translate.config')
    config.reset()
  end)

  describe('setup', function()
    it('should use default values when no config provided', function()
      config.setup()

      assert.is_not_nil(config.config)
      assert.equals('google', config.config.translate_service)
      assert.is_true(config.config.hover.enabled)
      assert.equals(500, config.config.hover.delay)
      assert.is_false(config.config.immersive.enabled)
      assert.is_true(config.config.cache.enabled)
      assert.equals(1000, config.config.cache.max_entries)
    end)

    it('should merge user config with defaults', function()
      config.setup({
        target_language = 'ja',
        translate_service = 'google',
        hover = {
          delay = 1000,
        },
      })

      assert.equals('ja', config.config.target_language)
      assert.equals(1000, config.config.hover.delay)
      -- Default values should be preserved
      assert.is_true(config.config.hover.enabled)
      assert.is_true(config.config.hover.auto)
    end)

    it('should handle nested config correctly', function()
      config.setup({
        immersive = {
          enabled = true,
        },
      })

      assert.is_true(config.config.immersive.enabled)
    end)

    it('should handle empty config', function()
      config.setup({})

      assert.is_not_nil(config.config)
      assert.is_not_nil(config.config.hover)
      assert.is_not_nil(config.config.immersive)
    end)
  end)

  describe('get', function()
    it('should return current config', function()
      config.setup({ target_language = 'fr' })

      local current = config.get()
      assert.equals('fr', current.target_language)
    end)
  end)

  describe('reset', function()
    it('should reset to default config', function()
      config.setup({ target_language = 'zh' })
      config.reset()

      -- Should be back to default (system locale or 'en')
      assert.is_not_nil(config.config.target_language)
      assert.equals('google', config.config.translate_service)
    end)
  end)
end)
