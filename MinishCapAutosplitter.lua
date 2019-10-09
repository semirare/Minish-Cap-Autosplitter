-- Minish Cap autosplitter for LiveSplit
-- Semirare, 2019 https://github.com/semirare
-- Requires LiveSplit 1.7+ See readme for setup information

current_split = 1
done = false
started = false

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
["BOOMERANG"] = 0x002B35,
["ENTERTOD"] = 0x002AA3,
["LANTERN"] = 0x002B35,
["WATERELEMENT"] = 0x002B42,
["ENTERPOW"] = 0x002AA3,
["CAPE"] = 0x002B37,
["WINDELEMENT"] = 0x002B42,
["ENTERDHC"] = 0x002AA3,
["DHCKEY"] = 0x002DBC
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
	return {memory.readbyte(0x0BF4), memory.readbyte(0x0BF5)}
end

--checks if the player's location matches the goal location and splits if it does
local function compare_locations(currentArea, currentRoom, goalArea, goalRoom)
	if (currentArea == goalArea and currentRoom == goalRoom) then
		tcp_connection:send("split\r\n")
		current_split = current_split + 1	
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
		current_split = current_split + 1
	end
end

--gets the player's current location to the location of each boss room
local function check_boss_entry(bossName)
	memory.usememorydomain("IWRAM")
	local current_location = get_player_location()
	memory.usememorydomain("EWRAM")
	if (bossName == "GLEEROK") then
		compare_locations(current_location[1], current_location[2], 81, 0)
	elseif (bossName == "MAZAAL") then
		compare_locations(current_location[1], current_location[2], 88, 22)
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
		--if we weren't started and game state becomes $02, game has been started
		started = true
		memory.usememorydomain("EWRAM")
		return true
	end
end

local function check_current_split()
	local split = splits_table[current_split]
	if (split[1] == "FLAG") then
		check_flag(address_table[split[2]], tonumber(split[4]))
	elseif (split[1] == "ENTERBOSS") then
		check_boss_entry(split[2])
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
	local file = io.open("MinishCapAutosplitterConfig.txt", 'r')
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
	print("Using splits:\n")
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