local core_mainmenu = require("core_mainmenu")
local cfg = require("Teamlog.configuration")
local lib_helpers = require("solylib.helpers")
local optionsLoaded, options = pcall(require, "Teamlog.options")

local optionsFileName = "addons/Teamlog/options.lua"
local firstPresent = true
local ConfigurationWindow

-- constants --
local LOCALES = "EJTKB"
local MSG_REPLACE = "\9([" .. LOCALES .. "])"
local MAX_MSG_SIZE = 100
local chat_memory = {} -- table, stores read msgs from mem
local ordered_messages = {} -- messages in order
local prevmaxy = 0

-- initialize an empty table for the chat memory
for i = 0, 58, 2 do -- 30 messages, 0 indexed
    chat_memory[i/2+1] = ""
end

-- Helpers in solylib
local function _getMenuState()
    local offsets = {
        0x00A98478,
        0x00000010,
        0x0000001E,
    }
    local address = 0
    local value = -1
    local bad_read = false
    for k, v in pairs(offsets) do
        if address ~= -1 then
            address = pso.read_u32(address + v)
            if address == 0 then
                address = -1
            end
        end
    end
    if address ~= -1 then
        value = bit.band(address, 0xFFFF)
    end
    return value
end
local function IsMenuOpen()
    local menuOpen = 0x43
    local menuState = _getMenuState()
    return menuState == menuOpen
end
local function IsSymbolChatOpen()
    local wordSelectOpen = 0x40
    local menuState = _getMenuState()
    return menuState == wordSelectOpen
end
local function IsMenuUnavailable()
    local menuState = _getMenuState()
    return menuState == -1
end
local function NotNilOrDefault(value, default)
    if value == nil then
        return default
    else
        return value
    end
end
local function GetPosBySizeAndAnchor(_x, _y, _w, _h, _anchor)
    local x
    local y

    local resW = pso.read_u16(0x00A46C48)
    local resH = pso.read_u16(0x00A46C4A)

    -- Top left
    if _anchor == 1 then
        x = _x
        y = _y

    -- Left
    elseif _anchor == 2 then
        x = _x
        y = (resH / 2) - (_h / 2) + _y

    -- Bottom left
    elseif _anchor == 3 then
        x = _x
        y = resH - _h + _y

    -- Top
    elseif _anchor == 4 then
        x = (resW / 2) - (_w / 2) + _x
        y = _y

    -- Center
    elseif _anchor == 5 then
        x = (resW / 2) - (_w / 2) + _x
        y = (resH / 2) - (_h / 2) + _y

    -- Bottom
    elseif _anchor == 6 then
        x = (resW / 2) - (_w / 2) + _x
        y = resH - _h + _y

    -- Top right
    elseif _anchor == 7 then
        x = resW - _w + _x
        y = _y

    -- Right
    elseif _anchor == 8 then
        x = resW - _w + _x
        y = (resH / 2) - (_h / 2) + _y

    -- Bottom right
    elseif _anchor == 9 then
        x = resW - _w + _x
        y = resH - _h + _y

    -- Whatever
    else
        x = _x
        y = _y
    end

    return { x, y }
end
-- End of helpers in solylib

if optionsLoaded then
    -- If options loaded, make sure we have all those we need
    options.configurationEnableWindow = NotNilOrDefault(options.configurationEnableWindow, true)
    options.enable                    = NotNilOrDefault(options.enable, true)
    options.useCustomTheme            = NotNilOrDefault(options.useCustomTheme, false)
    options.fontScale                 = NotNilOrDefault(options.fontScale, 1.0)

    options.clEnableWindow            = NotNilOrDefault(options.clEnableWindow, true)
    options.clHideWhenMenu            = NotNilOrDefault(options.clHideWhenMenu, true)
    options.clHideWhenSymbolChat      = NotNilOrDefault(options.clHideWhenSymbolChat, true)
    options.clHideWhenMenuUnavailable = NotNilOrDefault(options.clHideWhenMenuUnavailable, true)
    options.clChanged                 = NotNilOrDefault(options.clChanged, false)
    options.clTextColor               = NotNilOrDefault(options.clTextColor, 1)
    options.clAnchor                  = NotNilOrDefault(options.clAnchor, 1)
    options.clX                       = NotNilOrDefault(options.clX, 50)
    options.clY                       = NotNilOrDefault(options.clY, 50)
    options.clW                       = NotNilOrDefault(options.clW, 450)
    options.clH                       = NotNilOrDefault(options.clH, 350)
    options.clNoTitleBar              = NotNilOrDefault(options.clNoTitleBar, "")
    options.clNoResize                = NotNilOrDefault(options.clNoResize, "")
    options.clNoMove                  = NotNilOrDefault(options.clNoMove, "")
    options.clTransparentWindow       = NotNilOrDefault(options.clTransparentWindow, false)
    options.clTimestamps              = NotNilOrDefault(options.clTimestamps, false)
else
    options =
    {
        configurationEnableWindow = true,
        enable = true,
        useCustomTheme = false,
        fontScale = 1.0,

        clEnableWindow = true,
        clHideWhenMenu = false,
        clHideWhenSymbolChat = false,
        clHideWhenMenuUnavailable = false,
        clChanged = false,
        clTextColor = 1,
        clAnchor = 1,
        clX = 50,
        clY = 50,
        clW = 450,
        clH = 350,
        clNoTitleBar = "",
        clNoResize = "",
        clNoMove = "",
        clTransparentWindow = false,
        clTimestamps = false,
    }
end

local function SaveOptions(options)
    local file = io.open(optionsFileName, "w")
    if file ~= nil then
        io.output(file)

        io.write("return\n")
        io.write("{\n")
        io.write(string.format("    configurationEnableWindow = %s,\n", tostring(options.configurationEnableWindow)))
        io.write(string.format("    enable = %s,\n", tostring(options.enable)))
        io.write(string.format("    useCustomTheme = %s,\n", tostring(options.useCustomTheme)))
        io.write(string.format("    fontScale = %s,\n", tostring(options.fontScale)))
        io.write("\n")
        io.write(string.format("    clEnableWindow = %s,\n", tostring(options.clEnableWindow)))
        io.write(string.format("    clHideWhenMenu = %s,\n", tostring(options.clHideWhenMenu)))
        io.write(string.format("    clHideWhenSymbolChat = %s,\n", tostring(options.clHideWhenSymbolChat)))
        io.write(string.format("    clHideWhenMenuUnavailable = %s,\n", tostring(options.clHideWhenMenuUnavailable)))
        io.write(string.format("    clChanged = %s,\n", tostring(options.clChanged)))
        io.write(string.format("    clTextColor = %i,\n", options.clTextColor))
        io.write(string.format("    clAnchor = %i,\n", options.clAnchor))
        io.write(string.format("    clX = %i,\n", options.clX))
        io.write(string.format("    clY = %i,\n", options.clY))
        io.write(string.format("    clW = %i,\n", options.clW))
        io.write(string.format("    clH = %i,\n", options.clH))
        io.write(string.format("    clNoTitleBar = \"%s\",\n", options.clNoTitleBar))
        io.write(string.format("    clNoResize = \"%s\",\n", options.clNoResize))
        io.write(string.format("    clNoMove = \"%s\",\n", options.clNoMove))
        io.write(string.format("    clTransparentWindow = %s,\n", tostring(options.clTransparentWindow)))
        io.write(string.format("    clTimestamps = %s,\n", tostring(options.clTimestamps)))
        io.write("}\n")

        io.close(file)
    end
end

local colorTable =
{
    [1] = 0xFFFFFFFF,  -- White
    [2] = 0xFFFF0000,  -- Red
    [3] = 0xFF00FF00,  -- Green
    [4] = 0xFF0000FF,  -- Blue
    [5] = 0xFF00FFFF,  -- Cyan
    [6] = 0xFFFF00FF,  -- Magenta
    [7] = 0xFFFFFF00,  -- Yellow
    [8] = 0xFFFFA500,  -- Orange (Kelzan's favorite color)
    [9] = 0xFF6f00fe   -- Bright indigo (regular indigo too dark)
}


local function get_team_log()
    -- get all the team chat messages and render using imgui

    -- auto scroll down
    local sy = imgui.GetScrollY()
    local sym = imgui.GetScrollMaxY()
    scrolldown = false
    if sy <= 0 or prevmaxy == sy then
        scrolldown = true
    end

    -- read the entire ring buffer, format message, timestamp and render
    for i = 0, 58, 2 do
        --[[
            --algorithm to go from ring buffer to linear buffer
            1. Read all thirty messages in a loop
            2. Insert the messages into a table (key - value)
            3. If the key's value changes from the previous element:
            4. Append the element to a growing list. 
            5. Add timestamps to each message when they change.

            TODO: optimize this algorithm, make it run at 1Hz instead
            of 30Hz, make it read only single memory at a time instead
            of all 30 - not sure if this is important as other addons
            just operate at 30Hz...
        ]]
        -- first read the mem addr for the message
        local message = descud_message(pso.read_wstr(0x00A98600 + 0x90*i, MAX_MSG_SIZE))
        -- if the message has changed, add it to the table of ordered messages
        if chat_memory[i/2+1] ~= message then
            if options.clTimestamps then
                local timestamped_message = add_timestamp(message)
                table.insert(ordered_messages, timestamped_message)
            else
                table.insert(ordered_messages, message)
            end
        end 
        -- update memory here after each cycle as last "known"
        chat_memory[i/2+1] = message
    end
    
    -- render messages
    if #ordered_messages == 0 then
        -- Do nothing - attempting to render an empty table crashes the game 
    else
        -- only if there are messages we attempt to render
        last_ten_messages = get_last_hundred_elements(ordered_messages)
        for index, value in ipairs(last_ten_messages) do
            -- Set text color and render as wrapped
            local c = lib_helpers.GetColorAsFloats(colorTable[options.clTextColor])
            imgui.PushStyleColor("Text", c.r, c.g, c.b, c.a)
            imgui.TextWrapped(value)
        end
        -- scrolldown window on new chat
        if scrolldown then
            imgui.SetScrollY(imgui.GetScrollMaxY())
        end
        -- set prev state for scroll
        prevmaxy = imgui.GetScrollMaxY()
    end
end

function get_last_hundred_elements(input_table)
    -- get the last 100 elements of a table
    local length = #input_table
    local result = {}
    local start_index = math.max(length - 99, 1)
    
    for i = start_index, length do
        table.insert(result, input_table[i])
    end
    
    return result

end


function descud_message(message)
    -- remove the tab + local identifier (\9 = tab in lua)
    local output = string.gsub(message, MSG_REPLACE, "")
    return output 
end 

function add_timestamp(message)
    local ts = os.date("%H:%M:%S", os.time())
    local combined_string = "["..ts .."] " .. message
    return combined_string
end

local function present()
    -- If the addon has never been used, open the config window
    -- and disable the config window setting
    if options.configurationEnableWindow then
        ConfigurationWindow.open = true
        options.configurationEnableWindow = false
    end
    
    ConfigurationWindow.Update()
    if ConfigurationWindow.changed then
        ConfigurationWindow.changed = false
        SaveOptions(options)
    end

    -- Global enable here to let the configuration window work
    if options.enable == false then
        return
    end

    if (options.clEnableWindow == true)
        and (options.clHideWhenMenu == false or IsMenuOpen() == false)
        and (options.clHideWhenSymbolChat == false or IsSymbolChatOpen() == false)
        and (options.clHideWhenMenuUnavailable == false or IsMenuUnavailable() == false)
    then
        if firstPresent or options.clChanged then
            options.clChanged = false
            local ps = GetPosBySizeAndAnchor(options.clX, options.clY, options.clW, options.clH, options.clAnchor)
            imgui.SetNextWindowPos(ps[1], ps[2], "Always");
            imgui.SetNextWindowSize(options.clW, options.clH, "Always");
        end

        if options.clTransparentWindow == true then
            imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.0)
        end

        if imgui.Begin("Teamlog", nil, { options.clNoTitleBar, options.clNoResize, options.clNoMove }) then
            imgui.SetWindowFontScale(options.fontScale)
            get_team_log()
        end
        imgui.End()

        if options.clTransparentWindow == true then
            imgui.PopStyleColor()
        end

        if firstPresent then
            firstPresent = false
        end
	end
end

local function init()
    ConfigurationWindow = cfg.ConfigurationWindow(options)

    local function mainMenuButtonHandler()
        ConfigurationWindow.open = not ConfigurationWindow.open
    end

    core_mainmenu.add_button("Teamlog", mainMenuButtonHandler)

    return
    {
        name = "TeamLog",
        version = "0.2.0",
        author = "trituraite",
        present = present
    }
end

return {
    -- actual execution code, equivalent to if __name__ == "__main__": ? 
    __addon =
    {
        init = init,
    },
}
