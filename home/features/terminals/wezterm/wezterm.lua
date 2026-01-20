local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local action = wezterm.action

config.font = wezterm.font 'JetBrains Mono'
config.font_size = 13.0
config.color_scheme = 'Kanagawa (Gogh)'
config.pane_focus_follows_mouse = true
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.use_dead_keys = true
config.adjust_window_size_when_changing_font_size = false
config.front_end = "WebGpu"
config.webgpu_power_preference = 'HighPerformance'
config.window_close_confirmation = 'NeverPrompt'


config.keys = {{
    -- Map CMD/OPT to Emacs-style CTRL bindings (history/editing) for both layouts.
    key = "p",
    mods = "CMD",
    action = action.SendKey {
      key = "p",
      mods = "CTRL"
    }
}, {
    key = "p",
    mods = "OPT",
    action = action.SendKey {
      key = "p",
      mods = "CTRL"
    }
}, {
    key = 'n',
    mods = 'CMD',
    action = action.SendKey {
        key = 'n',
        mods = 'CTRL'
    }
}, {
    key = 'n',
    mods = 'OPT',
    action = action.SendKey {
        key = 'n',
        mods = 'CTRL'
    }
}, {
    key = 'u',
    mods = 'CMD',
    action = action.SendKey {
        key = 'u',
        mods = 'CTRL'
    }
}, {
    key = 'u',
    mods = 'OPT',
    action = action.SendKey {
        key = 'u',
        mods = 'CTRL'
    }
}, {
    key = 'l',
    mods = 'CMD',
    action = action.SendKey {
        key = 'l',
        mods = 'CTRL'
    }
}, {
    key = 'l',
    mods = 'OPT',
    action = action.SendKey {
        key = 'l',
        mods = 'CTRL'
    }
}, {
    key = 'c',
    mods = 'CMD',
    action = action.SendKey {
        key = 'c',
        mods = 'CTRL'
    }
}, {
    key = 'C',
    mods = 'CMD',
    action = action.CopyTo 'Clipboard'
}, {
    key = 'r',
    mods = 'OPT',
    action = action.SendKey {
        key = 'r',
        mods = 'CTRL'
    }
}, {
    -- Word-wise navigation in shells/readline.
    mods = "OPT",
    key = "LeftArrow",
    action = action.SendKey({
        mods = "ALT",
        key = "b"
    })
}, {
    mods = "OPT",
    key = "RightArrow",
    action = action.SendKey({
        mods = "ALT",
        key = "f"
    })
}, {
    -- Line start/end (Ctrl+A / Ctrl+E) for CMD, plus Ctrl+Alt+Arrow across keyboards.
    mods = "CMD",
    key = "LeftArrow",
    action = action.SendKey({
        mods = "CTRL",
        key = "a"
    })
}, {
    mods = "CMD|OPT",
    key = "LeftArrow",
    action = action.SendKey({
        mods = "CTRL",
        key = "a"
    })
}, {
    mods = "CMD|CTRL",
    key = "LeftArrow",
    action = action.SendKey({
        mods = "CTRL",
        key = "a"
    })
}, {
    mods = "CMD",
    key = "RightArrow",
    action = action.SendKey({
        mods = "CTRL",
        key = "e"
    })
}, {
    mods = "CMD|OPT",
    key = "RightArrow",
    action = action.SendKey({
        mods = "CTRL",
        key = "e"
    })
}, {
    mods = "CMD|CTRL",
    key = "RightArrow",
    action = action.SendKey({
        mods = "CTRL",
        key = "e"
    })
}, {
    -- Backspace/delete to start of line.
    mods = "CMD",
    key = "Backspace",
    action = action.SendKey({
        mods = "CTRL",
        key = "u"
    })
}, {
    mods = "OPT",
    key = "Backspace",
    action = action.SendKey({
        mods = "CTRL",
        key = "u"
    })
}}

return config
