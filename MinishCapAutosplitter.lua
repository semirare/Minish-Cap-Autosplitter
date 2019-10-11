-- Minish Cap autosplitter for LiveSplit
-- Semirare, 2019 https://github.com/icemirrors18/Minish-Cap-Autosplitter
-- Requires LiveSplit 1.7+ See readme for setup information

--CHANGE THE BELOW LINE BASED ON WHAT CATEGORY YOU ARE RUNNING
--change to one of the following: "ANY", "FIREROD", "GLITCHLESS", "HUNDO"
--make sure you have your "MinishCapAutosplitterConfig_(category name).txt" file setup for your splits
category = "HUNDO"

current_split = 1
done = false
started = false

--used for hundo kinstone split
kinstoneCave = false
kinstoneField = false

local address_table = 
{
["EZLO"] = 0x002C9E,
["ENTERDWS"] = 0x002AA3,
["GUSTJAR"] = 0x002B36,
["ENTERCHU"] = 0x002D45,
["EARTHELEMENT"] = 0x002B42,
["CRENELPLANT"] = 0x002CC5,
["GRIPRING"] = 0x002B43,
["ENTERCOF"] = 0x002AA3,
["CANE"] = 0x002B36,
["FIREELEMENT"] = 0x002B42,
["BOOTS"] = 0x002B37,
["BOW"] = 0x002B34,
["ENTERFOW"] = 0x002AA3,
["MOLEMITTS"] = 0x002B36,
["OCARINA"] = 0x002B37,
["FLIPPERS"] = 0x002B43,
["BOOMERANG"] = 0x002B35,
["ENTERTOD"] = 0x002AA3,
["LANTERN"] = 0x002B35,
["WATERELEMENT"] = 0x002B42,
["ROYALVALLEY"] = 0x002D02,
["ENTERPOW"] = 0x002AA3,
["CAPE"] = 0x002B37,
["WINDELEMENT"] = 0x002B42,
["ENTERDHC"] = 0x002AA3,
["SPAWNNUTS"] = 0x002DC4,
["DHCKEY"] = 0x002DBC,
["SIMON"] = 0x002B43,
["CUCCOS"] = 0x002CA5,
["BOTTLES"] = 0x002B29,
["TINGLE"] = 0x002B41,
["FIGURINES"] = 0x002B41,
["MIRROR"] = 0x002B35,
["OCTOSUCKS"] = 0x002D97
}

local location_table =
{
["GLEEROK"] = {81, 0},
["MAZAAL"] = {88, 22},
["OCTO"] = {96,14},
["HOUSEOFWINDS"] = {8,0},
["GYORG"] = {113,0},
["DHCBOSSHALL"] = {141,0},
["DARKNUTS"] = {137,0},
["V1"] = {140,0},
["WARPCRENEL"] = {6,2},
["WARPHYLIA"] = {11,0},
["CLOUDTOPS"] = {8,1},
["LEAVECLOUDTOPS"] = {3,1}
}

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
local function compare_locations(goal)
	local player_loc = get_player_location()
	local goal_loc = location_table[goal]
	if (player_loc[1] == goal_loc[1] and player_loc[2] == goal_loc[2]) then
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
	read_byte = memory.readbyte(address)
	--convert to 8 bit binary
	read_byte = toBits(read_byte, 8)
	--check the correct bit in the binary
	if (read_byte[bit] == 1) then
		--flag for the current split is set, so split
		tcp_connection:send("split\r\n")
		current_split = current_split + 1
	end
end

--gets the player's current location to the location of each boss room
local function check_area_entry(goalName)
	if (goalName == "WINDRUINS") then
		--check for castor minish cave HP then location
	elseif (goalName == "LEAVECLOUDTOPS") then
		--check for light arrows then location
	else
		compare_locations(goalName)
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
		check_flag(address_table[split[2]], tonumber(split[4]))
	elseif (split[1] == "ENTERAREA") then
		check_area_entry(split[2])
	elseif (split[1] == "KINSTONES") then
		check_kinstone_split()
	else
		--vaati splits
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
			if (splitInfo[1] == "FLAG") then
				splitInfo[3] = address_table[splitInfo[2]]
			end
			splits_table[splitNum] = splitInfo
			splitNum = splitNum + 1
		end
	end
	print("Using category: " .. category)
	print("Using splits:")
	for k, v in pairs(splits_table) do
		print(k .. ": " .. v[2])
	end
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
