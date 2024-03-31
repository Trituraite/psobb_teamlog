-- constants from chatlog. Prob will need? TODO: Delete as needed. 
local LOCALES = "EJTKB"
local MSG_REPLACE = "\9([" .. LOCALES .. "])"
local MAX_GAME_LOG = 30 -- need to test - supposedly it's 30? TODO
local MAX_MSG_SIZE = 100
local counter = 0 -- use as unique identifier
local chat_memory = {} -- use as a table 
local ordered_messages = {} -- messages in order

-- initialize an empty table for the chat memory
for i = 0, 58, 2 do -- 30 messages, 0 indexed
    chat_memory[i/2+1] = ""
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
    ]]
    -- test code for time here 
    local current_timestamp = os.date("%H:%M:%S", os.time())
    imgui.Text(current_timestamp)
    counter = counter + 1 
    imgui.Text(counter)

    -- above code shows that this body of code runs 30 times a second,
    -- or once every frame
    
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
        -- check if the message has changed: 
        if chat_memory[i/2+1] ~= descud_message(pso.read_wstr(0x00A98600+ 0x90*i, MAX_MSG_SIZE)) then
            local timestamped_message = add_timestamp(descud_message(pso.read_wstr(0x00A98600+ 0x90*i, MAX_MSG_SIZE)))
            table.insert(ordered_messages, timestamped_message)
        end 
        -- update memory here: 
        chat_memory[i/2+1] = descud_message(pso.read_wstr(0x00A98600+ 0x90*i, MAX_MSG_SIZE))
    end

    -- print the chat memory
    for index, value in ipairs(chat_memory) do
        imgui.Text(index)
        imgui.Text(value)
    end

    --print the ordered messages
    for index, value in ipairs(ordered_messages) do
        imgui.Text(index)
        imgui.Text(value)
    end
    
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