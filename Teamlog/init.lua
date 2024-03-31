local core_mainmenu = require("core_mainmenu")
local cfg = require("Teamlog.configuration")
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

-- initialize an empty table for the chat memory
for i = 0, 58, 2 do -- 30 messages, 0 indexed
    chat_memory[i/2+1] = ""
end

-- Helpers in solylib
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
        io.write(string.format("    clChanged = %s,\n", tostring(options.clChanged)))
        io.write(string.format("    clAnchor = %i,\n", options.clAnchor))
        io.write(string.format("    clX = %i,\n", options.clX))
        io.write(string.format("    clY = %i,\n", options.clY))
        io.write(string.format("    clW = %i,\n", options.clW))
        io.write(string.format("    clH = %i,\n", options.clH))
        io.write(string.format("    clNoTitleBar = \"%s\",\n", options.clNoTitleBar))
        io.write(string.format("    clNoResize = \"%s\",\n", options.clNoResize))
        io.write(string.format("    clNoMove = \"%s\",\n", options.clNoMove))
        io.write(string.format("    clTransparentWindow = %s,\n", tostring(options.clTransparentWindow)))
        io.write("}\n")

        io.close(file)
    end
end


local function get_team_log()
    --[[
        Gets all the team chat messages.
        
        From fuzziqersoftware on psobb disc: 

        it appears that team chat messages are at 
        00A98600, which is a list of 30 char16_t[0x90] 
        buffers

        how tf did he know this? 

        -- Useful info --
        Starting Mem Address: 0x00A98600
        Message length: (mem buffer * bytes) = 0x90 * 16 bits = 0x90 * 2
        Total num messages: 30
        Ring buffer: Messages will loop back to starting address after 30th msg

        Helpful links:

        Chatlog source file: 
        https://github.com/jtuu/psochatlogaddon/blob/master/Chatlog/init.lua
        Soly's pso API (gets auto imported when .lua file in right directory...)
        https://github.com/search?q=repo%3ASolybum%2Fpsobbaddonplugin%20read_u32&type=code 

        From testing, it looks like this code runs 30 times every second, or...
        exactly once a frame? 
    ]]

    -- constantly check the memory addresses for new messages 
    for i = 0, 58, 2 do -- 30 messages, 0 indexed
        --[[
            --algorithm to go from ring buffer to linear buffer
            1. Read all thirty messages in a loop
            2. Insert the messages into a table (key - value)
            3. If the key's value changes from the previous element:
            4. Append the element to a growing list. 
            5. (OPTIONAL) add timestamps to each message. 
        ]]
        -- first read the mem addr for the message
        local message = descud_message(pso.read_wstr(0x00A98600+ 0x90*i, MAX_MSG_SIZE))
        -- if the message has changed, add it to the table of ordered messages
        if chat_memory[i/2+1] ~= message then
            local timestamped_message = add_timestamp(message)
            table.insert(ordered_messages, timestamped_message)
        end 
        -- update memory here after each cycle as last "known"
        chat_memory[i/2+1] = message
    end

    -- WARNING: trying to render an empty table will crash the game
    if #ordered_messages == 0 then
        -- Do nothing 
    else
        -- only if there are messages we attempt to render
        last_ten_messages = get_last_ten_elements(ordered_messages)
        for index, value in ipairs(last_ten_messages) do
            imgui.Text(value)
        end
    end
end

function get_last_ten_elements(input_table)
    -- get the last 10 elements of a table
    local length = #input_table
    local result = {}
    local start_index = math.max(length - 9, 1)
    
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
    --get_team_log()
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
        version = "0.1.0",
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