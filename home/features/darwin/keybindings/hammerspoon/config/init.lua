local SwipeGestures = require('SwipeGestures')
local MonitorManager = require('MonitorManager')
local ScreenshotShortcuts = require('ScreenshotShortcuts')

ipc = require("hs.ipc")
ipc.cliInstall()

-- Start MonitorManager for workspace state persistence
MonitorManager.start()
ScreenshotShortcuts.start()

-- Make MonitorManager globally accessible for debugging
_G.MonitorManager = MonitorManager

-- Layout switching is handled by AeroSpace's built-in toggle:
-- Alt+T -> "layout tiles horizontal vertical" (configured in aerospace/default.nix)
-- MonitorManager handles workspace state persistence across monitor changes and sleep/resume
