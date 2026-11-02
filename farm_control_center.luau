-- Codex Farm Control Center for Hunting Together RPG
-- Uses the game's own remotes and server validation. No server-side gate bypasses.

local __codexOk, __codexError = xpcall(function()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = getgenv()
env.__CodexFarmCenterError = nil
local previousDirector = type(env.__CodexFarmCenter) == "table" and env.__CodexFarmCenter.manager or nil

if type(env.__CodexFarmCenter) == "table" and type(env.__CodexFarmCenter.Destroy) == "function" then
	pcall(env.__CodexFarmCenter.Destroy)
end

local runtime = {alive = true, connections = {}, version = "3.1.0-travel"}
env.__CodexFarmCenter = runtime

local function track(connection)
	table.insert(runtime.connections, connection)
	return connection
end

local function findModule(name)
	local object = ReplicatedStorage:FindFirstChild(name, true)
	if object and object:IsA("ModuleScript") then
		local ok, value = pcall(require, object)
		if ok then return value end
	end
	return nil
end

local QuestData = findModule("QuestData") or {}
local GearUtil = findModule("GearUtil")
local RewardData = findModule("RewardData") or {}
local AchievementData = findModule("AchievementData") or {}
local ItemData = findModule("ItemData") or {}
local GameConfig = findModule("GameConfig") or {}
local MonsterData = findModule("MonsterData") or {}
local MapData = findModule("MapData") or {}
local DungeonData = findModule("DungeonData") or {}
local ExpTable = findModule("ExpTable") or {}
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")

local function remote(name)
	return Remotes and Remotes:FindFirstChild(name)
end

local function decodeAttribute(name)
	local raw = player:GetAttribute(name)
	if type(raw) ~= "string" or raw == "" then return {} end
	local ok, value = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and type(value) == "table" and value or {}
end

local function comma(value)
	local n = tonumber(value) or 0
	if n ~= n or n == math.huge or n == -math.huge then return tostring(n) end
	local s = tostring(math.floor(n))
	local sign, body = s:match("^([%-]?)(%d+)$")
	body = body or s
	local changed
	repeat
		body, changed = body:gsub("^(%d+)(%d%d%d)", "%1,%2")
	until changed == 0
	return (sign or "") .. body
end

local function serverNow()
	local ok, value = pcall(workspace.GetServerTimeNow, workspace)
	return ok and value or os.time()
end

local function new(className, properties, parent)
	local object = Instance.new(className)
	if object:IsA("GuiObject") or object:IsA("LayerCollector") then
		object.AutoLocalize = false
		for _, attribute in ipairs({"LumiKeepText", "LumiKeepFont", "LumiKeepColor", "LumiNoTranslate", "LumiSkipIcon", "LumiNoPixelFont"}) do
			object:SetAttribute(attribute, true)
		end
	end
	for key, value in pairs(properties or {}) do
		object[key] = value
	end
	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		object.TextSize = math.max(12, object.TextSize)
	end
	object.Parent = parent
	return object
end

-- Local artwork supplied with this control center. Executors normally expose
-- getcustomasset/getsynasset; every image has a text fallback if unavailable.
local customAssetLoader = rawget(env, "getcustomasset") or rawget(env, "getsynasset")
local ASSET_ROOT = [[C:\mygame\ทายคำ]]
local function localAsset(executorPath, sourceRelativePath)
	if type(customAssetLoader) ~= "function" then return "" end
	local ok, asset = pcall(customAssetLoader, executorPath)
	if (not ok or type(asset) ~= "string") and sourceRelativePath then
		ok, asset = pcall(customAssetLoader, ASSET_ROOT .. "\\" .. sourceRelativePath)
	end
	return ok and type(asset) == "string" and asset or ""
end

local ASSETS = {
	Brand = localAsset([[duke_hub_assets/brand.png]], [[Glassmorphism (5)-Photoroom.png]]),
	Overview = localAsset([[duke_hub_assets/overview.png]], [[ีicon\Icon set 1\0.5x\House 256 px.png]]),
	Rewards = localAsset([[duke_hub_assets/rewards.png]], [[ีicon\Icon set 1\0.5x\Gift 256 px.png]]),
	Farm = localAsset([[duke_hub_assets/farm.png]], [[ีicon\Icon set 1\0.5x\Gamepad 1 256 px.png]]),
	Boss = localAsset([[duke_hub_assets/boss.png]], [[ีicon\Icon set 1\0.5x\Alarm 256 px.png]]),
	Dungeon = localAsset([[duke_hub_assets/dungeon.png]], [[ีicon\Icon set 1\0.5x\Map 256 px.png]]),
	Gear = localAsset([[duke_hub_assets/gear.png]], [[ีicon\Icon set 1\0.5x\Setting 1 256 px.png]]),
	Close = localAsset([[duke_hub_assets/close.png]], [[ีicon\Icon set 1\0.5x\Cross 256 px.png]]),
	Collapse = localAsset([[duke_hub_assets/collapse.png]], [[ีicon\Icon set 1\0.5x\Negative  256 px.png]]),
}

local COLORS = {
	Bg = Color3.fromRGB(7, 12, 10),
	Panel = Color3.fromRGB(8, 12, 11),
	Card = Color3.fromRGB(14, 20, 17),
	Card2 = Color3.fromRGB(24, 31, 27),
	Line = Color3.fromRGB(67, 83, 73),
	Text = Color3.fromRGB(244, 247, 245),
	Sub = Color3.fromRGB(167, 176, 170),
	Cyan = Color3.fromRGB(154, 238, 94),
	Blue = Color3.fromRGB(78, 133, 255),
	Green = Color3.fromRGB(103, 223, 91),
	Orange = Color3.fromRGB(255, 178, 72),
	Red = Color3.fromRGB(255, 97, 117),
	Purple = Color3.fromRGB(170, 113, 255),
}

local function corner(parent, radius)
	return new("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, parent)
end

local function stroke(parent, color, transparency, thickness)
	return new("UIStroke", {
		Color = color or COLORS.Line,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local oldGui = playerGui:FindFirstChild("CodexFarmControlCenter")
if oldGui then oldGui:Destroy() end
local obsoleteWarpGui = playerGui:FindFirstChild("CodexStageWarpUI")
if obsoleteWarpGui then obsoleteWarpGui:Destroy() end
pcall(function()
	local hidden = gethui()
	local hiddenWarpGui = hidden and hidden:FindFirstChild("CodexStageWarpUI")
	if hiddenWarpGui then hiddenWarpGui:Destroy() end
end)

local gui = new("ScreenGui", {
	Name = "CodexFarmControlCenter",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 72,
}, playerGui)

local shadow = new("Frame", {
	Name = "Shadow",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(774, 494),
	BackgroundColor3 = Color3.new(),
	BackgroundTransparency = 0.48,
	BorderSizePixel = 0,
}, gui)
corner(shadow, 12)
local shadowScale = new("UIScale", {Scale = 1}, shadow)

local main = new("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 480),
	BackgroundColor3 = COLORS.Bg,
	BackgroundTransparency = 0.16,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
corner(main, 11)
stroke(main, COLORS.Cyan, 0.42, 1.2)
local windowScale = new("UIScale", {Scale = 1}, main)
local function clampWindowPosition(position)
	local canvas = gui.AbsoluteSize
	if canvas.X <= 0 or canvas.Y <= 0 then return position end
	local halfWidth, halfHeight = 760 * windowScale.Scale / 2, 480 * windowScale.Scale / 2
	local x = position.X.Scale * canvas.X + position.X.Offset
	local y = position.Y.Scale * canvas.Y + position.Y.Offset
	return UDim2.fromOffset(
		math.clamp(x, halfWidth + 8, math.max(halfWidth + 8, canvas.X - halfWidth - 8)),
		math.clamp(y, halfHeight + 8, math.max(halfHeight + 8, canvas.Y - halfHeight - 8))
	)
end
local function fitWindow()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local scale = math.min(1, (viewport.X - 32) / 774, (viewport.Y - 70) / 494)
	windowScale.Scale = scale
	shadowScale.Scale = scale
	main.Position = clampWindowPosition(main.Position)
	shadow.Position = main.Position
end
fitWindow()
if workspace.CurrentCamera then
	track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow))
end
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(7, 10, 9)),
		ColorSequenceKeypoint.new(0.58, Color3.fromRGB(10, 18, 13)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(13, 24, 16)),
	}),
	Rotation = 18,
}, main)

local header = new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Active = true,
}, main)
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 10, 9)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(11, 16, 13)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(17, 27, 20)),
	}),
	Rotation = 0,
}, header)
new("Frame", {
	Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = COLORS.Line, BackgroundTransparency = 0.58, BorderSizePixel = 0,
}, header)

local logo = new("ImageLabel", {
	Position = UDim2.fromOffset(12, 6),
	Size = UDim2.fromOffset(106, 36),
	BackgroundTransparency = 1,
	Image = ASSETS.Brand,
	-- Custom textures are capped internally; these coordinates crop the visible
	-- logo band after the 1800px source is normalized to a 1024px texture.
	ImageRectOffset = Vector2.new(0, 390),
	ImageRectSize = Vector2.new(1024, 240),
	ScaleType = Enum.ScaleType.Fit,
}, header)
new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	Text = ASSETS.Brand == "" and "DUKE HUB" or "", TextColor3 = Color3.new(1, 1, 1), TextSize = 14,
	Font = Enum.Font.GothamBlack,
}, logo)

new("TextLabel", {
	Position = UDim2.fromOffset(126, 5), Size = UDim2.fromOffset(230, 20),
	BackgroundTransparency = 1, Text = "FARM CONTROL CENTER",
	TextColor3 = COLORS.Text, TextSize = 14, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)
local headerSub = new("TextLabel", {
	Position = UDim2.fromOffset(126, 24), Size = UDim2.fromOffset(250, 16),
	BackgroundTransparency = 1, Text = "ระบบฟาร์มแบบปลอดภัย • ใช้ระบบทางการของเกม",
	TextColor3 = COLORS.Sub, TextSize = 9, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

headerSub.Text = "Hunting Together RPG  •  Safe automation"

local headerStatus = new("TextLabel", {
	Position = UDim2.new(1, -292, 0, 9), Size = UDim2.fromOffset(198, 29),
	BackgroundColor3 = Color3.fromRGB(19, 24, 21), BackgroundTransparency = 0.12,
	BorderSizePixel = 0, Text = "● CONNECTED  •  Lv.--  •  0 Silver",
	TextColor3 = COLORS.Sub, TextSize = 9, Font = Enum.Font.GothamBold,
}, header)
corner(headerStatus, 7)
stroke(headerStatus, COLORS.Line, 0.45, 1)

local function headerButton(text, x, imageAsset)
	imageAsset = type(imageAsset) == "string" and imageAsset or ""
	local b = new("TextButton", {
		Position = UDim2.new(1, x, 0, 9), Size = UDim2.fromOffset(29, 29),
		BackgroundColor3 = COLORS.Card2, BackgroundTransparency = 0.24, BorderSizePixel = 0,
		Text = imageAsset == "" and text or "", TextColor3 = COLORS.Sub, TextSize = 14,
		Font = Enum.Font.GothamBold, AutoButtonColor = false,
	}, header)
	corner(b, 7)
	if imageAsset ~= "" then
		new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1,
			Image = imageAsset, ImageColor3 = COLORS.Sub, ScaleType = Enum.ScaleType.Fit,
		}, b)
	end
	return b
end
local minimizeButton = headerButton("—", -78, ASSETS.Collapse)
local closeButton = headerButton("×", -40, ASSETS.Close)

if ASSETS.Collapse == "" then minimizeButton.Text = "—" end
if ASSETS.Close == "" then closeButton.Text = "×" end

local sidebar = new("Frame", {
	Name = "Sidebar",
	Position = UDim2.fromOffset(0, 48), Size = UDim2.new(0, 180, 1, -48),
	BackgroundColor3 = Color3.fromRGB(8, 13, 11), BackgroundTransparency = 0.08, BorderSizePixel = 0,
}, main)
new("Frame", {Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = COLORS.Line, BackgroundTransparency = 0.42, BorderSizePixel = 0}, sidebar)

local profile = new("Frame", {
	Name = "Profile",
	Position = UDim2.new(0, 8, 1, -72), Size = UDim2.new(1, -16, 0, 58),
	BackgroundColor3 = COLORS.Card, BackgroundTransparency = 0.14, BorderSizePixel = 0,
}, sidebar)
corner(profile, 8)
stroke(profile, COLORS.Line, 0.6, 1)
local profileLevel = new("TextLabel", {
	Position = UDim2.fromOffset(11, 7), Size = UDim2.new(1, -22, 0, 22),
	BackgroundTransparency = 1, Text = "Lv. --", TextColor3 = COLORS.Text,
	TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, profile)
local profileInfo = new("TextLabel", {
	Position = UDim2.fromOffset(11, 30), Size = UDim2.new(1, -22, 0, 19),
	BackgroundTransparency = 1, Text = "กำลังโหลด...", TextColor3 = COLORS.Sub,
	TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
}, profile)

local navHolder = new("Frame", {
	Name = "Navigation",
	Position = UDim2.fromOffset(7, 18), Size = UDim2.new(1, -14, 0, 288),
	BackgroundTransparency = 1,
}, sidebar)
local navLayout = new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, navHolder)

local hint = new("TextLabel", {
	Position = UDim2.new(0, 12, 1, -106), Size = UDim2.new(1, -24, 0, 26),
	BackgroundTransparency = 1,
	Text = "RightControl\nซ่อน / แสดงหน้าต่าง",
	TextColor3 = Color3.fromRGB(104, 117, 144), TextSize = 10,
	Font = Enum.Font.Gotham, TextWrapped = true,
}, sidebar)
hint.Text = "RightControl\nซ่อน / แสดงหน้าต่าง"

local content = new("Frame", {
	Name = "Content",
	Position = UDim2.fromOffset(180, 48), Size = UDim2.new(1, -180, 1, -48),
	BackgroundTransparency = 1,
}, main)

local pageTitle = new("TextLabel", {
	Name = "PageTitle",
	Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -32, 0, 27),
	BackgroundTransparency = 1, Text = "OVERVIEW", TextColor3 = COLORS.Text,
	TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local pages = {}
local navButtons = {}
local currentPage = "overview"
local PAGE_TITLES = {
	play = "SMART FARM  /  เริ่มที่นี่",
	travel = "TRAVEL  /  เลือกด่านและกลับจุดเดิม",
	overview = "OVERVIEW  /  ภาพรวม",
	rewards = "REWARDS & CODES  /  รางวัล",
	farm = "FARM & QUESTS  /  ฟาร์ม",
	boss = "BOSS RADAR  /  บอส",
	dungeon = "DUNGEONS  /  ดันเจี้ยน",
	gear = "EQUIPMENT  /  อุปกรณ์",
}

local function makePage(id)
	local page = new("ScrollingFrame", {
		Name = id, Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 1, -50),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = COLORS.Cyan,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, content)
	new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, page)
	new("UIPadding", {PaddingBottom = UDim.new(0, 8)}, page)
	pages[id] = page
	return page
end

local function selectPage(id)
	currentPage = id
	pageTitle.Text = PAGE_TITLES[id] or string.upper(id)
	for name, page in pairs(pages) do page.Visible = name == id end
	for name, button in pairs(navButtons) do
		local selected = name == id
		button.BackgroundColor3 = selected and Color3.fromRGB(25, 34, 29) or Color3.fromRGB(10, 15, 13)
		button.BackgroundTransparency = selected and 0.04 or 0.34
		button.TextColor3 = selected and COLORS.Text or COLORS.Sub
		local label = button:FindFirstChild("Label")
		if label then label.TextColor3 = selected and COLORS.Text or COLORS.Sub end
		local marker = button:FindFirstChild("Marker")
		if marker then marker.Visible = selected end
		local icon = button:FindFirstChild("Icon")
		if icon then icon.ImageColor3 = selected and COLORS.Cyan or COLORS.Sub end
		local navStroke = button:FindFirstChild("NavStroke")
		if navStroke then navStroke.Transparency = selected and 0.45 or 1 end
	end
end

local function makeNav(id, text, order, iconAsset)
	local button = new("TextButton", {
		Name = id, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(10, 15, 13),
		BackgroundTransparency = 0.34, BorderSizePixel = 0, Text = "", TextColor3 = COLORS.Sub,
		TextSize = 14, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false, LayoutOrder = order,
	}, navHolder)
	corner(button, 8)
	local navStroke = stroke(button, COLORS.Line, 1, 1)
	navStroke.Name = "NavStroke"
	local marker = new("Frame", {
		Name = "Marker", Position = UDim2.fromOffset(0, 8), Size = UDim2.fromOffset(3, 22),
		BackgroundColor3 = COLORS.Cyan, BorderSizePixel = 0, Visible = false,
	}, button)
	corner(marker, 3)
	new("ImageLabel", {
		Name = "Icon", Position = UDim2.fromOffset(11, 10), Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1, Image = iconAsset or "", ImageColor3 = COLORS.Sub,
		ScaleType = Enum.ScaleType.Fit,
	}, button)
	new("TextLabel", {
		Name = "Label", Position = UDim2.fromOffset(39, 0), Size = UDim2.new(1, -65, 1, 0),
		BackgroundTransparency = 1, Text = text, TextColor3 = COLORS.Sub,
		TextSize = 14, Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
	}, button)
	new("TextLabel", {
		Position = UDim2.new(1, -22, 0, 0), Size = UDim2.fromOffset(18, 38),
		BackgroundTransparency = 1, Text = "›", TextColor3 = Color3.fromRGB(119, 130, 123),
		TextSize = 18, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Center,
	}, button)
	navButtons[id] = button
	track(button.MouseButton1Click:Connect(function() selectPage(id) end))
end

local function makeCard(parent, height, color)
	local frame = new("Frame", {
		Size = UDim2.new(1, -5, 0, height), BackgroundColor3 = COLORS.Card,
		BackgroundTransparency = 0.32, BorderSizePixel = 0,
	}, parent)
	corner(frame, 8)
	stroke(frame, COLORS.Line, 0.68, 1)
	frame.LayoutOrder = #parent:GetChildren()
	return frame
end

local function titleLabel(parent, title, subtitle)
	new("TextLabel", {
		Position = UDim2.fromOffset(15, 11), Size = UDim2.new(1, -30, 0, 23),
		BackgroundTransparency = 1, Text = title, TextColor3 = COLORS.Text,
		TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	if subtitle then
		new("TextLabel", {
			Position = UDim2.fromOffset(15, 35), Size = UDim2.new(1, -30, 0, 34),
			BackgroundTransparency = 1, Text = subtitle, TextColor3 = COLORS.Sub,
		TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
		}, parent)
	end
end

local refreshers = {}
local function makeToggle(parent, title, subtitle, color, getter, setter)
	local frame = makeCard(parent, 72)
	new("TextLabel", {
		Position = UDim2.fromOffset(15, 10), Size = UDim2.new(1, -100, 0, 22),
		BackgroundTransparency = 1, Text = title, TextColor3 = COLORS.Text,
		TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
	new("TextLabel", {
		Position = UDim2.fromOffset(15, 34), Size = UDim2.new(1, -105, 0, 29),
		BackgroundTransparency = 1, Text = subtitle, TextColor3 = COLORS.Sub,
		TextSize = 10, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
	}, frame)
	local toggle = new("TextButton", {
		Position = UDim2.new(1, -68, 0.5, -14), Size = UDim2.fromOffset(52, 28),
		BackgroundColor3 = Color3.fromRGB(31, 38, 34), BorderSizePixel = 0,
		Text = "OFF", TextColor3 = COLORS.Sub, TextSize = 11,
		Font = Enum.Font.GothamBold, AutoButtonColor = false,
	}, frame)
	corner(toggle, 14)
	stroke(toggle, COLORS.Line, 0.62, 1)
	local function refresh()
		local ok, enabled = pcall(getter)
		enabled = ok and enabled == true
		toggle.Text = enabled and "ON" or "OFF"
		toggle.BackgroundColor3 = enabled and color or Color3.fromRGB(31, 38, 34)
		toggle.TextColor3 = enabled and Color3.new(1, 1, 1) or COLORS.Sub
	end
	table.insert(refreshers, refresh)
	track(toggle.MouseButton1Click:Connect(function()
		local ok, value = pcall(getter)
		pcall(setter, not (ok and value == true))
		task.delay(0.3, refresh)
	end))
	refresh()
	return frame, refresh
end

local toastToken = 0
local toastLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 77, 1, -12),
	Size = UDim2.fromOffset(390, 38), BackgroundColor3 = Color3.fromRGB(36, 46, 65),
	BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
	TextColor3 = COLORS.Text, TextTransparency = 1, TextSize = 12,
	Font = Enum.Font.GothamBold, Visible = true, ZIndex = 30,
}, main)
corner(toastLabel, 10)

local function toast(message, tone)
	toastToken += 1
	local token = toastToken
	toastLabel.Text = tostring(message)
	toastLabel.BackgroundColor3 = tone == "bad" and Color3.fromRGB(103, 43, 55)
		or tone == "good" and Color3.fromRGB(33, 91, 72)
		or Color3.fromRGB(36, 57, 78)
	TweenService:Create(toastLabel, TweenInfo.new(0.18), {BackgroundTransparency = 0.05, TextTransparency = 0}):Play()
	task.delay(3.1, function()
		if runtime.alive and token == toastToken then
			TweenService:Create(toastLabel, TweenInfo.new(0.25), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
		end
	end)
end

local state = {
	autoClaim = false,
	autoRepeat = true,
	autoQuestPlan = false,
	autoRewards = false,
	autoCodes = false,
	autoSellJunk = false,
	junkThreshold = 25,
	autoDungeon = false,
	bossAlerts = true,
	rushAssist = false,
	refineReserve = 5000,
	latestDungeon = nil,
	dungeonStatus = "ยังไม่มีคำเชิญเข้าดันเจี้ยน",
	rewardStatus = "กำลังตรวจรางวัลฟรี...",
	codeResults = {},
	lastCode = nil,
	rewardAttempts = {},
	codeBusy = false,
	codesProcessed = false,
	lastJunkSell = 0,
	lastQuestPlan = 0,
}

local director = {
	enabled = false, huntBosses = true, runDungeons = true,
	equipBest = true, travel = {active = false, token = 0, status = "เลือกด่านที่ต้องการ", bookmark = previousDirector and previousDirector.travel and previousDirector.travel.bookmark},
	phase = "หยุดอยู่", detail = "กดเริ่ม ระบบจะเลือกเป้าหมายและเส้นทางให้",
	plan = nil, cooldowns = {}, blockedZones = {}, kills = 0,
	startedAt = 0, startExp = 0, startSilver = 0,
	ui = {}, navToken = 0,
	failedBossSpawns = previousDirector and table.clone(previousDirector.failedBossSpawns or {}) or {},
	bossSpawnKeys = previousDirector and table.clone(previousDirector.bossSpawnKeys or {}) or {},
}
runtime.manager = director

local function menuFire(name, value)
	local event = player:FindFirstChild("LumiMenuToggle")
	if event and event:IsA("BindableEvent") then event:Fire(name, value); return true end
	return false
end

local function setAutoFarm(enabled)
	if (player:GetAttribute("AutoOn") == true) ~= enabled then
		if not menuFire("autoToggle") then toast("ไม่พบปุ่ม Auto ของเกม", "bad") end
	end
end

local function setRemoteBoolean(name, enabled)
	local object = remote(name)
	if object and object:IsA("RemoteEvent") then object:FireServer(enabled) end
end

local function setBalanced(enabled)
	if enabled then
		local apply = remote("ApplyBuild")
		if apply then apply:FireServer("balance", true) end
	else
		local set = remote("SetAutoBuild")
		if set then set:FireServer("manual") end
	end
end

-- Pages
local overviewPage = makePage("overview")
local playPage = makePage("play")
local travelPage = makePage("travel")
local rewardsPage = makePage("rewards")
local farmPage = makePage("farm")
local bossPage = makePage("boss")
local dungeonPage = makePage("dungeon")
local gearPage = makePage("gear")

makeNav("play", "เริ่มฟาร์ม", 1, ASSETS.Overview)
makeNav("rewards", "รางวัล / โค้ด", 2, ASSETS.Rewards)
makeNav("farm", "ฟาร์ม / เควสต์", 3, ASSETS.Farm)
makeNav("boss", "บอส 10 นาที", 4, ASSETS.Boss)
makeNav("dungeon", "ดันเจี้ยน", 5, ASSETS.Dungeon)
makeNav("gear", "อุปกรณ์", 6, ASSETS.Gear)
makeNav("travel", "วาร์ป / กลับ", 7, ASSETS.Dungeon)

do
	local hero = makeCard(playPage, 146)
	hero.Name = "Control"
	director.ui.title = new("TextLabel", {
		Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 28),
		BackgroundTransparency = 1, Text = "พร้อมเริ่มฟาร์ม", TextSize = 20,
		TextColor3 = COLORS.Text, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
	}, hero)
	director.ui.detail = new("TextLabel", {
		Position = UDim2.fromOffset(14, 43), Size = UDim2.new(1, -28, 0, 44),
		BackgroundTransparency = 1, Text = director.detail, TextSize = 14,
		TextColor3 = COLORS.Sub, Font = Enum.Font.Gotham, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	}, hero)
	director.ui.start = new("TextButton", {
		Name = "StartStop", Position = UDim2.fromOffset(14, 98), Size = UDim2.new(0.64, -20, 0, 36),
		BackgroundColor3 = COLORS.Green, BorderSizePixel = 0, Text = "เริ่มฟาร์มอัตโนมัติ",
		TextSize = 15, TextColor3 = COLORS.Bg, Font = Enum.Font.GothamBold, AutoButtonColor = false,
	}, hero)
	corner(director.ui.start, 7)
	local rescan = new("TextButton", {
		Name = "Rescan", Position = UDim2.new(0.64, 2, 0, 98), Size = UDim2.new(0.36, -16, 0, 36),
		BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0, Text = "หาเป้าหมายใหม่",
		TextSize = 13, TextColor3 = COLORS.Text, Font = Enum.Font.GothamMedium,
	}, hero)
	corner(rescan, 7)
	track(director.ui.start.MouseButton1Click:Connect(function() director:SetEnabled(not director.enabled) end))
	track(rescan.MouseButton1Click:Connect(function()
		director.plan = nil
		director.blockedZones = {}
		director.cooldowns = {}
		director.navToken += 1
		if not director.enabled then director:Preview() end
	end))
	local function option(title, key)
		local row = makeCard(playPage, 40)
		row.Name = key .. "Row"
		new("TextLabel", {
			Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -100, 1, 0),
			BackgroundTransparency = 1, Text = title, TextSize = 14, TextColor3 = COLORS.Text,
			Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local button = new("TextButton", {
			Name = key, Position = UDim2.new(1, -70, 0, 6), Size = UDim2.fromOffset(56, 28),
			BorderSizePixel = 0, Text = "ON", TextSize = 12, Font = Enum.Font.GothamBold,
			TextColor3 = COLORS.Bg, BackgroundColor3 = COLORS.Green,
		}, row)
		corner(button, 14)
		local function refresh()
			button.Text = director[key] and "ON" or "OFF"
			button.BackgroundColor3 = director[key] and COLORS.Green or COLORS.Card2
			button.TextColor3 = director[key] and COLORS.Bg or COLORS.Sub
		end
		track(button.MouseButton1Click:Connect(function() director[key] = not director[key]; refresh() end))
		refresh()
	end
	option("แวะล่าบอสเมื่อเกิด แล้วกลับมาฟาร์ม", "huntBosses")
	option("ลงดันเมื่อเลเวลผ่านและมีรอบฟรี", "runDungeons")
	option("ใส่อุปกรณ์ที่ CP สูงสุดอัตโนมัติ", "equipBest")
	local info = makeCard(playPage, 112)
	info.Name = "Telemetry"
	director.ui.stats = new("TextLabel", {
		Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24),
		BackgroundTransparency = 1, Text = "กำลังตรวจข้อมูล...", TextSize = 13,
		TextColor3 = COLORS.Cyan, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
	}, info)
	director.ui.note = new("TextLabel", {
		Position = UDim2.fromOffset(14, 37), Size = UDim2.new(1, -28, 0, 66),
		BackgroundTransparency = 1, Text = "", TextSize = 12, TextWrapped = true,
		TextColor3 = COLORS.Sub, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	}, info)
end

do
	local intro = makeCard(travelPage, 110)
	intro.Name = "TravelControl"
		titleLabel(intro, "เลือกด่าน แล้วกลับมาจุดเดิมได้", "เมืองวาร์ปฟรี • เสาบอสเสีย Silver ตามเกม • จุดอื่นเดินให้ • หยุดฟาร์มก่อนเดินทาง")
	local back = new("TextButton", {
		Name = "Return", Position = UDim2.fromOffset(14, 72), Size = UDim2.new(0.5, -20, 0, 28),
		Text = "กลับจุดก่อนเดินทาง", TextSize = 13, Font = Enum.Font.GothamBold,
		TextColor3 = COLORS.Bg, BackgroundColor3 = COLORS.Green, BorderSizePixel = 0,
	}, intro)
	corner(back, 7)
	director.travel.backButton = back
	local cancel = new("TextButton", {
		Name = "Cancel", Position = UDim2.new(0.5, 4, 0, 72), Size = UDim2.new(0.5, -20, 0, 28),
		Text = "ยกเลิกเดินทาง", TextSize = 13, Font = Enum.Font.GothamBold,
		TextColor3 = COLORS.Sub, BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0,
	}, intro)
	corner(cancel, 7)
	track(back.MouseButton1Click:Connect(function() director:ReturnTrip() end))
	track(cancel.MouseButton1Click:Connect(function() director:CancelTrip() end))
	director.travel.label = new("TextLabel", {
		Name = "TravelStatus", Size = UDim2.new(1, -6, 0, 42), BackgroundTransparency = 1,
		Text = director.travel.status, TextColor3 = COLORS.Cyan, TextSize = 13,
		Font = Enum.Font.GothamMedium, TextWrapped = true, LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, travelPage)
	director.travel.rows = {}
	local destinations = {{id = "Town", name = "เมือง / NPC ทั้งหมด", order = 0}}
	for id, data in pairs(MapData) do
		if type(data) == "table" and data.Order then
			table.insert(destinations, {id = id, name = data.DisplayName or id, order = data.Order})
		end
	end
	table.sort(destinations, function(a, b) return a.order < b.order end)
	for index, destination in ipairs(destinations) do
		local row = makeCard(travelPage, 58)
		row.Name, row.LayoutOrder = destination.id, index + 10
		new("TextLabel", {
			Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -110, 0, 23),
			Text = destination.name, TextColor3 = COLORS.Text, TextSize = 14,
			Font = Enum.Font.GothamBold, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local reason = new("TextLabel", {
			Position = UDim2.fromOffset(12, 31), Size = UDim2.new(1, -110, 0, 20),
			Text = "กำลังตรวจ...", TextColor3 = COLORS.Sub, TextSize = 12,
			Font = Enum.Font.Gotham, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
		local go = new("TextButton", {
			Name = "Go", Position = UDim2.new(1, -92, 0, 14), Size = UDim2.fromOffset(80, 30),
			Text = "เดินทาง", TextSize = 13, TextColor3 = COLORS.Text, Font = Enum.Font.GothamBold,
			BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0,
		}, row)
		corner(go, 7)
		director.travel.rows[destination.id] = {button = go, reason = reason}
		track(go.MouseButton1Click:Connect(function() director:TravelTo(destination.id) end))
	end
end

local summaryCard = makeCard(overviewPage, 112, Color3.fromRGB(25, 39, 57))
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(200, 230, 207), Color3.fromRGB(160, 194, 167)), Rotation = 14}, summaryCard)
local summaryTitle = new("TextLabel", {
	Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -32, 0, 25),
	BackgroundTransparency = 1, Text = "กำลังอ่านสถานะตัวละคร...", TextColor3 = COLORS.Text,
	TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, summaryCard)
local summaryStats = new("TextLabel", {
	Position = UDim2.fromOffset(16, 45), Size = UDim2.new(1, -32, 0, 22),
	BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.Cyan,
	TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, summaryCard)
local summaryMode = new("TextLabel", {
	Position = UDim2.fromOffset(16, 75), Size = UDim2.new(1, -32, 0, 20),
	BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.Sub,
	TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
}, summaryCard)

local insightCard = makeCard(overviewPage, 104)
titleLabel(insightCard, "สูตรฟาร์ม EXP ที่เร็วกว่า", "มอนสเตอร์สูงกว่าหรือต่ำกว่าเราไม่เกิน 0–2 เลเวลให้ EXP เต็ม • ต่าง 4 เลเวลเหลือ 75% • ต่าง 6 เลเวลเหลือ 50% • ห่างมากเหลือ 25%")
local insightPill = new("TextLabel", {
	Position = UDim2.new(1, -151, 0, 69), Size = UDim2.fromOffset(136, 24),
	BackgroundColor3 = Color3.fromRGB(39, 81, 76), BorderSizePixel = 0,
	Text = "เป้าหมาย: ใกล้เลเวลเรา", TextColor3 = COLORS.Green,
	TextSize = 10, Font = Enum.Font.GothamBold,
}, insightCard)
corner(insightPill, 12)

local rushCard = makeCard(overviewPage, 88)
titleLabel(rushCard, "MONSTER RUSH • โบนัสรางวัล 1.5×", "สะสมคอมโบ 100 เพื่อเปิด Rush; ระบบจะสุ่มมาเป็นช่วง ๆ และเสริมมอนสเตอร์รอบตัว")
local rushStatus = new("TextLabel", {
	Position = UDim2.new(1, -146, 0, 12), Size = UDim2.fromOffset(130, 24),
	BackgroundColor3 = Color3.fromRGB(47, 55, 76), BorderSizePixel = 0,
	Text = "รอ Rush", TextColor3 = COLORS.Sub, TextSize = 10, Font = Enum.Font.GothamBold,
}, rushCard)
corner(rushStatus, 12)

makeToggle(overviewPage, "ฟาร์มอัตโนมัติ", "เดินโจมตี เก็บของ และใช้การตั้งค่าฟาร์มเดิมของเกม", COLORS.Green,
	function() return player:GetAttribute("AutoOn") == true end, setAutoFarm)
makeToggle(overviewPage, "เคลมเควสต์อัตโนมัติ", "เคลมเฉพาะเควสต์ที่เสร็จจริง เซิร์ฟเวอร์ตรวจซ้ำทุกครั้ง", COLORS.Blue,
	function() return state.autoClaim end, function(v) state.autoClaim = v end)

local boxInfo = makeCard(overviewPage, 68)
titleLabel(boxInfo, "Auto Open Box", "อ่านจากการตั้งค่าเกม • กล่องที่เกมอนุญาตจะถูกเปิดระหว่างฟาร์ม")
local boxStatus = new("TextLabel", {
	Position = UDim2.new(1, -80, 0, 21), Size = UDim2.fromOffset(64, 26), BackgroundColor3 = COLORS.Card2,
	BorderSizePixel = 0, Text = "--", TextColor3 = COLORS.Sub, TextSize = 11, Font = Enum.Font.GothamBold,
}, boxInfo)
corner(boxStatus, 13)

local rewardIntro = makeCard(rewardsPage, 104, Color3.fromRGB(29, 42, 59))
titleLabel(rewardIntro, "FREE REWARD MANAGER", "รับ Daily Login, Online Reward, 8-Day, Monthly วันนี้, Mail, Achievement และ Battle Pass ที่พร้อมแล้ว • ไม่ใช้ Robux และไม่ใช้ Make-up")
local rewardStatusLabel = new("TextLabel", {
	Position = UDim2.fromOffset(15, 76), Size = UDim2.new(1, -30, 0, 18),
	BackgroundTransparency = 1, Text = state.rewardStatus, TextColor3 = COLORS.Cyan,
	TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, rewardIntro)

makeToggle(rewardsPage, "รับรางวัลฟรีอัตโนมัติ", "ตรวจทุก 15 วินาทีและเคลมเฉพาะสิทธิ์ที่พร้อมจริงจากเซิร์ฟเวอร์", COLORS.Green,
	function() return state.autoRewards end, function(v) state.autoRewards = v end)
makeToggle(rewardsPage, "ลองโค้ดทางการอัตโนมัติ", "ลองครั้งเดียวต่อการเปิด UI เฉพาะโค้ดที่ผู้พัฒนาเผยแพร่ ไม่สุ่มโค้ด", COLORS.Purple,
	function() return state.autoCodes end, function(v) state.autoCodes = v end)

local codeCard = makeCard(rewardsPage, 174)
titleLabel(codeCard, "โค้ดรางวัล", "รายการยืนยันจากคำอธิบายเกม: HALLOWEEN และ BETATESTER • โค้ดหมดอายุหรือเคยใช้แล้วจะไม่เสียอะไร")
local codeStatus = new("TextLabel", {
	Position = UDim2.fromOffset(15, 70), Size = UDim2.new(1, -30, 0, 22),
	BackgroundTransparency = 1, Text = "ยังไม่ได้ลองโค้ด", TextColor3 = COLORS.Sub,
	TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, codeCard)
local redeemVerifiedButton = new("TextButton", {
	Position = UDim2.fromOffset(15, 98), Size = UDim2.fromOffset(154, 32),
	BackgroundColor3 = Color3.fromRGB(76, 55, 122), BorderSizePixel = 0,
	Text = "ลองโค้ดทางการ", TextColor3 = COLORS.Text, TextSize = 10,
	Font = Enum.Font.GothamBold, AutoButtonColor = false,
}, codeCard)
corner(redeemVerifiedButton, 9)
local codeInput = new("TextBox", {
	Position = UDim2.fromOffset(178, 98), Size = UDim2.new(1, -294, 0, 32),
	BackgroundColor3 = Color3.fromRGB(16, 21, 34), BorderSizePixel = 0,
	Text = "", PlaceholderText = "ใส่โค้ดเอง", ClearTextOnFocus = false,
	TextColor3 = COLORS.Text, PlaceholderColor3 = COLORS.Sub, TextSize = 11,
	Font = Enum.Font.GothamBold,
}, codeCard)
corner(codeInput, 9)
local redeemCustomButton = new("TextButton", {
	Position = UDim2.new(1, -106, 0, 98), Size = UDim2.fromOffset(91, 32),
	BackgroundColor3 = Color3.fromRGB(42, 91, 76), BorderSizePixel = 0,
	Text = "REDEEM", TextColor3 = COLORS.Text, TextSize = 10,
	Font = Enum.Font.GothamBold, AutoButtonColor = false,
}, codeCard)
corner(redeemCustomButton, 9)
local openCodeButton = new("TextButton", {
	Position = UDim2.fromOffset(15, 137), Size = UDim2.new(1, -30, 0, 25),
	BackgroundTransparency = 1, Text = "เปิดหน้า Code ทางการของเกม", TextColor3 = COLORS.Cyan,
	TextSize = 10, Font = Enum.Font.GothamBold, AutoButtonColor = false,
}, codeCard)

local rewardSafety = makeCard(rewardsPage, 92)
titleLabel(rewardSafety, "ขอบเขตความปลอดภัย", "ไม่ซื้อสินค้า, ไม่ใช้ Monthly Make-up, ไม่ลบ Mail และไม่เรียกของที่เซิร์ฟเวอร์ไม่ได้อนุมัติ")

makeToggle(farmPage, "Auto Farm", "เปิด/ปิดระบบต่อสู้อัตโนมัติของเกม", COLORS.Green,
	function() return player:GetAttribute("AutoOn") == true end, setAutoFarm)
makeToggle(farmPage, "Auto Skill", "ใช้สกิล Archer ที่ตั้งไว้: Double Strafe, Arrow Shower, Piercing Shot", COLORS.Purple,
	function() return player:GetAttribute("AutoSkill") == true end, function(v) setRemoteBoolean("SetAutoSkill", v) end)
makeToggle(farmPage, "Auto Equip", "เลือกของจาก Combat Power อัตโนมัติ (อาจไม่ใช่สแตต Archer ที่สวยที่สุด)", COLORS.Blue,
	function() return player:GetAttribute("AutoEquip") == true end, function(v) setRemoteBoolean("SetAutoEquip", v) end)
makeToggle(farmPage, "Auto Build: Balanced", "อัปค่าสเตตัสสมดุลอัตโนมัติ; ปิดแล้วกลับเป็น Manual", COLORS.Orange,
	function() return player:GetAttribute("AutoBuild") == "balance" end, setBalanced)
makeToggle(farmPage, "Smart Quest Planner", "รับ Daily ที่ยังไม่เสร็จและเลือก Repeat Quest ที่ให้ EXP/Gold ต่อเป้าหมายดีที่สุด", COLORS.Blue,
	function() return state.autoQuestPlan end, function(v) state.autoQuestPlan = v end)
makeToggle(farmPage, "Auto Repeat Quest", "หลังเคลม จะรับซ้ำเฉพาะเควสต์ที่ระบุ Repeat=true เท่านั้น", COLORS.Cyan,
	function() return state.autoRepeat end, function(v) state.autoRepeat = v end)
makeToggle(farmPage, "Rush Assist", "เมื่อ Monster Rush เริ่ม จะเปิด Auto Farm ให้ทันทีเพื่อเก็บโบนัส 1.5×", COLORS.Red,
	function() return state.rushAssist end, function(v) state.rushAssist = v end)
makeToggle(farmPage, "No Clip", "ผ่านสิ่งกีดขวางฝั่งไคลเอนต์; ประตูเลเวลยังถูกเซิร์ฟเวอร์ตรวจอยู่", COLORS.Purple,
	function()
		local s = env.__CodexNoClipState
		return type(s) == "table" and s.enabled == true
	end,
	function(v)
		local s = env.__CodexNoClipState
		if type(s) == "table" and type(s.setEnabled) == "function" then s.setEnabled(v) else toast("ตัวควบคุม No Clip ไม่พร้อม", "bad") end
	end)

local questCard = makeCard(farmPage, 96)
titleLabel(questCard, "เควสต์ที่กำลังทำ", "กำลังอ่านข้อมูลเควสต์...")
local questStatus = new("TextLabel", {
	Position = UDim2.fromOffset(15, 69), Size = UDim2.new(1, -30, 0, 18),
	BackgroundTransparency = 1, Text = "", TextColor3 = COLORS.Cyan,
	TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, questCard)

local plannerCard = makeCard(farmPage, 104, Color3.fromRGB(27, 42, 58))
titleLabel(plannerCard, "เควสต์แนะนำ", "กำลังคำนวณ EXP + Gold ต่อจำนวนมอนสเตอร์และความต่างเลเวล...")
local plannerStatus = new("TextLabel", {
	Position = UDim2.fromOffset(15, 70), Size = UDim2.new(1, -30, 0, 24),
	BackgroundTransparency = 1, Text = "--", TextColor3 = COLORS.Green,
	TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, plannerCard)

makeToggle(farmPage, "Auto Sell Junk", "ขายเฉพาะ Item Kind=etc ที่เกมไม่กันไว้และไม่ได้ล็อก เมื่ออยู่ใกล้ Merchant หรือมี Premium", COLORS.Orange,
	function() return state.autoSellJunk end, function(v) state.autoSellJunk = v end)
local junkCard = makeCard(farmPage, 102)
titleLabel(junkCard, "Junk Seller", "เซิร์ฟเวอร์เป็นผู้คัดรายการขาย • ไม่ขาย Gear, Potion, Card, Refine Stone หรือของที่ล็อก")
local junkStatus = new("TextLabel", {
	Position = UDim2.fromOffset(15, 70), Size = UDim2.new(1, -150, 0, 20),
	BackgroundTransparency = 1, Text = "กำลังตรวจ junk...", TextColor3 = COLORS.Sub,
	TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, junkCard)
local sellJunkButton = new("TextButton", {
	Position = UDim2.new(1, -130, 0, 64), Size = UDim2.fromOffset(115, 28),
	BackgroundColor3 = Color3.fromRGB(97, 69, 42), BorderSizePixel = 0,
	Text = "SELL NOW", TextColor3 = COLORS.Text, TextSize = 9,
	Font = Enum.Font.GothamBold, AutoButtonColor = false,
}, junkCard)
corner(sellJunkButton, 8)

local speedCard = makeCard(farmPage, 116, Color3.fromRGB(30, 43, 55))
titleLabel(speedCard, "เส้นทางเลเวลเร็วสุดที่ตรวจพบ", "1) ปาร์ตี้กับผู้เล่นเลเวลสูง: เกมแชร์ EXP ได้ทุกส่วนต่างเลเวล  2) ทำ r06 Spotted Hyena  3) เก็บ Monster Rush 1.5×  4) แวะบอสทุก 10 นาที")
local moneyCard = makeCard(farmPage, 104, Color3.fromRGB(49, 41, 31))
titleLabel(moneyCard, "เส้นทาง Gold เร็วสุด", "Daily Quest รวมสูงสุด 4,500 Gold/วัน + ล่ามอนสเตอร์ระดับใกล้ตัว + ขาย official junk ใกล้ Merchant • เก็บไข่/การ์ดบอสไว้ก่อน ไม่ขายอัตโนมัติ")

local bosses = {
	{id = "terra_colossus", map = "Boss01", name = "Gorilla King", zone = "Terra"},
	{id = "bigboss_thornback_behemoth", map = "Boss02", name = "Whitefang Sabertooth", zone = "Frost"},
	{id = "bigboss_obsidian_pharaoh", map = "Boss03", name = "Obsidian Pharaoh", zone = "Desert"},
	{id = "bigboss_tempest_dragon_king", map = "Boss04", name = "Tempest Dragon King", zone = "Sky"},
	{id = "bigboss_volcano_turtle_king", map = "Boss05", name = "Volcano Turtle King", zone = "Volcano"},
}
local bossLabels = {}

local bossIntro = makeCard(bossPage, 87, Color3.fromRGB(34, 31, 53))
titleLabel(bossIntro, "BOSS RADAR", "บอสทุกตัวตั้ง Respawn 600 วินาที (10 นาที) • แจ้งเตือนเมื่อบอสกลับมาเกิด แต่จะไม่วาร์ปฝืนประตูเลเวล")
makeToggle(bossPage, "แจ้งเตือนบอสเกิด", "เตือนในหน้าต่างนี้ทันทีเมื่อสถานะเปลี่ยนจากรอเป็นพร้อมล่า", COLORS.Red,
	function() return state.bossAlerts end, function(v) state.bossAlerts = v end)

for index, boss in ipairs(bosses) do
	local card = makeCard(bossPage, 67)
	new("TextLabel", {
		Position = UDim2.fromOffset(15, 10), Size = UDim2.new(1, -145, 0, 22),
		BackgroundTransparency = 1, Text = boss.name, TextColor3 = COLORS.Text,
		TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	new("TextLabel", {
		Position = UDim2.fromOffset(15, 34), Size = UDim2.new(1, -145, 0, 18),
		BackgroundTransparency = 1, Text = boss.zone .. " • รอบละ 10 นาที", TextColor3 = COLORS.Sub,
		TextSize = 10, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	local status = new("TextLabel", {
		Position = UDim2.new(1, -130, 0.5, -14), Size = UDim2.fromOffset(114, 28),
		BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0, Text = "กำลังอ่าน...",
		TextColor3 = COLORS.Sub, TextSize = 10, Font = Enum.Font.GothamBold,
	}, card)
	corner(status, 14)
	bossLabels[boss.id] = {label = status, wasAlive = workspace:GetAttribute("BossAlive_" .. boss.id) == true, boss = boss}
end

local dungeonIntro = makeCard(dungeonPage, 106, Color3.fromRGB(28, 43, 58))
titleLabel(dungeonIntro, "SAFE DUNGEON ENTRY", "เข้าให้อัตโนมัติเฉพาะเมื่อเลเวลผ่าน, เป็นหัวหน้าปาร์ตี้ และยังมีรอบฟรี ระบบจะไม่ซื้อหรือใช้ Dungeon Key แทนคุณ")
local dungeonStatusLabel = new("TextLabel", {
	Position = UDim2.fromOffset(15, 76), Size = UDim2.new(1, -30, 0, 18),
	BackgroundTransparency = 1, Text = state.dungeonStatus, TextColor3 = COLORS.Cyan,
	TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, dungeonIntro)
makeToggle(dungeonPage, "เข้า Free Run อัตโนมัติ", "ค่าเริ่มต้นปิด; เปิดเมื่อยืนที่ดันและต้องการรับคำเชิญอัตโนมัติ", COLORS.Green,
	function() return state.autoDungeon end, function(v) state.autoDungeon = v end)

local gateInfo = makeCard(dungeonPage, 102)
titleLabel(gateInfo, "ทำไมเดินทะลุประตูแล้วยังเข้าไม่ได้?", "การชนกำแพงเป็นฝั่งเครื่องเรา แต่เงื่อนไขเลเวล, การโหลดแผนที่ และการเข้า Boss/Dungeon ถูกเซิร์ฟเวอร์ตรวจ จึงต้องผ่านเงื่อนไขจริง ระบบนี้จะใช้ช่องทางเข้าอย่างเป็นทางการเท่านั้น")
local keyInfo = makeCard(dungeonPage, 92)
titleLabel(keyInfo, "การใช้กุญแจ", "เมื่อรอบฟรีหมด หน้าต่างนี้จะหยุดและแจ้งเตือน จะไม่กดซื้อกุญแจหรือใช้ทรัพยากรโดยอัตโนมัติ")

local gearSummary = makeCard(gearPage, 104, Color3.fromRGB(33, 37, 55))
titleLabel(gearSummary, "GEAR SAFETY", "ตีบวกอัตโนมัติจะหยุดที่ +4 (ช่วงโอกาสสำเร็จ 100%) และเก็บเงินสำรองไว้ • รีโรลจะเปิดหน้าจอเกมให้ตัดสินใจเอง")
local gearStatus = new("TextLabel", {
	Position = UDim2.fromOffset(15, 76), Size = UDim2.new(1, -30, 0, 18),
	BackgroundTransparency = 1, Text = "กำลังอ่านหินและเงิน...", TextColor3 = COLORS.Cyan,
	TextSize = 10, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, gearSummary)

local refineCard = makeCard(gearPage, 128)
titleLabel(refineCard, "Safe Refine อุปกรณ์ที่สวมใส่ → +4", "ต้องอยู่ใกล้ Blacksmith • ใช้ Refine Stone • กดสองครั้งเพื่อยืนยัน • หยุดทันทีถ้าเงินจะต่ำกว่าเงินสำรอง")
local reserveButton = new("TextButton", {
	Position = UDim2.fromOffset(15, 82), Size = UDim2.fromOffset(155, 31),
	BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0,
	Text = "สำรองเงิน: 5,000", TextColor3 = COLORS.Orange, TextSize = 10,
	Font = Enum.Font.GothamBold, AutoButtonColor = false,
}, refineCard)
corner(reserveButton, 9)
local refineButton = new("TextButton", {
	Position = UDim2.new(1, -210, 0, 78), Size = UDim2.fromOffset(195, 38),
	BackgroundColor3 = Color3.fromRGB(50, 111, 89), BorderSizePixel = 0,
	Text = "SAFE REFINE", TextColor3 = COLORS.Text, TextSize = 11,
	Font = Enum.Font.GothamBold, AutoButtonColor = false,
}, refineCard)
corner(refineButton, 10)

local rerollCard = makeCard(gearPage, 120)
titleLabel(rerollCard, "Reroll แบบควบคุมเอง", "ครั้งแรกเริ่ม 5,000 Silver และการล็อกช่องใช้ Lock Charm • สำหรับ Archer ให้มองหา DEX, AGI, CRIT และ ATK%")
local rerollButton = new("TextButton", {
	Position = UDim2.new(1, -170, 0, 73), Size = UDim2.fromOffset(155, 34),
	BackgroundColor3 = Color3.fromRGB(86, 57, 126), BorderSizePixel = 0,
	Text = "เปิดหน้า REROLL", TextColor3 = COLORS.Text, TextSize = 10,
	Font = Enum.Font.GothamBold, AutoButtonColor = false,
}, rerollCard)
corner(rerollButton, 9)

local autoEquipInfo = makeCard(gearPage, 96)
titleLabel(autoEquipInfo, "คำเตือน Auto Equip", "เกมเลือกจาก Combat Power โดยรวม จึงเหมาะกับการโตไว แต่ของ CP ต่ำกว่าบางชิ้นอาจมี DEX/CRIT ที่เข้ากับ Archer มากกว่า ควรเช็กก่อนขายหรือรีโรล")

-- Compact category rows mirror the reference: details appear on demand.
-- Existing controls retain their instances and callbacks after reparenting.
do
	local function collectCards(page)
		local cards = {}
		for _, child in ipairs(page:GetChildren()) do
			if child:IsA("Frame") then table.insert(cards, child) end
		end
		table.sort(cards, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		return cards
	end

	local function section(page, title, order, cards, indices)
		local frame = new("Frame", {
			Name = "Section" .. tostring(order), Size = UDim2.new(1, -6, 0, 42),
			BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = order,
		}, page)
		local headerButton = new("TextButton", {
			Name = "Expand", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
			BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0,
			Text = "", AutoButtonColor = false,
		}, frame)
		corner(headerButton, 6)
		new("TextLabel", {
			Name = "Label", Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -45, 1, 0),
			BackgroundTransparency = 1, Text = title, TextColor3 = COLORS.Text,
			TextSize = 15, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
		}, headerButton)
		local arrow = new("TextLabel", {
			Name = "Arrow", Position = UDim2.new(1, -32, 0, 0), Size = UDim2.fromOffset(26, 42),
			BackgroundTransparency = 1, Text = "›", TextColor3 = COLORS.Sub,
			TextSize = 20, Font = Enum.Font.Gotham,
		}, headerButton)
		local body = new("Frame", {
			Name = "Body", Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
		}, frame)
		local layout = new("UIListLayout", {
			Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		}, body)
		for i, index in ipairs(indices) do
			local card = assert(cards[index], "Missing section card: " .. page.Name .. ":" .. tostring(index))
			card.LayoutOrder = i
			card.Parent = body
		end
		local expanded = false
		local function resize()
			local height = layout.AbsoluteContentSize.Y
			body.Size = UDim2.new(1, 0, 0, height)
			frame.Size = UDim2.new(1, -6, 0, expanded and height + 54 or 42)
		end
		track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize))
		track(headerButton.MouseButton1Click:Connect(function()
			expanded = not expanded
			body.Visible = expanded
			arrow.Text = expanded and "v" or "›"
			resize()
		end))
		track(headerButton.MouseEnter:Connect(function() headerButton.BackgroundTransparency = 0.6 end))
		track(headerButton.MouseLeave:Connect(function() headerButton.BackgroundTransparency = 1 end))
		resize()
	end

	local definitions = {
		{page = overviewPage, groups = {
			{"ตัวละครและสถานะ", {1}},
			{"ฟาร์มและเควสต์อัตโนมัติ", {4, 5}},
			{"เป้าหมายและโบนัส EXP", {2}},
			{"Monster Rush", {3}},
			{"การเปิดกล่อง", {6}},
		}},
		{page = rewardsPage, groups = {
			{"รับรางวัลอัตโนมัติ", {1, 2}},
			{"โค้ดและการแลกรางวัล", {3, 4}},
			{"เงื่อนไขการรับรางวัล", {5}},
		}},
		{page = farmPage, groups = {
			{"ตั้งค่าการต่อสู้", {1, 2, 3, 4}},
			{"จัดการและวางแผนเควสต์", {5, 6, 9, 10}},
			{"Monster Rush Assist", {7}},
			{"การเคลื่อนที่ / No Clip", {8}},
			{"ขายของอัตโนมัติ", {11, 12}},
			{"เส้นทาง EXP และ Gold", {13, 14}},
		}},
		{page = bossPage, groups = {
			{"ตั้งค่าการแจ้งเตือนบอส", {1, 2}},
			{"สถานะบอสทั้งหมด", {3, 4, 5, 6, 7}},
		}},
		{page = dungeonPage, groups = {
			{"เข้า Free Run อัตโนมัติ", {1, 2}},
			{"เงื่อนไขประตูและเลเวล", {3}},
			{"การใช้กุญแจดันเจี้ยน", {4}},
		}},
		{page = gearPage, groups = {
			{"สถานะอุปกรณ์และทรัพยากร", {1}},
			{"ตีบวก Safe Refine", {2}},
			{"รีโรลสแตตอุปกรณ์", {3}},
			{"การเลือกอุปกรณ์อัตโนมัติ", {4}},
		}},
	}
	for _, definition in ipairs(definitions) do
		local cards = collectCards(definition.page)
		for index, group in ipairs(definition.groups) do
			section(definition.page, group[1], index, cards, group[2])
		end
	end
end

local actionCooldown = {}
local function readyFor(key, seconds)
	local now = os.clock()
	if now - (actionCooldown[key] or 0) < seconds then return false end
	actionCooldown[key] = now
	return true
end

local function listHas(list, wanted)
	if type(list) ~= "table" then return false end
	for _, value in pairs(list) do if value == wanted then return true end end
	return false
end

local function processRewards()
	if not state.autoRewards then state.rewardStatus = "Auto Reward ปิดอยู่"; return end
	local claimed, pending = 0, 0
	local daily = decodeAttribute("DailyJson")
	if daily.CanClaim == true then
		pending += 1
		if (state.rewardAttempts.daily or 0) < 3 and readyFor("daily", 20) then
			local r = remote("DailyClaim")
			if r then
				r:FireServer()
				state.rewardAttempts.daily = (state.rewardAttempts.daily or 0) + 1
				claimed += 1
			end
		end
	end

	local rewards = decodeAttribute("RewardsJson")
	local c8 = type(rewards.C8) == "table" and rewards.C8 or {}
	if c8.Can == true then
		pending += 1
		if readyFor("reward_c8", 20) then
			local r = remote("RewardAction")
			if r then r:FireServer("c8", nil); claimed += 1 end
		end
	end
	local month = type(rewards.Month) == "table" and rewards.Month or {}
	local today = tonumber(month.Today)
	if today and not listHas(month.Days, today) then
		pending += 1
		if readyFor("reward_month", 20) then
			local r = remote("RewardAction")
			if r then r:FireServer("month", nil); claimed += 1 end
		end
	end
	local online = type(rewards.Online) == "table" and rewards.Online or {}
	local onlineSeconds = tonumber(online.Sec) or 0
	if tonumber(online.At) then onlineSeconds += math.min(75, math.max(0, serverNow() - tonumber(online.At))) end
	for index, definition in ipairs(RewardData.Online or {}) do
		local needed = (tonumber(definition.Minutes) or math.huge) * 60
		if onlineSeconds >= needed and not listHas(online.Got, index) then
			pending += 1
			if readyFor("reward_online_" .. index, 20) then
				local r = remote("RewardAction")
				if r then r:FireServer("online", index); claimed += 1 end
			end
		end
	end

	if (tonumber(player:GetAttribute("MailUnclaimed")) or 0) > 0 and readyFor("mail_all", 20) then
		local r = remote("MailAction")
		if r then r:FireServer("claimall"); claimed += 1 end
	end
	if (tonumber(player:GetAttribute("BattlePassReady")) or 0) > 0 and readyFor("battle_pass", 20) then
		local r = remote("BattlePassAction")
		if r then r:FireServer("claimAll"); r:FireServer("missionAll"); claimed += 1 end
	end
	if (tonumber(player:GetAttribute("AchieveReady")) or 0) > 0 and readyFor("achievements", 20) then
		local data = decodeAttribute("AchieveJson")
		local counters = type(data.C) == "table" and data.C or {}
		local got = type(data.Got) == "table" and data.Got or {}
		local r = remote("AchieveAction")
		if r then
			for _, definition in ipairs(AchievementData.List or {}) do
				local value = definition.Type == "level" and (tonumber(player:GetAttribute("Level")) or 1) or (tonumber(counters[definition.Type]) or 0)
				if definition.Id and not got[definition.Id] and value >= (tonumber(definition.Count) or math.huge) then
					r:FireServer("claim", definition.Id, false)
					claimed += 1
				end
			end
		end
	end
	state.rewardStatus = string.format("พร้อมรับ %d รายการ • ส่งคำขอแล้ว %d • Online %.0f นาที", pending, claimed, onlineSeconds / 60)
end

local verifiedCodes = {"HALLOWEEN", "BETATESTER"}
local function updateCodeStatus()
	local parts = {}
	for _, code in ipairs(verifiedCodes) do
		table.insert(parts, code .. ": " .. tostring(state.codeResults[code] or "รอลอง"))
	end
	if state.lastCode and state.lastCode ~= "HALLOWEEN" and state.lastCode ~= "BETATESTER" then
		table.insert(parts, state.lastCode .. ": " .. tostring(state.codeResults[state.lastCode] or "รอลอง"))
	end
	codeStatus.Text = table.concat(parts, "   •   ")
end

local function runCodeQueue(codes)
	if state.codeBusy then toast("กำลังตรวจโค้ดอื่นอยู่", "info"); return end
	state.codeBusy = true
	task.spawn(function()
		for _, raw in ipairs(codes) do
			if not runtime.alive then break end
			local code = string.upper(tostring(raw or "")):match("^%s*(.-)%s*$")
			if code ~= "" then
				state.lastCode = code
				local redeem = remote("RedeemCode")
				local ok, response = false, nil
				if redeem then ok, response = pcall(function() return redeem:InvokeServer(code) end) end
				local message = ok and type(response) == "table" and tostring(response.Msg or (response.Ok and "สำเร็จ" or "ไม่สำเร็จ")) or "เรียกโค้ดไม่สำเร็จ"
				state.codeResults[code] = message
				if type(response) == "table" and response.Ok then toast("รับโค้ด " .. code .. " สำเร็จ", "good") end
				updateCodeStatus()
				task.wait(3.2)
			end
		end
		state.codeBusy = false
	end)
end

track(redeemVerifiedButton.MouseButton1Click:Connect(function()
	state.codesProcessed = true
	runCodeQueue(verifiedCodes)
end))
track(redeemCustomButton.MouseButton1Click:Connect(function()
	local code = codeInput.Text
	if code:gsub("%s", "") == "" then toast("ใส่โค้ดก่อน", "bad") else runCodeQueue({code}) end
end))
track(codeInput.FocusLost:Connect(function(enterPressed)
	if enterPressed and codeInput.Text:gsub("%s", "") ~= "" then runCodeQueue({codeInput.Text}) end
end))
track(openCodeButton.MouseButton1Click:Connect(function() menuFire("code") end))

local function junkInfo()
	local items = decodeAttribute("ItemsJson")
	local locks = decodeAttribute("LocksJson")
	local keep = type(GameConfig.JunkKeep) == "table" and GameConfig.JunkKeep or {}
	local count, value = 0, 0
	for id, amount in pairs(items) do
		local definition = ItemData[id]
		if type(amount) == "number" and type(definition) == "table" and definition.Kind == "etc" and (tonumber(definition.Sell) or 0) > 0 and not keep[id] and not locks[id] then
			count += amount
			value += math.floor((tonumber(definition.Sell) or 0) * (100 + (tonumber(player:GetAttribute("SellBonusPct")) or 0)) / 100) * amount
		end
	end
	return count, value
end

local function nearMerchant()
	if player:GetAttribute("Premium") == true or player:GetAttribute("PremiumForever") == true then return true end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local candidates = {}
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("Model") and (string.find(string.lower(object.Name), "merchant", 1, true) or object:GetAttribute("NpcId") == "merchant") then
			table.insert(candidates, object)
		end
	end
	for _, object in ipairs(candidates) do
		local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
		if part and (part.Position - root.Position).Magnitude <= 22 then return true end
	end
	return false
end

local function sellJunk(manual)
	local count, value = junkInfo()
	junkStatus.Text = string.format("Junk %d ชิ้น • มูลค่าประมาณ %s Gold", count, comma(value))
	if count <= 0 then if manual then toast("ไม่มี junk ที่ขายได้", "info") end; return false end
	if not nearMerchant() then if manual then toast("ต้องอยู่ใกล้ Merchant ก่อน", "bad") end; return false end
	if not manual and count < state.junkThreshold then return false end
	if os.clock() - state.lastJunkSell < 20 then return false end
	local r = remote("ShopSellJunk")
	if not r then return false end
	state.lastJunkSell = os.clock()
	r:FireServer()
	toast(string.format("ส่งขาย junk %d ชิ้น • ~%s Gold", count, comma(value)), "good")
	return true
end

track(sellJunkButton.MouseButton1Click:Connect(function() sellJunk(true) end))

-- Quest automation: claim only verified completions, then repeat only the same repeatable quest.
local questCooldown = {}
local function questDefinitions()
	return type(QuestData.Quests) == "table" and QuestData.Quests or QuestData
end

local function bestRepeatQuest()
	local level = tonumber(player:GetAttribute("Level")) or 1
	local bestId, bestDef, bestScore, bestMonster
	for id, definition in pairs(questDefinitions()) do
		if type(definition) == "table" and definition.Repeat == true and (tonumber(definition.ReqLevel) or 0) <= level then
			if director.enabled and director.plan and definition.Target ~= director.plan.id then continue end
			local reward = definition.Reward or definition.Rewards or {}
			local count = math.max(1, tonumber(definition.Count) or 1)
			local monster = MonsterData[definition.Target] or {}
			local difference = math.abs(level - (tonumber(monster.Level) or level))
			local proximity = difference <= 2 and 1 or difference <= 4 and 0.75 or difference <= 6 and 0.5 or 0.25
			local score = ((tonumber(reward.Exp or definition.Exp) or 0) / count) + ((tonumber(reward.Silver or definition.Silver) or 0) / count * 0.25) + proximity * 8
			if not bestScore or score > bestScore then bestId, bestDef, bestScore, bestMonster = id, definition, score, monster end
		end
	end
	return bestId, bestDef, bestScore or 0, bestMonster or {}
end

local function processQuestPlan(data, active)
	local bestId, bestDef, score, monster = bestRepeatQuest()
	if bestId then
		plannerStatus.Text = string.format("%s • %s Lv.%s • Score %.1f", bestId, tostring(monster.Name or bestDef.Name), tostring(monster.Level or "?"), score)
	else
		plannerStatus.Text = "ยังไม่มี Repeat Quest ที่เหมาะกับเลเวลนี้"
	end
	if not state.autoQuestPlan or os.clock() - state.lastQuestPlan < 12 then return bestId end
	state.lastQuestPlan = os.clock()
	local action = remote("QuestAction")
	if not action then return bestId end
	local slots = 0
	for _ in pairs(active) do slots += 1 end
	local maxSlots = tonumber(GameConfig.MaxActiveQuests) or 6
	local definitions = questDefinitions()
	local daily = type(data.Daily) == "table" and data.Daily or {}
	local sortedIds = {}
	for id, definition in pairs(definitions) do
		if type(definition) == "table" and string.sub(tostring(id), 1, 1) == "d" and (tonumber(definition.ReqLevel) or 0) <= (tonumber(player:GetAttribute("Level")) or 1) and active[id] == nil and daily[id] ~= data.Today then
			table.insert(sortedIds, id)
		end
	end
	table.sort(sortedIds)
	for _, id in ipairs(sortedIds) do
		if slots >= maxSlots then break end
		action:FireServer("accept", id)
		slots += 1
	end
	if bestId and active[bestId] == nil and slots < maxSlots then
		action:FireServer("accept", bestId)
		toast("Planner รับเควสต์ " .. bestId .. " แล้ว", "good")
	end
	return bestId
end

local function questIsComplete(definition, progress, items)
	if type(definition) ~= "table" then return false end
	local kind = string.lower(tostring(definition.Type or ""))
	local needed = tonumber(definition.Count) or 1
	if kind == "level" then return (tonumber(player:GetAttribute("Level")) or 0) >= needed end
	if kind == "collect" or kind == "item" then
		local held = items[definition.Target]
		if type(held) == "table" then held = held.Count or held.Amount or 0 end
		return (tonumber(held) or 0) >= needed
	end
	return (tonumber(progress) or 0) >= needed
end

local function processQuests()
	local data = decodeAttribute("QuestsJson")
	local active = type(data.Active) == "table" and data.Active or {}
	local items = decodeAttribute("ItemsJson")
	local definitions = questDefinitions()
	local lines = {}
	local plannedId = processQuestPlan(data, active)
	for id, progress in pairs(active) do
		local def = definitions[id]
		local count = type(def) == "table" and (tonumber(def.Count) or 1) or 1
		table.insert(lines, string.format("%s %s/%s", tostring(id), tostring(progress), tostring(count)))
		if state.autoClaim and questIsComplete(def, progress, items) then
			local now = os.clock()
			if now - (questCooldown[id] or 0) > 6 then
				questCooldown[id] = now
				local action = remote("QuestAction")
				if action then
					action:FireServer("claim", id)
					toast("เคลมเควสต์ " .. tostring(id) .. " แล้ว", "good")
					if state.autoRepeat and type(def) == "table" and def.Repeat == true and (not state.autoQuestPlan or id == plannedId) then
						task.delay(1.25, function()
							if runtime.alive and state.autoRepeat then action:FireServer("accept", id) end
						end)
					end
				end
			end
		end
	end
	questStatus.Text = #lines > 0 and table.concat(lines, "   •   ") or "ไม่มีเควสต์ Active"
end

-- Safe dungeon handling: strict fail-closed checks.
local dungeonPrompt = remote("DungeonPrompt")
if dungeonPrompt and dungeonPrompt:IsA("RemoteEvent") then
	track(dungeonPrompt.OnClientEvent:Connect(function(action, data)
		if action ~= "dungeonselect" or type(data) ~= "table" then return end
		state.latestDungeon = data
		state.dungeonStatus = "ได้รับรายการดันเจี้ยนแล้ว — กำลังตรวจรอบฟรี"
		if director.HandleDungeon then director:HandleDungeon(data) end
	end))
end

-- Safe refine
local refineArmedAt = 0
local refining = false
local function nearBlacksmith()
	if player:GetAttribute("Premium") == true then return true end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	for _, object in ipairs(workspace:GetDescendants()) do
		if object:IsA("Model") and (string.find(string.lower(object.Name), "blacksmith", 1, true) or object:GetAttribute("NpcId") == "blacksmith") then
			local part = object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
			if part and (part.Position - root.Position).Magnitude <= 22 then return true end
		end
	end
	return false
end

local function itemCount(items, id)
	local value = items[id]
	if type(value) == "table" then value = value.Count or value.Amount or value.Qty end
	return tonumber(value) or 0
end

local function equippedRefs()
	local result, seen = {}, {}
	local equip = decodeAttribute("EquipJson")
	for _, ref in pairs(equip) do
		if type(ref) == "string" and ref ~= "" and not seen[ref] then seen[ref] = true; table.insert(result, ref) end
	end
	local weapon = player:GetAttribute("WeaponId")
	if type(weapon) == "string" and weapon ~= "" and not seen[weapon] then table.insert(result, weapon) end
	return result
end

local function safeRefine()
	if refining then return end
	if not GearUtil then toast("โหลด GearUtil ไม่สำเร็จ", "bad"); return end
	if not nearBlacksmith() then toast("ต้องยืนใกล้ Blacksmith ก่อน", "bad"); return end
	refining = true
	refineButton.Text = "กำลังตรวจอุปกรณ์..."
	local upgraded = 0
	for _, ref in ipairs(equippedRefs()) do
		if not runtime.alive then break end
		local gear = decodeAttribute("GearJson")
		local refine = decodeAttribute("RefineJson")
		local okDef, def = pcall(GearUtil.Resolve, ref, gear)
		local level = tonumber(refine[ref]) or 0
		while okDef and def and level < 4 do
			local nextLevel = level + 1
			local okCost, cost = pcall(GearUtil.RefineCost, def, nextLevel)
			local okStones, stones = pcall(GearUtil.RefineStones, def, nextLevel)
			cost = okCost and tonumber(cost) or math.huge
			local stoneId = okStones and type(stones) == "table" and stones.Stone or "refine_stone"
			local silver = tonumber(player:GetAttribute("Silver")) or 0
			local items = decodeAttribute("ItemsJson")
			if silver - cost < state.refineReserve then
				toast("หยุด: ต้องใช้ " .. comma(cost) .. " และต้องเหลือเงินสำรอง", "bad")
				break
			end
			if itemCount(items, stoneId) < 1 then toast("หยุด: Refine Stone ไม่พอ", "bad"); break end
			local refineRemote = remote("RefineWeapon")
			if not refineRemote then toast("ไม่พบระบบตีบวก", "bad"); break end
			local before = player:GetAttribute("RefineJson")
			refineRemote:FireServer(ref, false)
			local changed = false
			for _ = 1, 20 do
				task.wait(0.1)
				if player:GetAttribute("RefineJson") ~= before then changed = true; break end
			end
			if not changed then toast("เซิร์ฟเวอร์ไม่อนุมัติการตีบวก", "bad"); break end
			level = tonumber(decodeAttribute("RefineJson")[ref]) or level
			upgraded += 1
			task.wait(0.25)
		end
	end
	refining = false
	refineButton.Text = "SAFE REFINE"
	if upgraded > 0 then toast("ตีบวกสำเร็จ " .. tostring(upgraded) .. " ขั้น (ไม่เกิน +4)", "good")
	else toast("ไม่มีชิ้นที่ตีได้ภายใต้เงื่อนไขปลอดภัย", "info") end
end

track(reserveButton.MouseButton1Click:Connect(function()
	state.refineReserve = state.refineReserve == 5000 and 0 or 5000
	reserveButton.Text = "สำรองเงิน: " .. comma(state.refineReserve)
	reserveButton.TextColor3 = state.refineReserve > 0 and COLORS.Orange or COLORS.Red
	toast(state.refineReserve > 0 and "เปิดเงินสำรอง 5,000" or "ปิดเงินสำรอง — ระวังเงินหมด", state.refineReserve > 0 and "good" or "bad")
end))

track(refineButton.MouseButton1Click:Connect(function()
	if os.clock() - refineArmedAt > 3 then
		refineArmedAt = os.clock()
		refineButton.Text = "กดอีกครั้งเพื่อยืนยัน"
		task.delay(3.1, function() if runtime.alive and not refining then refineButton.Text = "SAFE REFINE" end end)
	else
		refineArmedAt = 0
		task.spawn(safeRefine)
	end
end))

track(rerollButton.MouseButton1Click:Connect(function()
	if menuFire("reroll") then toast("เปิดหน้า Reroll ของเกมแล้ว — ตรวจสแตตก่อนกดยืนยัน", "info")
	else toast("เปิดหน้า Reroll ไม่สำเร็จ", "bad") end
end))

-- One owner for movement and native auto combat. No direct position writes.
do
	local CollectionService = game:GetService("CollectionService")
	local nodes, spawnZones = {}, {}
	for id, data in pairs(MapData) do
		if type(data) == "table" and tonumber(data.Order) then
			table.insert(nodes, {id = id, data = data})
			for _, spawn in ipairs(data.Spawns or {}) do spawnZones[spawn.Id] = id end
		end
	end
	table.sort(nodes, function(a, b) return a.data.Order < b.data.Order end)

	function director:Character()
		local character = player.Character
		return character and character:FindFirstChild("HumanoidRootPart"), character and character:FindFirstChildOfClass("Humanoid")
	end

	function director:TotalExp(level, progress)
		local total = tonumber(progress) or 0
		for previous = 1, math.max(1, tonumber(level) or 1) - 1 do
			local need = ExpTable.BaseNeed and ExpTable.BaseNeed(previous) or (ExpTable.Base and ExpTable.Base[previous])
			total += tonumber(need) or 0
		end
		return total
	end

	function director:HealingSupply()
		local items, count = decodeAttribute("ItemsJson"), 0
		for id, definition in pairs(ItemData) do
			if type(definition) == "table" and definition.Kind == "usable"
				and ((tonumber(definition.HealMin) or 0) > 0 or (tonumber(definition.HealMax) or 0) > 0 or (tonumber(definition.HealPercent) or 0) > 0) then
				count += itemCount(items, id)
			end
		end
		return count
	end

	function director:RetreatReason(healthFraction, plan, potionStart, potionNow)
		if healthFraction < 0.35 then return "เลือดต่ำ" end
		if plan and plan.boss and potionStart and potionNow and potionStart - potionNow >= 5 then return "ใช้ยาครบ 5 ขวดแล้ว" end
		return nil
	end

	function director:CanAccess(id)
		local definition = MapData[id]
		if not definition then return false, "ไม่พบข้อมูลแผนที่" end
		local level = tonumber(player:GetAttribute("Level")) or 1
		local minimum = tonumber(tostring(definition.LevelText):match("%d+"))
		if not minimum or level < minimum then return false, "ต้องการ Lv." .. tostring(minimum or "?") end
		local gates = {}
		for _, part in ipairs(CollectionService:GetTagged("BossLock")) do
			if part:IsA("BasePart") and not part:GetAttribute("NoCollide") then gates[part:GetAttribute("BossId")] = part end
		end
		for _, node in ipairs(nodes) do
			if node.data.Order >= definition.Order then break end
			local gate = gates[node.id]
			if gate and gate.CanCollide then
				local required = gate:GetAttribute("LockText")
				if node.data.BossRoom then required = "ต้องชนะ " .. tostring((MonsterData[node.data.Boss] or {}).Name or node.id) end
				return false, required or ("ประตู " .. node.id .. " ยังล็อก")
			end
		end
		if (self.blockedZones[id] or 0) > os.clock() then return false, "พักโซนที่เดินไปไม่ถึง" end
		return true
	end

	function director:ZonePart(id)
		local folder = workspace:FindFirstChild("Zones")
		local zone = folder and folder:FindFirstChild(id)
		return zone and zone:IsA("BasePart") and zone or nil
	end

	function director:Monster(id)
		local folder = workspace:FindFirstChild("Monsters")
		local root = self:Character()
		local found, distance
		for _, model in ipairs(folder and folder:GetChildren() or {}) do
			if model:IsA("Model") and model:GetAttribute("MonsterId") == id and (tonumber(model:GetAttribute("HP")) or 0) > 0 and model.PrimaryPart then
				local value = root and (root.Position - model.PrimaryPart.Position).Magnitude or 0
				if not distance or value < distance then found, distance = model, value end
			end
		end
		return found
	end

	function director:DungeonStatus()
		local level = tonumber(player:GetAttribute("Level")) or 1
		local minimum, selected, selectedId
		for id, data in pairs(DungeonData.Dungeons or {}) do
			local required = tonumber(data.MinLevel)
			if required and (not minimum or required < minimum) then minimum = required end
			if required and required <= level and (not selected or required > selected.MinLevel) then selected, selectedId = data, id end
		end
		if not selected then
			return false, minimum and string.format("ดัน: Lv.%d / ต้อง Lv.%d (อีก %d เลเวล)", level, minimum, math.max(0, minimum - level)) or "ดัน: ยังไม่มีข้อมูลที่เข้าได้"
		end
		if DungeonData.Open == false then return false, "ดัน: เซิร์ฟเวอร์ยังไม่เปิด" end
		if DungeonData.AdminOnly == true and player:GetAttribute("IsAdmin") ~= true then return false, "ดัน: จำกัดสิทธิ์ทดสอบในเซิร์ฟเวอร์นี้" end
		return true, "ดัน: เลเวลผ่าน รอรายการรอบฟรีจาก NPC", selectedId
	end

	function director:ChooseDungeon(data, level)
		if type(data) ~= "table" or data.IsLeader ~= true then return nil, "ต้องเป็นหัวหน้าปาร์ตี้" end
		if type(data.Dungeons) ~= "table" then return nil, "ยังไม่มีรายการรอบฟรีจากเซิร์ฟเวอร์" end
		local selected
		for _, definition in pairs(data.Dungeons) do
			if type(definition) ~= "table" then continue end
			local required, free, used = tonumber(definition.MinLevel), tonumber(definition.Free), tonumber(definition.Used)
			if type(definition.Id) ~= "string" or not required or not free or not used then continue end
			if required > level or free - used <= 0 then continue end
			local partyReady = true
			for _, member in ipairs(data.Party or {}) do
				if (tonumber(member.Level) or 0) < required then partyReady = false end
			end
			if partyReady and (not selected or required > selected.MinLevel) then selected = definition end
		end
		return selected, selected and "พร้อมลงด้วยรอบฟรี" or "ไม่มีดันที่เลเวลผ่านและมีรอบฟรี"
	end

	function director:HandleDungeon(data)
		if not (state.autoDungeon or (self.enabled and self.runDungeons)) then return end
		local definition, reason = self:ChooseDungeon(data, tonumber(player:GetAttribute("Level")) or 1)
		if not definition then state.dungeonStatus = reason; self.dungeonTrip = false; self.lastDungeonAttempt = os.clock(); return end
		if os.clock() - (self.lastDungeonRequest or -100) < 20 then return end
		self.lastDungeonRequest, self.dungeonRequested = os.clock(), definition.Id
		self.dungeonTrip, self.dungeonEntering = false, os.clock() + 25
		state.dungeonStatus = "เข้า " .. tostring(definition.Name or definition.Id) .. " • Easy / รอบฟรี"
		setAutoFarm(false)
		if remote("DungeonAction") then remote("DungeonAction"):FireServer("selectEnter", definition.Id, "easy") end
	end

	function director:DungeonTrip()
		local eligible = self:DungeonStatus()
		if not self.runDungeons or not eligible then self.dungeonTrip = false; return false end
		if not self.dungeonTrip and os.clock() - (self.lastDungeonAttempt or -600) < 600 then return false end
		if self.plan and self.plan.boss then return false end
		local map = workspace:FindFirstChild("Map")
		local village = map and map:FindFirstChild("Village")
		local gate = village and village:FindFirstChild("DungeonGate_Village")
		local keeper = gate and gate:FindFirstChild("GateKeeper")
		local torso = keeper and keeper:FindFirstChild("Torso")
		local prompt = torso and torso:FindFirstChild("DungeonPrompt")
		if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
		if not self.dungeonTrip then
			self.dungeonTrip, self.lastDungeonAttempt, self.promptFiredAt = true, os.clock(), nil
			self:CancelNavigation()
			self.navProgress = nil
		end
		setAutoFarm(false)
		local root = self:Character()
		if not root then return true end
		if (root.Position - torso.Position).Magnitude > math.max(3, prompt.MaxActivationDistance - 1) then
			self.phase, self.detail = "กำลังไปหน้าดัน", "เดินไปคุย GateKeeper เพื่อตรวจรอบฟรีจริง"
			self:Walk(torso.Position)
			return true
		end
		self.phase, self.detail = "กำลังตรวจสิทธิ์ลงดัน", "รอข้อมูลจาก NPC • ถ้ารอบฟรีหมดจะกลับไปฟาร์ม"
		if not self.promptFiredAt then
			self.promptFiredAt = os.clock()
			local firePrompt = rawget(env, "fireproximityprompt")
			if type(firePrompt) == "function" then firePrompt(prompt) else
				prompt:InputHoldBegin()
				task.delay(prompt.HoldDuration + 0.1, function() if prompt.Parent then prompt:InputHoldEnd() end end)
			end
		elseif os.clock() - self.promptFiredAt > 12 then
			self.dungeonTrip = false
			self.phase, self.detail = "กลับไปฟาร์ม", "NPC ไม่ส่งรายการดัน กลับไปฟาร์มและลองใหม่ภายหลัง"
		end
		return self.dungeonTrip
	end

	if dungeonPrompt then
		track(dungeonPrompt.OnClientEvent:Connect(function(action, data)
			if action ~= "ready" or type(data) ~= "table" or type(data.Id) ~= "string" then return end
			if not director.enabled or not director.runDungeons or not director.dungeonRequested then return end
			if os.clock() - (director.lastDungeonRequest or 0) > 20 then return end
			director.dungeonRequested = nil
			if remote("DungeonAction") then remote("DungeonAction"):FireServer("ready", data.Id, true) end
		end))
	end

	function director:SelectPlan()
		local root, humanoid = self:Character()
		local level = tonumber(player:GetAttribute("Level")) or 1
		local now = os.clock()
		if self.huntBosses and humanoid then
			for index = #bosses, 1, -1 do
				local boss = bosses[index]
				local definition = MonsterData[boss.id] or {}
				local model = self:Monster(boss.id)
				local spawnKey = model and model:GetAttribute("SpawnAt") or self.bossSpawnKeys[boss.id] or workspace:GetAttribute("BossNext_" .. boss.id)
				self.bossSpawnKeys[boss.id] = spawnKey
				local healthy = humanoid.Health / math.max(1, humanoid.MaxHealth) >= 0.7
				local alreadyFighting = self.plan and self.plan.boss and self.plan.id == boss.id
				if (healthy or alreadyFighting) and (definition.Level or math.huge) <= level and self:CanAccess(boss.map) and self:ZonePart(boss.map)
					and workspace:GetAttribute("BossAlive_" .. boss.id) == true and (self.cooldowns[boss.id] or 0) <= now
					and (not spawnKey or self.failedBossSpawns[boss.id] ~= spawnKey) then
					return {id = boss.id, zone = boss.map, name = boss.name, level = definition.Level, boss = true, model = model, spawnKey = spawnKey}
				end
			end
		end
		local choice, bestDistance
		local folder = workspace:FindFirstChild("Monsters")
		local cap = math.min(level, self.levelCap or level)
		for _, model in ipairs(folder and folder:GetChildren() or {}) do
			local id = model:GetAttribute("MonsterId")
			local definition = id and MonsterData[id]
			local zone = id and spawnZones[id]
			local hp = tonumber(model:GetAttribute("HP")) or 0
			local rank = definition and tonumber(definition.Level)
			if model:IsA("Model") and model.PrimaryPart and definition and zone and rank and rank <= cap and hp > 0
				and not definition.Boss and not definition.MiniBoss and not string.find(id, "boss", 1, true)
				and (self.cooldowns[id] or 0) <= now and self:CanAccess(zone) then
				local distance = root and (root.Position - model.PrimaryPart.Position).Magnitude or 0
				if not choice or rank > choice.level or (rank == choice.level and distance < bestDistance) then
					choice = {id = id, zone = zone, name = definition.Name or id, level = rank, model = model, boss = false}
					bestDistance = distance
				end
			end
		end
		-- Keep fighting the current living monster instead of switching every tick.
		local current = self.plan
		if choice and current and not current.boss and current.model and current.model.Parent
			and (current.model:GetAttribute("HP") or 0) > 0 and current.level >= choice.level
			and (self.cooldowns[current.id] or 0) <= now and self:CanAccess(current.zone) then return current end
		return choice
	end

	function director:CancelNavigation()
		self.navToken += 1
		self.navBusy, self.waypoints, self.navGoal = false, nil, nil
	end

	function director:Walk(goal)
		local root, humanoid = self:Character()
		if not root or not humanoid then return false end
		if (root.Position - goal).Magnitude < 10 then return true end
		local now = os.clock()
		if not self.navProgress or (root.Position - self.navProgress).Magnitude > 2 then
			self.navProgress, self.navProgressAt = root.Position, now
		elseif now - (self.navProgressAt or now) > 9 then
			if self.plan then self.blockedZones[self.plan.zone] = now + 45; self.cooldowns[self.plan.id] = now + 45 end
			self.plan = nil
			self:CancelNavigation()
			self.navProgressAt = now
			self.phase, self.detail = "เส้นทางติดขัด", "พักเส้นทางนี้ 45 วินาที แล้วหาเป้าหมายใหม่"
			return false
		end
		if self.waypoints and self.navGoal and (self.navGoal - goal).Magnitude < 16 then
			local point = self.waypoints[self.waypointIndex]
			while point and (root.Position - point.Position).Magnitude < 5 do
				self.waypointIndex += 1
				point = self.waypoints[self.waypointIndex]
			end
			if point then
				if point.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
				humanoid:MoveTo(point.Position)
				return false
			end
			self.waypoints = nil
		end
		if self.navBusy or now - (self.lastPathAt or 0) < 1.5 then return false end
		self.lastPathAt, self.navBusy, self.navGoal = now, true, goal
		local token = self.navToken
		task.spawn(function()
			local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5})
			local ok = pcall(path.ComputeAsync, path, root.Position, goal)
			if token ~= self.navToken or not (self.enabled or self.travel.active) then return end
			self.navBusy = false
			if ok and path.Status == Enum.PathStatus.Success then
				self.waypoints, self.waypointIndex = path:GetWaypoints(), 2
			else
				-- A normal MoveTo can cross small stair segments that pathfinding misses.
				-- Lack of progress is caught above; no teleports or collision changes.
				humanoid:MoveTo(goal)
			end
		end)
		return false
	end

	function director:ApplyEquip()
		if (player:GetAttribute("AutoEquip") == true) == self.equipBest then return end
		if os.clock() - (self.lastEquipRequest or -10) < 5 then return end
		self.lastEquipRequest = os.clock()
		setRemoteBoolean("SetAutoEquip", self.equipBest)
	end

	function director:CurrentZone()
		local root = self:Character()
		if not root then return "Town" end
		local chosen, distance = "Town", math.huge
		local folder = workspace:FindFirstChild("Zones")
		for _, part in ipairs(folder and folder:GetChildren() or {}) do
			if part:IsA("BasePart") and MapData[part.Name] then
				local delta = root.Position - part.Position
				local value = Vector2.new(delta.X, delta.Z).Magnitude
				if value < distance then distance, chosen = value, part.Name end
			end
		end
		if distance > 150 then return "Town" end
		return chosen
	end

	function director:PillarAvailable(id)
		if id == "Town" then return true end
		for unlocked in string.gmatch(tostring(player:GetAttribute("WarpPillars") or ""), "[^,]+") do
			if unlocked == id then return true end
		end
		return false
	end

	function director:TravelRoute(id, returnPosition)
		local root = self:Character()
		local map = workspace:FindFirstChild("Map")
		local pillars = map and map:FindFirstChild("WarpPillars")
		local zone = self:ZonePart(id)
		local goal = returnPosition or (zone and zone.Position)
		local direct = (id == "Town" or (MapData[id] and MapData[id].BossRoom)) and id or nil
		if direct and self:PillarAvailable(direct) then return direct, direct == "Town" and 0 or (tonumber(direct:match("%d+")) or 0) * 1000 end
		if not root or not goal or not pillars then return nil, 0 end
		local sourceDistance = math.huge
		for _, model in ipairs(pillars:GetChildren()) do
			local column = model:FindFirstChild("Column")
			if column then sourceDistance = math.min(sourceDistance, (column.Position - root.Position).Magnitude) end
		end
		local best, bestDistance = nil, (root.Position - goal).Magnitude - 90
		for _, model in ipairs(pillars:GetChildren()) do
			local pillarId, column = model:GetAttribute("WarpId"), model:FindFirstChild("Column")
			if column and type(pillarId) == "string" and self:PillarAvailable(pillarId) and (pillarId == "Town" or self:CanAccess(pillarId)) then
				local distance = sourceDistance + (column.Position - goal).Magnitude
				if distance < bestDistance then best, bestDistance = pillarId, distance end
			end
		end
		return best, best and best ~= "Town" and (tonumber(best:match("%d+")) or 0) * 1000 or 0
	end

	function director:CancelTrip()
		self.travel.token += 1
		self.travel.active = false
		self:CancelNavigation()
		local root, humanoid = self:Character()
		if root and humanoid then humanoid:MoveTo(root.Position) end
		self.travel.status = "ยกเลิกการเดินทางแล้ว"
	end

	function director:ReturnTrip()
		if not self.travel.bookmark then self.travel.status = "ยังไม่มีจุดก่อนเดินทาง"; return end
		self:TravelTo(self.travel.bookmark.zone, self.travel.bookmark.position, true)
	end

	function director:TravelTo(id, returnPosition, returning)
		local allowed, reason = true, nil
		if id ~= "Town" then allowed, reason = self:CanAccess(id) end
		if not allowed then self.travel.status = "ไปไม่ได้: " .. tostring(reason); return end
		local pillarId, cost = self:TravelRoute(id, returnPosition)
		if cost > 0 and self:PillarAvailable(pillarId) then
			if (tonumber(player:GetAttribute("Silver")) or 0) < cost then self.travel.status = "Silver ไม่พอ: วาร์ปนี้ใช้ " .. comma(cost); return end
		end
		local root = self:Character()
		if not root then self.travel.status = "รอตัวละครเกิดก่อน"; return end
		if workspace:GetAttribute("DungeonId") ~= nil then self.travel.status = "ใช้ปุ่มออกดันของเกมก่อนเดินทาง"; return end
		if self.enabled then self:SetEnabled(false) else setAutoFarm(false) end
		self:CancelTrip()
		if not returning then self.travel.bookmark = {zone = self:CurrentZone(), position = root.Position} end
		local travel = self.travel
		travel.active, travel.status = true, "เตรียมเดินทางไป " .. id
		local token, deadline = travel.token, os.clock() + 150
		self.navProgress, self.plan = nil, nil
		task.spawn(function()
			local ok, message = xpcall(function()
				local map = workspace:FindFirstChild("Map")
				local pillars = map and map:FindFirstChild("WarpPillars")
				local pillarModel = pillars and pillarId and pillars:FindFirstChild("WarpPillar_" .. pillarId)
				local destination = pillarModel and pillarModel:FindFirstChild("Column")
				local function alive() return runtime.alive and travel.active and travel.token == token and os.clock() < deadline end
				local function moveTo(goal, label, tolerance)
					self:CancelNavigation()
					self.navProgress = nil
					while alive() do
						local current, humanoid = self:Character()
						if not current or not humanoid or humanoid.Health <= 0 then error("ตัวละครเสียชีวิตระหว่างเดินทาง") end
						if (current.Position - goal).Magnitude <= (tolerance or 9) then return true end
						travel.status = label .. string.format(" • %.0f studs", (current.Position - goal).Magnitude)
						self:Walk(goal)
						task.wait(0.35)
					end
					return false
				end
				if destination and self:PillarAvailable(pillarId) and (root.Position - destination.Position).Magnitude > 35 then
					local source, nearest
					for _, model in ipairs(pillars:GetChildren()) do
						local pillar = model:FindFirstChild("Column")
						if pillar and pillar:IsA("BasePart") then
							local distance = (pillar.Position - root.Position).Magnitude
							if not nearest or distance < nearest then source, nearest = pillar, distance end
						end
					end
					if not source then error("ไม่พบเสาวาร์ปต้นทาง") end
					if not moveTo(source.Position + Vector3.new(0, 0, 7), "กำลังเดินไปเสาวาร์ป", 9) then return end
					local prompt = source:FindFirstChild("WarpPrompt")
					if prompt then
						local fire = rawget(env, "fireproximityprompt")
						if type(fire) == "function" then fire(prompt) else prompt:InputHoldBegin(); task.wait(prompt.HoldDuration + 0.1); prompt:InputHoldEnd() end
						task.wait(0.5)
					end
					if not alive() then return end
					local event = remote("PillarWarp")
					if not event then error("ไม่พบ PillarWarp ของเกม") end
					self:CancelNavigation()
					travel.status = "ส่งคำขอวาร์ปไป " .. id .. " • รอเซิร์ฟเวอร์"
					event:FireServer(pillarId)
					local responseDeadline = os.clock() + 10
					local arrived = false
					while alive() and os.clock() < responseDeadline do
						local current = self:Character()
						if current and (current.Position - destination.Position).Magnitude < 65 then arrived = true; break end
						task.wait(0.25)
					end
					if not arrived then error("เซิร์ฟเวอร์ไม่ยืนยันวาร์ป (ตรวจเสาที่ปลดล็อก/Silver/ระยะ)") end
				end
				local zone = self:ZonePart(id)
				local goal = returnPosition or (destination and destination.Position + Vector3.new(0, 0, 7)) or (zone and zone.Position + Vector3.new(0, 3, 0))
				if not goal then error("โซนยังไม่โหลดหรือไม่มีเสาวาร์ป") end
				if not moveTo(goal, returning and "กำลังกลับจุดเดิม" or "กำลังไปจุดหมาย", 10) then return end
				travel.status = returning and "กลับถึงจุดเดิมแล้ว" or ("ถึง " .. id .. " แล้ว • กดเริ่มเพื่อฟาร์ม")
				travel.lastArrival = {id = id, returning = returning == true, at = os.clock()}
			end, debug.traceback)
			if travel.token ~= token then return end
			if not ok then travel.status, travel.lastError = "เดินทางไม่สำเร็จ: " .. tostring(message):match("[^\n]+"), tostring(message) end
			if os.clock() >= deadline then travel.status = "เดินทางหมดเวลา ลองเลือกจุดใกล้ขึ้น" end
			travel.active = false
			self:CancelNavigation()
		end)
	end

	function director:ConfigureTarget(id)
		if self.configuredId == id then return true end
		local settings = decodeAttribute("BotJson")
		local excludes = {}
		for monsterId, definition in pairs(MonsterData) do if type(definition) == "table" and monsterId ~= id then excludes[monsterId] = true end end
		settings.Exclude, settings.Only = excludes, {}
		settings.Mode, settings.Preset = "fight", "normal"
		settings.AttackLeader, settings.NormalAttack, settings.UseSkills = true, true, true
		settings.FixedArea, settings.Loot = false, true
		local event = remote("SetBotSettings")
		if not event then self.phase, self.detail = "หยุด: ตั้งเป้าหมายไม่ได้", "ไม่พบ SetBotSettings"; return false end
		event:FireServer(settings)
		self.configuredId, self.settingsSentAt = id, os.clock()
		return true
	end

	function director:Watch(model)
		if self.observed == model then return end
		if self.observer then self.observer:Disconnect(); self.observer = nil end
		self.observed = model
		if not model then return end
		local counted = false
		self.observer = model:GetAttributeChangedSignal("HP"):Connect(function()
			if self.enabled and not counted and (model:GetAttribute("HP") or 1) <= 0 then
				counted = true
				self.kills += 1
				if self.plan and self.plan.boss and self.plan.model == model then
					self.bossLootUntil = os.clock() + 5
					self.lastDecision = "ชนะ " .. self.plan.name .. " • รอเก็บของก่อนกลับฟาร์ม"
				end
			end
		end)
	end

	function director:Preview()
		local plan = self:SelectPlan()
		self.preview = plan
		self.phase = "พร้อมเริ่มฟาร์ม"
		self.detail = plan and string.format("เป้าหมาย: %s Lv.%d • %s\nเลือกตัวเลเวลสูงสุดในโซนที่เข้าถึงได้", plan.name, plan.level, (MapData[plan.zone] or {}).DisplayName or plan.zone) or "ยังไม่พบมอนสเตอร์ในโซนที่เข้าถึงได้"
	end

	function director:SetEnabled(value)
		if value == self.enabled then return end
		if value and self.travel.active then self:CancelTrip() end
		self.enabled = value
		self:CancelNavigation()
		if value then
			self.savedBot = decodeAttribute("BotJson")
			self.savedAutoSkill = player:GetAttribute("AutoSkill") == true
			self.startedAt, self.startExp, self.startSilver = os.clock(), tonumber(player:GetAttribute("Exp")) or 0, tonumber(player:GetAttribute("Silver")) or 0
			self.startLevel = tonumber(player:GetAttribute("Level")) or 1
			self.startTotalExp = self:TotalExp(self.startLevel, self.startExp)
			self.kills, self.plan, self.configuredId, self.levelCap = 0, nil, nil, nil
			self.navProgress, self.cooldowns, self.blockedZones = nil, {}, {}
			self.resting, self.restGoal = false, nil
			self.lastDecision, self.bossLootUntil, self.bossPotionStart = nil, nil, nil
			state.autoClaim, state.autoQuestPlan, state.autoRewards, state.autoSellJunk = true, true, true, true
			setRemoteBoolean("SetAutoSkill", true)
			self.phase, self.detail = "กำลังหาเป้าหมาย", "กำลังตรวจเลเวล ประตู และมอนสเตอร์ที่ยังมีชีวิต"
		else
			setAutoFarm(false)
			local root, humanoid = self:Character()
			if humanoid and root then humanoid:MoveTo(root.Position) end
			local event = remote("SetBotSettings")
			if event and self.savedBot then event:FireServer(self.savedBot) end
			if self.savedAutoSkill ~= nil then setRemoteBoolean("SetAutoSkill", self.savedAutoSkill) end
			if self.resting and remote("SitToggle") then remote("SitToggle"):FireServer(false) end
			self.resting, self.plan, self.configuredId = false, nil, nil
			self.dungeonTrip, self.dungeonEntering, self.dungeonRequested = false, nil, nil
			state.autoClaim, state.autoQuestPlan, state.autoRewards, state.autoSellJunk = false, false, false, false
			self:Watch(nil)
			self.phase, self.detail = "หยุดแล้ว", "หยุดการเดินและต่อสู้อัตโนมัติแล้ว กดเริ่มเพื่อทำต่อ"
		end
	end

	function director:Tick()
		if not self.enabled then return end
		if self.levelCap and os.clock() > (self.levelCapUntil or 0) then self.levelCap = nil end
		local root, humanoid = self:Character()
		if not root or not humanoid or humanoid.Health <= 0 then
			if self.plan then self.cooldowns[self.plan.id] = os.clock() + 120; self.levelCap = math.max(1, self.plan.level - 1); self.levelCapUntil = os.clock() + 120 end
			self.plan = nil
			self:CancelNavigation()
			self.phase, self.detail = "รอเกิดใหม่", "ลดเป้าหมายหลังเสียชีวิต • ไม่ใช้การเกิดใหม่แบบเสียเงิน"
			return
		end
		local health = humanoid.Health / math.max(1, humanoid.MaxHealth)
		local retreatReason = self:RetreatReason(health, self.plan, self.bossPotionStart, self.plan and self.plan.boss and self:HealingSupply() or nil)
		if retreatReason or self.resting then
			if not self.resting then
				self.resting = true
				if self.plan then
					self.cooldowns[self.plan.id] = os.clock() + (self.plan.boss and 600 or 120)
					if self.plan.boss then
						self.failedBossSpawns[self.plan.id] = self.plan.spawnKey
						self.lastDecision = "พัก " .. self.plan.name .. ": " .. tostring(retreatReason)
					end
					if not self.plan.boss then self.levelCap, self.levelCapUntil = math.max(1, self.plan.level - 1), os.clock() + 120 end
					if self.plan.boss then
						local previous
						for _, node in ipairs(nodes) do
							if node.data.Order >= MapData[self.plan.zone].Order then break end
							if not node.data.BossRoom and self:CanAccess(node.id) and self:ZonePart(node.id) then previous = self:ZonePart(node.id) end
						end
						self.restGoal = previous and previous.Position + Vector3.new(0, 3, 0)
					end
				end
				self:CancelNavigation()
			end
			setAutoFarm(false)
			if self.restGoal and (root.Position - self.restGoal).Magnitude > 12 then
				self.phase, self.detail = "ถอยจากบอสเพื่อพัก", "เลือดต่ำ กลับไปจุดฟาร์มก่อนพักฟื้น"
				self:Walk(self.restGoal)
				return
			end
			if remote("SitToggle") then remote("SitToggle"):FireServer(health < 0.75) end
			self.phase, self.detail = "พักฟื้นเลือด", string.format("HP %.0f%% • กลับไปฟาร์มเมื่อ HP ถึง 75%%", health * 100)
			if health >= 0.75 then self.resting, self.plan, self.configuredId, self.restGoal = false, nil, nil, nil end
			return
		end
		if workspace:GetAttribute("DungeonId") ~= nil then
			self.phase, self.detail = "อยู่ในดันเจี้ยน", "ใช้ระบบ Auto ของเกมในดัน • ตั้งค่าเส้นทางและการเก็บของจากตัวเกม"
			setAutoFarm(true)
			return
		end
		if self.bossLootUntil and os.clock() < self.bossLootUntil then
			self.phase, self.detail = "เก็บของจากบอส", "ให้ Auto Loot ของเกมเก็บของ 5 วินาที ก่อนกลับไปฟาร์ม"
			setAutoFarm(true)
			return
		end
		if self.dungeonEntering and os.clock() < self.dungeonEntering then
			setAutoFarm(false)
			self.phase, self.detail = "รอเข้าดันเจี้ยน", "ส่งคำขอรอบฟรีแล้ว รอ Ready check และการย้ายเซิร์ฟเวอร์"
			return
		end
		self.dungeonEntering = nil
		if self:DungeonTrip() then return end
		local plan = self:SelectPlan()
		if not plan then
			setAutoFarm(false)
			self.phase, self.detail = "รอมอนสเตอร์เกิด", "ยังไม่พบตัวที่เลเวลผ่านและเข้าถึงได้ ตรวจใหม่อัตโนมัติ"
			return
		end
		if not self.plan or plan.id ~= self.plan.id or plan.model ~= self.plan.model then
			setAutoFarm(false)
			self:CancelNavigation()
			self.plan, self.fightStarted, self.configuredId = plan, nil, nil
			self.bossPotionStart = plan.boss and self:HealingSupply() or nil
			self.navProgress = nil
			self:Watch(plan.model)
		end
		local zone = self:ZonePart(plan.zone)
		local targetRoot = plan.model and plan.model.Parent and plan.model.PrimaryPart
		local goal = targetRoot and targetRoot.Position or (zone and zone.Position + Vector3.new(0, 3, 0))
		if not goal then self.phase, self.detail = "รอแผนที่โหลด", plan.zone; return end
		if not self:ConfigureTarget(plan.id) then return end
		local saved = decodeAttribute("BotJson")
		if type(saved.Exclude) ~= "table" or saved.Exclude[plan.id] == true then
			self.phase, self.detail = "รอเซิร์ฟเวอร์ยืนยัน", "กำลังตั้งตัวกรองมอนสเตอร์: " .. plan.name
			if os.clock() - (self.settingsSentAt or os.clock()) > 4 then self:SetEnabled(false); self.detail = "เซิร์ฟเวอร์ไม่ยืนยันตัวกรองมอนสเตอร์ ลองเริ่มอีกครั้ง" end
			return
		end
		if not self.fightStarted and (root.Position - goal).Magnitude > 24 then
			setAutoFarm(false)
			self.phase = plan.boss and "กำลังไปหาบอส" or "กำลังไปจุดฟาร์ม"
			self.detail = string.format("%s Lv.%d • ระยะ %.0f studs", plan.name, plan.level, (root.Position - goal).Magnitude)
			self:Walk(goal)
			return
		end
		self:CancelNavigation()
		if not targetRoot then self.phase, self.detail = "รอบอสแสดงตัว", plan.name; return end
		self.fightStarted = self.fightStarted or os.clock()
		setAutoFarm(true)
		local hp = plan.model:GetAttribute("HP") or 0
		self.phase = plan.boss and "กำลังล่าบอส" or "กำลังฟาร์ม"
		self.detail = string.format("%s Lv.%d • HP %s\n%s", plan.name, plan.level, comma(hp), plan.boss and "จบบอสแล้วกลับไปจุดฟาร์มอัตโนมัติ" or "ติดตามเลือดและเวลาฆ่า เพื่อปรับความยาก")
		local deadline = plan.boss and 180 or 35
		if os.clock() - self.fightStarted > deadline then
			self.cooldowns[plan.id] = os.clock() + (plan.boss and 600 or 120)
			if plan.boss then self.failedBossSpawns[plan.id], self.lastDecision = plan.spawnKey, "พัก " .. plan.name .. ": ต่อสู้นานเกิน 3 นาที" end
			if not plan.boss then self.levelCap, self.levelCapUntil = math.max(1, plan.level - 1), os.clock() + 120 end
			self.plan = nil
			setAutoFarm(false)
			self.phase, self.detail = "ปรับเป้าหมายลง", "ฆ่าช้าเกินไป พักเป้าหมายนี้ 2 นาที แล้วเลือกตัวรองลงมา"
		end
	end

	function director:RefreshUI()
		self:ApplyEquip()
		if self.travel.label then self.travel.label.Text = self.travel.status end
		if os.clock() - (self.lastTravelRefresh or -10) > 3 then
			self.lastTravelRefresh = os.clock()
			for id, row in pairs(self.travel.rows or {}) do
				local allowed, reason = true, nil
				if id ~= "Town" then allowed, reason = self:CanAccess(id) end
				row.reason.Text = allowed and ((MapData[id] and MapData[id].LevelText or "ทุกเลเวล") .. " • ไปได้") or tostring(reason)
				local pillar, cost = self:TravelRoute(id)
				row.button.Text = allowed and (pillar and (cost > 0 and comma(cost) or "วาร์ปฟรี") or "เดินไป") or "ล็อก"
				if allowed and cost > 0 then row.reason.Text ..= " • วาร์ป " .. comma(cost) .. " Silver" end
				row.button.BackgroundColor3 = allowed and Color3.fromRGB(35, 78, 45) or COLORS.Card2
			end
			local bookmark = self.travel.bookmark
			if bookmark and self.travel.backButton then
				local pillar, cost = self:TravelRoute(bookmark.zone, bookmark.position)
				self.travel.backButton.Text = cost > 0 and ("กลับจุดเดิม • " .. comma(cost) .. " Silver") or "กลับจุดก่อนเดินทาง"
			end
		end
		self.ui.title.Text, self.ui.detail.Text = self.phase, self.detail
		self.ui.start.Text = self.enabled and "หยุดการทำงาน" or "เริ่มฟาร์มอัตโนมัติ"
		self.ui.start.BackgroundColor3 = self.enabled and COLORS.Red or COLORS.Green
		local minutes = math.max(1 / 60, (os.clock() - (self.startedAt > 0 and self.startedAt or os.clock())) / 60)
		local gained = self.startedAt > 0 and math.max(0, self:TotalExp(player:GetAttribute("Level"), player:GetAttribute("Exp")) - (self.startTotalExp or 0)) or 0
		local silver = self.startedAt > 0 and (tonumber(player:GetAttribute("Silver")) or 0) - self.startSilver or 0
		self.ui.stats.Text = string.format("ฆ่า %d ตัว  •  EXP +%s  •  %s EXP/นาที  •  Silver %+d", self.kills, comma(gained), comma(gained / minutes), silver)
		local _, dungeon = self:DungeonStatus()
		local boss = bosses[1]
		for index = #bosses, 1, -1 do
			if (MonsterData[bosses[index].id] or {}).Level and MonsterData[bosses[index].id].Level <= (player:GetAttribute("Level") or 1) and self:CanAccess(bosses[index].map) then boss = bosses[index]; break end
		end
		local remaining = math.max(0, (workspace:GetAttribute("BossNext_" .. boss.id) or 0) - serverNow())
		local bossText = workspace:GetAttribute("BossAlive_" .. boss.id) == true and (boss.name .. ": เกิดแล้ว") or string.format("%s: %02d:%02d", boss.name, math.floor(remaining / 60), math.floor(remaining % 60))
		self.ui.note.Text = bossText .. "\n" .. dungeon
		self.ui.note.Text ..= "\nAuto Equip: " .. (player:GetAttribute("AutoEquip") == true and "ON • เลือก CP สูงสุดโดยเกม" or "OFF / รอยืนยัน")
		for _, node in ipairs(nodes) do
			local minimum = tonumber(tostring(node.data.LevelText):match("%d+")) or math.huge
			local allowed, reason = self:CanAccess(node.id)
			if not allowed and minimum <= (player:GetAttribute("Level") or 1) then
				self.ui.note.Text ..= "\nโซนถัดไป: " .. tostring(reason)
				break
			end
		end
		if self.lastDecision then self.ui.note.Text ..= "\n" .. self.lastDecision end
		state.dungeonStatus = dungeon
	end

	director:Preview()
	director:RefreshUI()
	task.spawn(function()
		while runtime.alive do
			local ok, message = xpcall(function() director:Tick(); director:RefreshUI() end, debug.traceback)
			if not ok then
				director.lastError = tostring(message)
				pcall(function() director:SetEnabled(false) end)
				director.phase, director.detail = "หยุดเพราะข้อผิดพลาด", "ตรวจ runtime.manager.lastError เพื่อดูรายละเอียด"
				pcall(function() director:RefreshUI() end)
			end
			task.wait(0.5)
		end
	end)
end

do
	local bestId, bestDef, bestScore, bestMonster = bestRepeatQuest()
	local junkCount, junkValue = junkInfo()
	local requiredRemotes = {"QuestAction", "RewardAction", "RedeemCode", "ShopSellJunk", "DailyClaim", "MailAction", "BattlePassAction", "AchieveAction"}
	local remoteChecks = {}
	for _, name in ipairs(requiredRemotes) do remoteChecks[name] = remote(name) ~= nil end
	runtime.selfTest = {
		modules = {quest = next(questDefinitions()) ~= nil, reward = next(RewardData) ~= nil, achievement = next(AchievementData) ~= nil, item = next(ItemData) ~= nil},
		remotes = remoteChecks,
		planner = {id = bestId, name = bestMonster.Name or (bestDef and bestDef.Name), score = bestScore},
		junk = {count = junkCount, value = junkValue},
		pages = 8,
	}
end

-- Window behavior
local orb = new("TextButton", {
	Name = "OpenButton", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -18, 0.5, 0),
	Size = UDim2.fromOffset(52, 52), BackgroundColor3 = COLORS.Blue, BorderSizePixel = 0,
	Text = "F", TextColor3 = Color3.new(1, 1, 1), TextSize = 20, Font = Enum.Font.GothamBlack,
	Visible = false, AutoButtonColor = false,
}, gui)
corner(orb, 16)
stroke(orb, COLORS.Cyan, 0.15, 2)

local function setVisible(value)
	main.Visible = value
	shadow.Visible = value
	orb.Visible = not value
end
track(closeButton.MouseButton1Click:Connect(function() setVisible(false) end))
track(minimizeButton.MouseButton1Click:Connect(function() setVisible(false) end))
track(orb.MouseButton1Click:Connect(function() setVisible(true) end))
track(UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.RightControl then setVisible(not main.Visible) end
end))

task.delay(2.5, function()
	if runtime.alive and state.autoCodes and not state.codesProcessed then
		state.codesProcessed = true
		runCodeQueue(verifiedCodes)
	end
end)

-- Dragging
do
	local dragging, dragStart, startPos
	track(header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = input.Position; startPos = main.Position
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			main.Position = clampWindowPosition(UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y))
			shadow.Position = main.Position
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))
end

-- Live status loop
task.spawn(function()
	local slowTick = 0
	while runtime.alive do
		local level = tonumber(player:GetAttribute("Level")) or 0
		local job = tostring(player:GetAttribute("Job") or "Adventurer")
		local silver = tonumber(player:GetAttribute("Silver")) or 0
		headerStatus.Text = string.format("● LIVE  •  Lv.%d  •  %s Silver", level, comma(silver))
		headerStatus.TextColor3 = COLORS.Green
		profileLevel.Text = "Lv. " .. tostring(level) .. "  •  " .. job
		profileInfo.Text = comma(silver) .. " Silver"
		summaryTitle.Text = player.DisplayName .. "  •  Lv." .. tostring(level) .. " " .. job
		summaryStats.Text = comma(silver) .. " Silver   •   " .. comma(player:GetAttribute("Exp") or 0) .. " EXP"
		summaryMode.Text = (player:GetAttribute("AutoOn") == true and "AUTO FARM: ทำงาน" or "AUTO FARM: หยุด") .. "   •   Auto Skill: " .. (player:GetAttribute("AutoSkill") == true and "ON" or "OFF")
		local bestId = bestRepeatQuest()
		insightPill.Text = bestId and ("Best Quest: " .. bestId) or "กำลังคำนวณเควสต์"
		boxStatus.Text = player:GetAttribute("OptAutoOpenBox") == true and "ON" or "OFF"
		boxStatus.TextColor3 = player:GetAttribute("OptAutoOpenBox") == true and COLORS.Green or COLORS.Sub

		local rushEnds = tonumber(player:GetAttribute("RushEndsAt")) or 0
		local rushLeft = math.max(0, rushEnds - serverNow())
		local combo = tonumber(player:GetAttribute("RushCombo")) or 0
		if rushLeft > 0 then
			rushStatus.Text = string.format("ACTIVE %.0fs", rushLeft)
			rushStatus.BackgroundColor3 = Color3.fromRGB(111, 53, 66)
			rushStatus.TextColor3 = Color3.fromRGB(255, 191, 103)
			if state.rushAssist and player:GetAttribute("AutoOn") ~= true then setAutoFarm(true) end
		else
			rushStatus.Text = string.format("Combo %d/100", combo)
			rushStatus.BackgroundColor3 = COLORS.Card2
			rushStatus.TextColor3 = COLORS.Sub
		end

		dungeonStatusLabel.Text = state.dungeonStatus
		rewardStatusLabel.Text = state.rewardStatus
		updateCodeStatus()
		local items = decodeAttribute("ItemsJson")
		gearStatus.Text = string.format("Silver %s   •   Refine Stone %d   •   Lock Charm %d", comma(silver), itemCount(items, "refine_stone"), itemCount(items, "lock_charm"))
		local junkCount, junkValue = junkInfo()
		junkStatus.Text = string.format("Junk %d ชิ้น • ~%s Gold • Auto ที่ %d+", junkCount, comma(junkValue), state.junkThreshold)

		for _, entry in pairs(bossLabels) do
			local alive = workspace:GetAttribute("BossAlive_" .. entry.boss.id) == true
			local nextAt = tonumber(workspace:GetAttribute("BossNext_" .. entry.boss.id)) or 0
			if alive then
				entry.label.Text = "พร้อมล่า"
				entry.label.BackgroundColor3 = Color3.fromRGB(39, 91, 69)
				entry.label.TextColor3 = COLORS.Green
				if not entry.wasAlive and state.bossAlerts then toast(entry.boss.name .. " เกิดแล้ว!", "good") end
			else
				local left = math.max(0, nextAt - serverNow())
				entry.label.Text = left > 0 and string.format("%02d:%02d", math.floor(left / 60), math.floor(left % 60)) or "กำลังเกิด"
				entry.label.BackgroundColor3 = Color3.fromRGB(70, 48, 58)
				entry.label.TextColor3 = COLORS.Orange
			end
			entry.wasAlive = alive
		end

		for _, refresh in ipairs(refreshers) do pcall(refresh) end
		slowTick += 1
		if slowTick % 3 == 0 then pcall(processQuests) end
		if slowTick % 5 == 0 then pcall(processRewards) end
		if slowTick % 10 == 0 and state.autoSellJunk then pcall(sellJunk, false) end
		task.wait(1)
	end
end)

function runtime.Destroy()
	if not runtime.alive then return end
	if director.enabled then pcall(function() director:SetEnabled(false) end) end
	if director.travel.active then pcall(function() director:CancelTrip() end) end
	if director.observer then director.observer:Disconnect() end
	runtime.alive = false
	for _, connection in ipairs(runtime.connections) do pcall(function() connection:Disconnect() end) end
	if gui and gui.Parent then gui:Destroy() end
	if env.__CodexFarmCenter == runtime then env.__CodexFarmCenter = nil end
end

selectPage("play")
toast("Farm Control Center พร้อมใช้งาน", "good")

end, debug.traceback)
if not __codexOk then
	getgenv().__CodexFarmCenterError = tostring(__codexError)
end
