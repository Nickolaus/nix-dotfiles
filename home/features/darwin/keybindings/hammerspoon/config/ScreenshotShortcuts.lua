local ScreenshotShortcuts = {}

local function shottr(path)
    return function()
        hs.urlevent.openURL("shottr://" .. path)
    end
end

local bindings = {
    { { "cmd", "shift" }, "x", "grab/area", "Shottr area capture" },
    { { "cmd", "ctrl", "shift" }, "x", "grab/fullscreen", "Shottr fullscreen capture" },
    { { "cmd", "ctrl", "shift" }, "w", "grab/window", "Shottr window capture" },
    { { "cmd", "ctrl", "shift" }, "s", "grab/scrolling", "Shottr scrolling capture" },
    { { "cmd", "ctrl", "shift" }, "r", "grab/repeat", "Shottr repeat area capture" },
    { { "cmd", "ctrl", "shift" }, "o", "ocr", "Shottr OCR" },
}

function ScreenshotShortcuts.start()
    for _, binding in ipairs(bindings) do
        hs.hotkey.bind(binding[1], binding[2], binding[4], shottr(binding[3]))
    end
end

return ScreenshotShortcuts
