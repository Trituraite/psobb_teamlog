-- constants from chatlog. Prob will need? TODO: Delete as needed. 
local LOCALES = "EJTK"
local MSG_MATCH = "^(.-) > \t([" .. LOCALES .. "])(.+)"
local MSG_REPLACE = "^\t[" .. LOCALES .. "]"
local MAX_GAME_LOG = 29 -- need to test - supposedly it's 30? TODO
local MAX_MSG_SIZE = 100 
local output_messages = {}

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
    ]]
    -- test code for time here 
    local current_timestamp = os.date("%H:%M:%S", os.time())
    imgui.Text(current_timestamp)

    -- read few messages
    for i= 0,10,2 do 
        local ptr = pso.read_wstr(0x00A98600+ 0x90*i, MAX_MSG_SIZE)
        imgui.Text(ptr)
        -- print repr string
        imgui.Text(string.format("%q",ptr))
        imgui.Text(descud_message(ptr))
        imgui.Text("\n")
    end
end


function descud_message(message)
    -- remove the tab + local identifier (\9 = tab in lua)
    -- TODO: make it work for all languages
    local output = string.gsub(message, "\9E", "")
    return output 
end 

local function present()
    get_team_log()
end

local function init()
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