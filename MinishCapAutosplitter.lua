-- Minish Cap autosplitter for LiveSplit
-- Semirare, 2019 https://github.com/icemirrors18/Minish-Cap-Autosplitter
-- Requires LiveSplit 1.7+ See readme for setup information

--CHANGE THE BELOW LINE BASED ON WHAT CATEGORY YOU ARE RUNNING
--change to one of the following: "ANY", "FIREROD", "GLITCHLESS", "HUNDO", "PK22AH"
--make sure you have your "MinishCapAutosplitterConfig_(category name).txt" file setup for your splits
category = "ANY"

current_split = 1
done = false
started = false

--used for weird hundo splits
kinstoneCave = false
kinstoneField = false

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

--gets the current area and room of the player
local function get_player_location()
	--returns the room and area as DECIMAL, not hex
	memory.usememorydomain("IWRAM")
	local location = {memory.readbyte(0x0BF4), memory.readbyte(0x0BF5)}
	memory.usememorydomain("EWRAM")
	return location
end

--checks if the player's location matches the goal location and splits if it does
local function compare_locations(areaid, roomid)
	local player_loc = get_player_location()
	if (player_loc[1] == areaid and player_loc[2] == roomid) then
		tcp_connection:send("split\r\n")
		current_split = current_split + 1	
	end
end

local function check_kinstone_split()
	--hundo why do you do this
	local player_loc = get_player_location()
	if (kinstoneCave) then
		if (kinstoneField) then
			--if both cave and field have been entered, split upon town entry
			if (player_loc[1] == 2 and player_loc[2] == 0) then
				tcp_connection:send("split\r\n")
				current_split = current_split + 1
			end
		else
			--if cave has been entered but field hasn't check for field entry
			if (player_loc[1] == 3 and player_loc[2] == 7) then
				kinstoneField = true
			end
		end
	else
		--check for cave entry
		if (player_loc[1] == 19 and player_loc[2] == 3) then
			kinstoneCave = true;
		end
	end
end

--checks flag for item/dungeon entry/other flagged event
local function check_flag(address,bit)
	--read address
	memory.usememorydomain("EWRAM")
	read_byte = memory.readbyte(tonumber(address))
	--convert to 8 bit binary
	read_byte = toBits(read_byte, 8)
	--check the correct bit in the binary
	if (read_byte[bit] == 1) then
		--flag for the current split is set, so split
		tcp_connection:send("split\r\n")
		current_split = current_split + 1
	end
end

--check if the player has entered  the goal room
local function check_area_entry(areaid, roomid)
	if (goalName == "WINDRUINS") then
		--check for castor minish cave HP then location
		if check_flag(0x2D23, 8) then
			compare_locations(5, 0)
		end			
	elseif (goalName == "LEAVECLOUDTOPS") then
		--check for light arrows then location
		if check_flag(0x2B34, 4) then
			compare_locations(3, 1)
		end	
	else
		compare_locations(areaid, roomid)
	end
end

local function check_vaati(segmentName)
	if (segmentName == "V2") then
		memory.usememorydomain("System Bus")
		--check if V2 hp hits threshold to end fight
		if (memory.readbyte(0x030016F5) == 188 or memory.readbyte(0x030016F5) == 190) then
			tcp_connection:send("split\r\n")
			current_split = current_split + 1
		end
	else
		--V3
		memory.usememorydomain("IWRAM")
		local location = get_player_location()
		memory.usememorydomain("EWRAM")
		if (memory.readbyte(0x21EF4) == 0 and location[1] == 139 and location[2] == 0) then
			tcp_connection:send("split\r\n")
			done = true
		end
	end
end

--check when to start the timer
local function check_start()
	memory.usememorydomain("IWRAM")
	if(memory.readbyte(0x1002) == 2) then
		--if we weren't started and game state becomes 2, game has been started
		started = true
		memory.usememorydomain("EWRAM")
		return true
	end
end

local function check_current_split()
	local split = splits_table[current_split]
	if (split[1] == "FLAG") then
		check_flag(split[2], tonumber(split[3]))
	elseif (split[1] == "LOCATION") then
		check_area_entry(tonumber(split[2]), tonumber(split[3]))
	elseif (split[1] == "KINSTONES") then
		check_kinstone_split()
	else
		check_vaati(split[2])
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
	local file = io.open("MinishCapAutosplitterConfig\\MinishCapAutosplitterConfig_" .. category .. ".txt", 'r')
	local splitNum = 1
	local splitInfo = {}
	for line in file:lines() do
		if (string.sub(line,1,2) ~= "--") then
			splitInfo = splitString(line, ",")
			splits_table[splitNum] = splitInfo
			splitNum = splitNum + 1
		end
	end
	print("Using category: " .. category)
end

-- set up the livesplit connection
tcp_connection = init_livesplit()

-- set up the splits that the user has set up in AutosplitterConfig.txt
establish_splits()


while true do
	if (not done) then
		if (not started) then
			if (check_start()) then
				tcp_connection:send("starttimer\r\n")
				started = true
			end
		else
			check_current_split()
		end
	end
	
	emu.frameadvance()
end
