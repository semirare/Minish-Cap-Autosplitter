-- Minish Cap autosplitter for LiveSplit
-- Semirare, 2019 https://github.com/icemirrors18/Minish-Cap-Autosplitter
-- Requires LiveSplit 1.7+ See readme for setup information

current_split = 1
max_split = 1
started = false

--used to store splits based on how the user has set them up - populated in the establish_splits function
local splits_table ={}

--returns a table representing the given num as binary with bits number of digits
function toBits(num,bits)
	bits = bits or math.max(1, select(2, math.frexp(num)))
	local t = {}
	for b = bits, 1, -1 do
		t[b] = math.fmod(num, 2)
		num = math.floor((num - t[b]) / 2)
	end
	return t
end

local function init_livesplit()
	local host, port = "localhost", 16834
	local socket = require("socket")
	local tcp = assert(socket.tcp())

	tcp:connect(host, port)

    return tcp
end

local function check_current_split()
	local split = splits_table[currentSplit]
	if (split[1] == "FLAG") then
		check_flag(split[3], split[4])
	elseif (split[1] == "ENTERBOSS") then
		check_boss_entry(split[2])
	else
		--vaati splits
		check_vaati(split[2])
	end
end

--checks flag for item/dungeon entry/other flagged event
local function check_flag(address,bit)
	--read address
	read_byte = memory.readbyte(address)
	--convert to 8 bit binary
	read_byte = toBits(read_byte, 8)
	--check the correct bit in the binary
	if (read_byte[bit] == 1) then
		--flag for the current split is set, so split
		tcp_connection:send("split\r\n")
		split_num = split_num + 1
	end
end

--gets the player's current location to the location of each boss room
local function check_boss_entry(bossName)
	local current_location = get_player_location()
	if (bossName == "GLEEROK") then
		compare_locations(current_location[1], current_location[2], 81, 0)
	elseif (bossName == "MAZAAL") then
		compare_locations(current_location[1], current_location[2], 88, 2)
	elseif (bossName == "OCTO") then
		compare_locations(current_location[1], current_location[2], 96, 14)
	elseif (bossName == "GYORG") then
		compare_locations(current_location[1], current_location[2], 113, 0)
	elseif (bossName == "DARKNUTS") then
		--darknuts to V1
		compare_locations(current_location[1], current_location[2], 137, 0)
	else
		--V1 to V2
		compare_locations(current_location[1], current_location[2], 140, 0)
	end
end

local function check_vaati(segmentName)
	if (segmentName == "V2") then
		memory.usememorydomain("System Bus")
		--check if V2 hp hits threshold to end fight
		if (memory.readbyte(0x030016F5) == 188 or memory.readbyte(0x030016F5) == 190) then
			tcp_connection:send("split\r\n")
			split_num = split_num + 1
		end
	else
		--V3
		memory.usememorydomain("IWRAM")
		local location = get_player_location()
		memory.usememorydomain("EWRAM")
		if (memory.readbyte(0x2021EF4) == 0 and location[1] == 139 and location[2] == 0) then
			tcp_connection:send("split\r\n")
			split_num = split_num + 1
		end
	end
end

--gets the current area and room of the player
local function get_player_location()
	--returns the room and area as DECIMAL, not hex
	return {memory.readbyte(0x0BF4), memory.readbyte(0x0BF5)}
end

--checks if the player's location matches the goal location and splits if it does
local function compare_locations(currentArea, currentRoom, goalArea, goalRoom)
	if (currentArea == goalArea and currentRoom == goalRoom) then
		tcp_connection:send("split\r\n")
		split_num = split_num + 1	
	end
end

--check when to start the timer
local function check_start()
	if(memory.readbyte(0x1002) == 2) then
		--if we weren't started and game state becomes $02, game has been started
		started = true
		return true
	end
end

--splits string
function splitString (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

--set up for customized splits
local function establish_splits()
	local file = io.open("MinishCapAutosplitterConfig.txt", 'r')
	local splitNum = 1
	local splitInfo = {}
	for line in io.lines(file) do
		if (line[1] != "-") then
			splitInfo = splitString(line, ",")
			splits_table[splitNum] = splitInfo
			splitNum = splitNum + 1
		end
	end
	maxSplit = splitNum - 1
end

-- set up the livesplit connection
tcp_connection = init_livesplit()

-- set up the splits that the user has set up in AutosplitterConfig.txt
establish_splits()

-- set memory domain the IWRAM, almost every check is in IWRAM except V2 and V3 which will change the domain when needed
memory.usememorydomain("IWRAM")

while true do
    -- Check for when to start the timer
    if (not started) then
		if (check_start()) then
			tcp_connection:send("starttimer\r\n")
			started = true
		end
	end
	
	if (split_num <= maxSplit) then
		check_current_split()
	end
	emu.frameadvance()
end
