# comment-translate.nvim

It translates comments and strings in code, helping developers understand multilingual codebases.

## Features

- **Hover Translation**: Display translation when hovering over comments or strings
- **Immersive Translation**: Automatically translate and display comments inline in the buffer
- **Translate and Replace**: Translate selected text and replace it
- **Translation Cache**: Speed up re-translation of the same text
- **TreeSitter Support**: Accurate comment/string detection

## Requirements

- Neovim 0.8+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (required)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) (recommended)
- `curl` command
- Internet connection
- Translation backend uses the unofficial Google Translate HTTP endpoint via
  `curl`. Network policies (proxy/firewall) or upstream endpoint changes can
  break translation; document this for your users if stability is critical.

## Privacy / Data Handling

**Important**: This plugin sends the text you translate (comments, strings, or visual selections) to an external translation service over the network.

- **External transmission**: Translation uses the unofficial Google Translate HTTP endpoint (`translate.googleapis.com`) via `curl`.
- **What is sent**: The selected text / detected comment or string content. If it contains **personal data**, **credentials**, **internal code**, or other sensitive information, it may be transmitted outside your environment.
- **Cache behavior**: The built-in cache is **in-memory only** (no files are written by the plugin). Once Neovim exits, the cache is cleared.
- **Recommendation**: If you work in restricted/compliance environments, set `target_language` explicitly and consider disabling the plugin (or avoid translating sensitive buffers/text).

## Installation

### lazy.nvim

```lua
{
  'noir4y/comment-translate.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('comment-translate').setup({
      target_language = 'ja',
    })
  end,
}
```

### packer.nvim

```lua
use {
  'noir4y/comment-translate.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  config = function()
    require('comment-translate').setup({
      target_language = 'ja',
    })
  end,
}
```

### Manual Installation

```bash
# Clone to plugin directory
git clone https://github.com/noir4y/comment-translate.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/comment-translate.nvim

# Install dependencies
git clone https://github.com/nvim-lua/plenary.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/plenary.nvim
git clone https://github.com/nvim-treesitter/nvim-treesitter \
  ~/.local/share/nvim/site/pack/plugins/start/nvim-treesitter
```

Add to init.lua:
```lua
require('comment-translate').setup({
  target_language = 'ja',
})
```

## Configuration

```lua
require('comment-translate').setup({
  target_language = 'ja',  -- Target language (default: auto-detected from system locale, fallback 'en')
  translate_service = 'google',  -- Currently only 'google' is supported
  hover = {
    enabled = true,  -- Enable hover translation
    delay = 500,  -- Additional delay (ms) after CursorHold before showing hover
    auto = true,  -- If false, disable auto-hover and use explicit keymap
  },
  immersive = {
    enabled = false,  -- Enable immersive translation on startup
  },
  cache = {
    enabled = true,  -- Enable translation cache
    max_entries = 1000,  -- Maximum cache entries
  },
  max_length = 5000,  -- Maximum translation text length
  targets = {
    comment = true,  -- Include comments as translation targets
    string = true,  -- Include strings as translation targets
  },
  keymaps = {
    hover = '<leader>th',  -- Hover translation
    hover_manual = '<leader>tc',  -- Manual hover trigger (when auto is disabled)
    replace = '<leader>tr',  -- Replace selected text with translation
    toggle = '<leader>tt',  -- Toggle immersive translation ON/OFF (global)
  },
})
```

### Configuration Notes

**target_language**: The default value is automatically detected from your system
locale environment variables (`LANG`, `LANGUAGE`, `LC_ALL`) or Vim's language
setting. If detection fails, it falls back to `'en'`. Set this explicitly if
you want a specific target language.

**hover.delay**: This delay is applied *after* the `CursorHold` event fires.
The total time before hover appears is `'updatetime'` (Neovim option, default
4000ms) plus `hover.delay`. To make hover appear faster, reduce both values.

### Custom Keymaps

You can disable default keymaps and set up your own:

```lua
require('comment-translate').setup({
  target_language = 'ja',
  keymaps = {
    hover = false,         -- Disable default keymap
    hover_manual = false,  -- Disable manual hover keymap
    replace = false,
    toggle = false,
  },
})

-- Use <Plug> mappings to set up custom keymaps
vim.keymap.set('n', '<leader>th', '<Plug>(comment-translate-hover)')
vim.keymap.set('x', '<leader>tr', '<Plug>(comment-translate-replace)')
vim.keymap.set('n', '<leader>tt', '<Plug>(comment-translate-toggle)')
```

## Commands

- `:CommentTranslateHover` - Display translation for comment under cursor
- `:CommentTranslateHoverToggle` - Toggle auto hover ON/OFF
- `:CommentTranslateReplace` - Replace selected text with translation
- `:CommentTranslateToggle` - Toggle immersive translation ON/OFF (global)
- `:CommentTranslateUpdate` - Update immersive translation for current buffer
- `:CommentTranslateSetup` - Setup plugin with default settings (useful for manual init)
- `:CommentTranslateHealth` - Check plugin health (alias for `:checkhealth comment-translate`)

## Usage

### Hover Translation

When you hover over a comment or string, the translation result will automatically appear in a popup.

**Timing**: The hover popup appears after `'updatetime'` (Neovim option, default
4000ms) plus `hover.delay` (default 500ms). To make hover appear faster:

```lua
-- In your Neovim config
vim.opt.updatetime = 300  -- Faster CursorHold trigger

-- In plugin setup
hover = { delay = 200 }   -- Shorter additional delay
```

**Manual Mode**: Set `hover.auto = false` to disable automatic hover and use an explicit keymap (`<leader>tc` by default) to trigger translation. This is useful if you find automatic hover distracting. You can also toggle auto-hover at runtime with `:CommentTranslateHoverToggle`.

### Immersive Translation

Run `:CommentTranslateToggle` to translate and display all comments inline.

**Note**: Immersive mode is **global** — when enabled, it automatically applies
to all buffers. When you switch to a different buffer, translations are
automatically applied there as well. Toggling OFF disables it for all buffers.

Translations are displayed inline next to the original text.

### Translate and Replace Selected Text

Select text in visual mode and run `:CommentTranslateReplace` to replace the selection with its translation.

## Testing

### Quick Test

After installing the plugin, create a test file and verify:

```lua
-- test.lua
-- This is a test comment
local x = 1
```

Open the file in Neovim and hover over the comment to see the translation.

## License

MIT
