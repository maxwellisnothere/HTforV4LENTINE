-- DUKE HUB / Hunting Together RPG
local env = getgenv()
local HttpService = game:GetService("HttpService")
local BASE = "https://raw.githubusercontent.com/maxwellisnothere/HTforV4LENTINE/main/"

if game.GameId ~= 10769401924 and game.GameId ~= 10771222399 then
	error("DUKE HUB: this loader supports Hunting Together RPG only")
end
if env.__DukeHTLoading then return end
env.__DukeHTLoading = true

local ok, message = xpcall(function()
	local manifest = HttpService:JSONDecode(game:HttpGet(BASE .. "assets/manifest.json"))
	local write = rawget(env, "writefile")
	local mkdir = rawget(env, "makefolder")
	local isfolder = rawget(env, "isfolder")
	local isfile = rawget(env, "isfile")
	local read = rawget(env, "readfile")
	local crypt = rawget(env, "crypt")
	local decode = rawget(env, "base64decode") or (type(crypt) == "table" and (crypt.base64decode or crypt.base64_decode))
	local function decodeBase64(value)
		if type(decode) == "function" then return decode(value) end
		local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
		local result, buffer, bits = {}, 0, 0
		for index = 1, #value do
			local char = value:sub(index, index)
			if char == "=" then break end
			local offset = alphabet:find(char, 1, true)
			if offset then
				buffer = buffer * 64 + offset - 1
				bits += 6
				if bits >= 8 then
					bits -= 8
					local scale = 2 ^ bits
					table.insert(result, string.char(math.floor(buffer / scale) % 256))
					buffer %= scale
				end
			end
		end
		return table.concat(result)
	end
	-- Download the user's supplied artwork on a new machine; no absolute paths.
	if type(write) == "function" and type(mkdir) == "function" then
		if type(isfolder) ~= "function" or not isfolder("duke_hub_assets") then pcall(mkdir, "duke_hub_assets") end
		for name, entry in pairs(manifest.files) do
			assert(type(name) == "string" and name:match("^[%w_%-]+%.png$"), "Invalid asset filename")
			local path = "duke_hub_assets/" .. name
			local contents = decodeBase64(entry.base64)
			assert(#contents == entry.bytes, "Asset size mismatch: " .. name)
			local cached = false
			if type(isfile) == "function" and type(read) == "function" and isfile(path) then
				local readOk, previous = pcall(read, path)
				cached = readOk and previous == contents
			end
			if not cached then write(path, contents) end
		end
	else
		warn("DUKE HUB: file APIs unavailable; artwork may use text fallbacks")
	end

	local source = game:HttpGet(BASE .. "farm_control_center.luau")
	local chunk, compileError = loadstring(source, "DUKE HUB / HT")
	assert(chunk, compileError)
	chunk()
	assert(not env.__CodexFarmCenterError, env.__CodexFarmCenterError)
end, debug.traceback)

env.__DukeHTLoading = nil
if not ok then error("DUKE HUB failed to load: " .. tostring(message)) end
