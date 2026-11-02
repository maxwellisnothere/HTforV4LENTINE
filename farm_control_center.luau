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

local runtime = {alive = true, connections = {}, version = "3.3.2-boss-entry"}
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

local function displayError(value)
	local first = tostring(value):match("[^\r\n]+") or "ไม่ทราบสาเหตุ"
	return (first:gsub("^.-:%d+:%s*", ""))
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
	play = "BOSS ASSISTANT  /  เริ่มที่นี่",
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
	enabled = false, huntBosses = true, runDungeons = false,
	selectedBoss = "terra_colossus", hopMode = false, sellTrip = false,
	healAt = 70, potionBudget = 50, retreatAt = 25, potionChoice = "current", fightMinutes = 0,
	autoPickup = true, boxRadius = 70, pickupStatus = "รอกล่องในระยะ 70 studs", lootAttempts = setmetatable({}, {__mode = "k"}),
	hop = {visited = {}, count = 0, max = 10, nextAt = 0},
	equipBest = true, travel = {active = false, token = 0, status = "เลือกด่านที่ต้องการ", bookmark = previousDirector and previousDirector.travel and previousDirector.travel.bookmark},
	phase = "พร้อมเฝ้าบอส", detail = "ยืนจุดฟาร์ม เปิด Auto ของเกม แล้วกดเริ่มเฝ้าบอส",
	plan = nil, cooldowns = {}, blockedZones = {}, kills = 0,
	startedAt = 0, startExp = 0, startSilver = 0,
	ui = {}, navToken = 0,
	failedBossSpawns = previousDirector and table.clone(previousDirector.failedBossSpawns or {}) or {},
	bossSpawnKeys = previousDirector and table.clone(previousDirector.bossSpawnKeys or {}) or {},
}
runtime.manager = director
for _, key in ipairs({"healAt", "potionBudget", "retreatAt", "potionChoice", "fightMinutes", "autoPickup", "selectedBoss"}) do
	if previousDirector and previousDirector[key] ~= nil then director[key] = previousDirector[key] end
end

local function menuFire(name, value)
	local event = player:FindFirstChild("LumiMenuToggle")
	if event and event:IsA("BindableEvent") then
		local setIdentity = rawget(env, "setthreadidentity") or rawget(env, "setidentity")
		local getIdentity = rawget(env, "getthreadidentity") or rawget(env, "getidentity")
		local original = type(getIdentity) == "function" and getIdentity() or nil
		if original and type(setIdentity) == "function" then setIdentity(2) end
		local ok = pcall(event.Fire, event, name, value)
		if original and type(setIdentity) == "function" then setIdentity(original) end
		return ok
	end
	return false
end

local lastAutoRequest = -10
local function setAutoFarm(enabled)
	if (player:GetAttribute("AutoOn") == true) ~= enabled and os.clock() - lastAutoRequest > 1 then
		lastAutoRequest = os.clock()
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

makeNav("play", "เฝ้าบอส", 1, ASSETS.Overview)
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
		BackgroundTransparency = 1, Text = "พร้อมเฝ้าบอส", TextSize = 20,
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
		BackgroundColor3 = COLORS.Green, BorderSizePixel = 0, Text = "เริ่มเฝ้าบอส",
		TextSize = 15, TextColor3 = COLORS.Bg, Font = Enum.Font.GothamBold, AutoButtonColor = false,
	}, hero)
	corner(director.ui.start, 7)
	local rescan = new("TextButton", {
		Name = "Rescan", Position = UDim2.new(0.64, 2, 0, 98), Size = UDim2.new(0.36, -16, 0, 36),
		BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0, Text = "จำจุดฟาร์มนี้",
		TextSize = 13, TextColor3 = COLORS.Text, Font = Enum.Font.GothamMedium,
	}, hero)
	corner(rescan, 7)
	track(director.ui.start.MouseButton1Click:Connect(function() director:SetEnabled(not director.enabled) end))
	track(rescan.MouseButton1Click:Connect(function() director:SaveHome() end))
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
		track(button.MouseButton1Click:Connect(function()
			if key == "hopMode" then director:SetHopMode(not director.hopMode); refresh(); return end
			director[key] = not director[key]; refresh()
			if key == "autoPickup" and not director.autoPickup then director:CancelBoxTrip(true, "ปิดเดินเก็บกล่องแล้ว") end
		end))
		table.insert(refreshers, refresh)
		refresh()
	end
	option("แวะล่าบอสเมื่อเกิด แล้วกลับมาฟาร์ม", "huntBosses")
	option("ลงดันเมื่อเลเวลผ่านและมีรอบฟรี", "runDungeons")
	option("กลับเมืองขาย Junk แล้วกลับจุดเดิม", "sellTrip")
	option("ล่าบอสข้ามเซิร์ฟ (สูงสุด 10 ครั้ง/รอบ)", "hopMode")
	option("ใส่อุปกรณ์ที่ CP สูงสุดอัตโนมัติ", "equipBest")
	option("เดินเปิดกล่อง E (70 studs) และเก็บของ", "autoPickup")
	local sustain = makeCard(playPage, 224)
	sustain.Name = "BossSustain"
	titleLabel(sustain, "ยาและงบต่อบอส", "ตั้งก่อนออกทริป • งบ 0 = ไม่ใช้ยา • เวลา 0 = ไม่จำกัด")
	local function numberSetting(label, key, minimum, maximum, step, y)
		new("TextLabel", {Position = UDim2.fromOffset(12, y), Size = UDim2.new(1, -142, 0, 28),
			BackgroundTransparency = 1, Text = label, TextColor3 = COLORS.Text, TextSize = 13,
			Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left}, sustain)
		local input = new("TextBox", {Name = key, Position = UDim2.new(1, -124, 0, y), Size = UDim2.fromOffset(110, 28),
			BackgroundColor3 = COLORS.Card2, TextColor3 = COLORS.Cyan, BorderSizePixel = 0, ClearTextOnFocus = false,
			Text = tostring(director[key]), TextSize = 14, Font = Enum.Font.GothamBold}, sustain)
		corner(input, 6)
		track(input.FocusLost:Connect(function()
			if director.session then toast("จบทริปก่อนเปลี่ยนค่าการต่อสู้", "info") else
				local value = tonumber(input.Text)
				if value and value == value then director[key] = math.clamp(math.floor(value / step + 0.5) * step, minimum, maximum) end
			end
			input.Text = tostring(director[key])
		end))
		table.insert(refreshers, function() if not input:IsFocused() then input.Text = tostring(director[key]) end end)
	end
	numberSetting("ใช้ยาเมื่อ HP ต่ำกว่า % (เกมสูงสุด 90)", "healAt", 5, 90, 5, 60)
	numberSetting("ยอมใช้ยาสูงสุดกี่ขวดต่อบอส", "potionBudget", 0, 9999, 1, 92)
	numberSetting("ยาหมดงบ/หมดตัว และ HP ต่ำกว่า % ให้ถอย", "retreatAt", 1, 80, 1, 124)
	numberSetting("เวลาต่อบอส (นาที, 0 = สู้ต่อเรื่อย ๆ)", "fightMinutes", 0, 60, 1, 156)
	local choosePotion = new("TextButton", {Name = "PotionChoice", Position = UDim2.fromOffset(12, 190),
		Size = UDim2.new(1, -26, 0, 26), BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0,
		Text = "", TextSize = 13, TextColor3 = COLORS.Cyan, Font = Enum.Font.GothamBold}, sustain)
	corner(choosePotion, 6)
	local potionChoices = {"current", "red_potion", "red_potion_m", "white_potion"}
	local function potionText()
		choosePotion.Text = "ยา: " .. (director.potionChoice == "current" and "ตามช่องยาที่ตั้งไว้ในเกม" or tostring((ItemData[director.potionChoice] or {}).Name or director.potionChoice)) .. "  ›"
	end
	track(choosePotion.MouseButton1Click:Connect(function()
		if director.session then toast("จบทริปก่อนเปลี่ยนยา", "info"); return end
		local index = table.find(potionChoices, director.potionChoice) or 1
		director.potionChoice = potionChoices[index % #potionChoices + 1]; potionText()
	end))
	table.insert(refreshers, potionText); potionText()
	local info = makeCard(playPage, 164)
	info.Name = "Telemetry"
	director.ui.stats = new("TextLabel", {
		Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 24),
		BackgroundTransparency = 1, Text = "กำลังตรวจข้อมูล...", TextSize = 13,
		TextColor3 = COLORS.Cyan, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
	}, info)
	director.ui.note = new("TextLabel", {
		Position = UDim2.fromOffset(14, 37), Size = UDim2.new(1, -28, 0, 122),
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
	function() return director.equipBest end, function(v) director.equipBest = v; director:ApplyEquip() end)
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
local bossChoices = {}

local bossIntro = makeCard(bossPage, 87, Color3.fromRGB(34, 31, 53))
titleLabel(bossIntro, "BOSS RADAR", "บอสทุกตัวตั้ง Respawn 600 วินาที (10 นาที) • แจ้งเตือนเมื่อบอสกลับมาเกิด แต่จะไม่วาร์ปฝืนประตูเลเวล")
makeToggle(bossPage, "แจ้งเตือนบอสเกิด", "เตือนในหน้าต่างนี้ทันทีเมื่อสถานะเปลี่ยนจากรอเป็นพร้อมล่า", COLORS.Red,
	function() return state.bossAlerts end, function(v) state.bossAlerts = v end)

for index, boss in ipairs(bosses) do
	local card = makeCard(bossPage, 102)
	card.Name = boss.map
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
	local choose = new("TextButton", {
		Name = "Select", Position = UDim2.fromOffset(15, 66), Size = UDim2.new(1, -30, 0, 27),
		Text = "เลือกบอสตัวนี้", TextSize = 13, Font = Enum.Font.GothamBold,
		TextColor3 = COLORS.Text, BackgroundColor3 = COLORS.Card2, BorderSizePixel = 0,
	}, card)
	corner(choose, 7)
	bossChoices[boss.id] = choose
	track(choose.MouseButton1Click:Connect(function()
		if director.enabled then toast("หยุดเฝ้าบอสก่อนเปลี่ยนเป้าหมาย", "info"); return end
		director.selectedBoss = boss.id
		director:Preview()
	end))
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
	for _, object in ipairs(workspace:QueryDescendants('#merchant, #Merchant, Model[$NpcId = "merchant"]')) do
		if object:IsA("Model") then
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

	function director:SetNativeAuto(value)
		setAutoFarm(value)
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

	function director:RetreatReason(healthFraction, plan, used, available, budget, retreatPercent)
		if not plan or not plan.boss then return healthFraction < 0.35 and "เลือดต่ำ" or nil end
		budget = budget or self.potionBudget or 50
		retreatPercent = retreatPercent or self.retreatAt or 25
		local exhausted = (used or 0) >= budget
		if (exhausted or (available or 0) <= 0) and healthFraction * 100 <= retreatPercent then
			return exhausted and ("ใช้ยาครบงบ " .. budget .. " ขวด และเลือดต่ำ") or "ยาที่เลือกหมดและเลือดต่ำ"
		end
		return nil
	end

	function director:HealingSnapshot()
		local items, out = decodeAttribute("ItemsJson"), {}
		for id, definition in pairs(ItemData) do
			if type(definition) == "table" and definition.Kind == "usable"
				and ((tonumber(definition.HealMin) or 0) > 0 or (tonumber(definition.HealPercent) or 0) > 0) then out[id] = itemCount(items, id) end
		end
		return out
	end

	function director:ConsumedPotions(before, after)
		local used = 0
		for id, value in pairs(before or {}) do used += math.max(0, value - (after[id] or 0)) end
		return used
	end

	function director:SetHealthAuto(percent)
		local event = remote("SetPotionAuto")
		if event then event:FireServer("hp", percent) end
	end

	function director:UpdatePotionUsage()
		local session = self.session
		if not session or session.kind ~= "boss" or not session.potionChanged or session.restored then return end
		local snapshot = self:HealingSnapshot()
		session.potionsUsed = (session.potionsUsed or 0) + self:ConsumedPotions(session.potionSnapshot, snapshot)
		session.potionSnapshot = snapshot
		if session.potionsUsed >= session.potionBudget and not session.potionCapped then
			session.potionCapped = true
			session.potionSentAt = os.clock()
			self:SetHealthAuto(0)
		end
	end

	function director:PreparePotions(session)
		if session.potionChanged then return true end
		local auto, slot = remote("SetPotionAuto"), remote("SetPotionSlot")
		if not auto or not slot then return false end
		session.potionPercent = tonumber(player:GetAttribute("PotionHpPercent")) or 0
		session.potionSlot = player:GetAttribute("PotionHpNow")
		session.selectedPotion = self.potionChoice == "current" and session.potionSlot or self.potionChoice
		session.potionBudget, session.retreatPercent = self.potionBudget, self.retreatAt
		session.healAt, session.fightMinutes = self.healAt, self.fightMinutes
		session.potionsUsed, session.potionSnapshot = 0, self:HealingSnapshot()
		session.potionChanged, session.potionSentAt = true, os.clock()
		if self.potionChoice ~= "current" then slot:FireServer("hp", self.potionChoice) end
		auto:FireServer("hp", session.potionBudget > 0 and session.healAt or 0)
		session.potionCapped = session.potionBudget == 0
		return true
	end

	track(player:GetAttributeChangedSignal("ItemsJson"):Connect(function() director:UpdatePotionUsage() end))

	function director:BossPresence(alive, nextAt, now, model)
		if model and model.Parent and (tonumber(model:GetAttribute("HP")) or 0) > 0 then return "alive", 0 end
		local remaining = math.max(0, (tonumber(nextAt) or 0) - now)
		if remaining > 0 then return "countdown", remaining end
		-- No timer is not proof of death; enter the room and inspect it.
		return "scout", 0
	end

	function director:CurrentBossPresence(boss)
		return self:BossPresence(workspace:GetAttribute("BossAlive_" .. boss.id), workspace:GetAttribute("BossNext_" .. boss.id), serverNow(), self:Monster(boss.id))
	end

	function director:CanPickup(owner, freeAt, now, delay, ownerTime)
		freeAt = tonumber(freeAt) or 0
		if freeAt > 0 and now - (freeAt - ownerTime) < delay then return false end
		return not owner or owner == 0 or owner == player.UserId or freeAt <= now
	end

	function director:LootIsGone(object, kind)
		return not object.Parent or not CollectionService:HasTag(object, kind) or object:GetAttribute("Opened") == true
			or (kind == "LootBox" and object:GetAttribute("OpenTitle") ~= nil)
	end

	function director:ConfirmPickup(object, kind)
		local attempt = self.lootAttempts[object] or {}
		if attempt.confirmed then return end
		attempt.confirmed = true
		self.lootAttempts[object] = attempt
		self.pickupConfirmed = (self.pickupConfirmed or 0) + 1
		if kind == "LootBox" then self.boxesOpened = (self.boxesOpened or 0) + 1 else self.dropsPicked = (self.dropsPicked or 0) + 1 end
		self.pickupStatus = "เปิดกล่อง " .. (self.boxesOpened or 0) .. " • เก็บของ " .. (self.dropsPicked or 0) .. " ครั้ง"
	end

	function director:CanWalkToBox(distance, height, busy, autoOn)
		return not busy and autoOn == true and distance > 6 and distance <= (self.boxRadius or 70) and math.abs(height) <= 12
	end

	function director:CancelBoxTrip(resumeAuto, reason)
		local trip = self.lootTrip
		if not trip then return end
		self.lootTrip = nil
		self:CancelNavigation()
		local root, humanoid = self:Character()
		if root and humanoid then humanoid:MoveTo(root.Position) end
		self.boxSearchAfter = os.clock() + 3
		self.pickupStatus = reason or "ยกเลิกเดินเก็บกล่องแล้ว"
		if resumeAuto then self:SetNativeAuto(trip.native) end
	end

	function director:StartBoxTrip(object)
		local root = self:Character()
		if not root then return end
		self:CancelNavigation()
		self.lootTrip = {active = true, object = object, origin = root.Position, native = player:GetAttribute("AutoOn") == true,
			stage = "approach", startedAt = os.clock(), deadline = os.clock() + 35, attempts = 0,
			startDistance = (root.Position - object.Position).Magnitude}
		self:SetNativeAuto(false)
		self.pickupStatus = "พัก Auto แล้วเดินไปเปิดกล่อง"
	end

	function director:ReturnFromBox(reason)
		local trip = self.lootTrip
		if not trip then return end
		self:CancelNavigation()
		trip.stage, trip.deadline, trip.result = "return", os.clock() + 35, reason
		self.pickupStatus = reason .. " • กำลังกลับจุดฟาร์ม"
	end

	function director:StepBoxTrip()
		local trip = self.lootTrip
		if not trip then return end
		local root, humanoid = self:Character()
		if not self.autoPickup or not root or not humanoid or humanoid.Health <= 0 then self:CancelBoxTrip(false); return end
		if self.travel.active or self.session or self.hop.busy or self.hop.pending then self:CancelBoxTrip(false); return end
		if player:GetAttribute("AutoOn") == true then
			self:SetNativeAuto(false)
			self:CancelNavigation()
			self.pickupStatus = "พัก Auto ก่อนเดินไปกล่อง"
			if os.clock() - trip.startedAt > 5 and trip.stage == "approach" and not trip.walkStarted then
				self:CancelBoxTrip(true, "พัก Auto ไม่สำเร็จ ลองเปิดสคริปต์ใหม่")
			end
			return
		end
		if self.navError then
			if trip.stage == "return" then self:CancelBoxTrip(true, "ทางกลับกล่องติดขัด • คืน Auto แล้ว")
			else self:ReturnFromBox("ไปกล่องไม่ถึง") end
			return
		end
		if os.clock() >= trip.deadline then
			if trip.stage == "return" then self:CancelBoxTrip(true, "กลับจากกล่องหมดเวลา • คืน Auto แล้ว")
			else self.lootAttempts[trip.object] = {nextAt = os.clock() + 60}; self:ReturnFromBox("ไปกล่องหมดเวลา") end
			return
		end
		if trip.stage == "return" then
			self.pickupStatus = trip.result .. string.format(" • กลับจุดฟาร์ม %.0f studs", (root.Position - trip.origin).Magnitude)
			if self:Walk(trip.origin, 5) then
				self.lastBoxTrip = {opened = trip.opened == true, distance = (root.Position - trip.origin).Magnitude,
					approachDistance = trip.approachDistance, startDistance = trip.startDistance, requests = trip.attempts,
					result = trip.result, attributes = trip.object:GetAttributes()}
				self:CancelBoxTrip(true, trip.result .. " • กลับจุดฟาร์มและคืน Auto แล้ว")
			end
			return
		end
		if self:LootIsGone(trip.object, "LootBox") then
			if trip.attempts > 0 then
				trip.opened = true
				self:ConfirmPickup(trip.object, "LootBox")
				self:ReturnFromBox("กล่องเปิด/เปลี่ยนสถานะแล้ว")
			else self:ReturnFromBox("กล่องหายก่อนถึง") end
			return
		end
		local distance = (root.Position - trip.object.Position).Magnitude
		if trip.stage == "approach" then
			trip.walkStarted = true
			self.pickupStatus = string.format("เดินไปเปิด %s • %.0f studs", tostring(trip.object:GetAttribute("Label") or trip.object.Name), distance)
			if self:Walk(trip.object.Position, 5) then
				trip.stage, trip.deadline, trip.approachDistance = "open", os.clock() + 6, distance
			end
			return
		end
		if distance > 7 then self:ReturnFromBox("กล่องอยู่นอกระยะเปิด"); return end
		local event = remote("OpenLootBox")
		if not event then self:ReturnFromBox("ไม่พบระบบเปิดกล่องของเกม"); return end
		if trip.attempts < 3 and os.clock() >= (trip.nextRequestAt or 0) then
			trip.attempts += 1
			trip.nextRequestAt = os.clock() + 1
			local prompt = trip.object:FindFirstChild("OpenPrompt")
			if not prompt and trip.object.Parent then
				prompt = trip.object.Parent:QueryDescendants("ProximityPrompt#OpenPrompt")[1]
			end
			if prompt and prompt.Enabled then
				local fire = rawget(env, "fireproximityprompt")
				if type(fire) == "function" then fire(prompt) else
					prompt:InputHoldBegin()
					task.delay(prompt.HoldDuration + 0.1, function() if runtime.alive and self.lootTrip == trip and prompt.Parent then prompt:InputHoldEnd() end end)
				end
			else event:FireServer(trip.object) end
			self.pickupStatus = "กดเปิดกล่องในระยะแล้ว • รอเกมยืนยัน"
		end
	end

	function director:PickupNearby()
		if self.lootTrip then self:StepBoxTrip(); return end
		if not self.autoPickup then return end
		local root, humanoid = self:Character()
		if not root or not humanoid or humanoid.Health <= 0 then return end
		local now, candidate, kind, nearest, walkBox, walkDistance = serverNow(), nil, nil, math.huge, nil, math.huge
		local busy = self.travel.active or self.session ~= nil or self.hop.busy or self.hop.pending or self.navBusy
		for _, tag in ipairs({"LootBox", "Drop"}) do
			for _, object in ipairs(CollectionService:GetTagged(tag)) do
				if not object:IsA("BasePart") or not object.Parent or object:GetAttribute("LumiHiddenLocal") then continue end
				local range = tag == "Drop" and (tonumber(GameConfig.DropPickupReach) or 7) or 7
				local distance = (object.Position - root.Position).Magnitude
				local attempt = self.lootAttempts[object]
				if attempt and (attempt.confirmed or os.clock() < (attempt.nextAt or 0)) then continue end
				if not self:CanPickup(object:GetAttribute("OwnerUserId"), object:GetAttribute("FreeAt"), now,
					tag == "Drop" and (tonumber(GameConfig.DropPickupDelay) or 0) or 0, tonumber(GameConfig.DropOwnerTime) or 15) then continue end
				if self:LootIsGone(object, tag) then continue end
				if tag == "LootBox" and distance < walkDistance and os.clock() >= (self.boxSearchAfter or 0)
					and self:CanWalkToBox(distance, object.Position.Y - root.Position.Y, busy, player:GetAttribute("AutoOn")) then
					walkBox, walkDistance = object, distance
				end
				if distance <= range and distance < nearest then candidate, kind, nearest = object, tag, distance end
			end
		end
		if walkBox and kind ~= "LootBox" then self:StartBoxTrip(walkBox); return end
		if not candidate then
			if walkBox then self:StartBoxTrip(walkBox) end
			return
		end
		local event = remote(kind == "LootBox" and "OpenLootBox" or "PickupDrop")
		if not event then return end
		local attempt = self.lootAttempts[candidate] or {count = 0}
		attempt.count += 1
		attempt.nextAt = os.clock() + (attempt.count % 3 == 0 and 15 or 1)
		self.lootAttempts[candidate] = attempt
		if kind == "LootBox" then event:FireServer(candidate) else event:FireServer() end
		self.pickupStatus = kind == "LootBox" and "ส่งเปิดกล่อง E ในระยะแล้ว" or "ส่งเก็บของในระยะแล้ว"
		task.delay(0.8, function()
			if runtime.alive and self:LootIsGone(candidate, kind) then
				self:ConfirmPickup(candidate, kind)
			end
		end)
	end

	function director:SetHopMode(value)
		if self.session and self.session.stage ~= "hop" then toast("จบทริปหรือกดหยุดก่อนเปลี่ยนโหมดข้ามเซิร์ฟ", "info"); return end
		self.hopMode = value
		if not value then
			self.hop.token = (self.hop.token or 0) + 1
			self.hop.busy = false
			if self.session then self:BeginReturn("ปิดโหมดข้ามเซิร์ฟ กลับจุดเดิม") end
		elseif not self.enabled then self:SetEnabled(true)
		else self.hop.nextAt = math.min(self.hop.nextAt or 0, os.clock() + 3) end
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
		if not definition then
			state.dungeonStatus = reason; self.dungeonTrip = false; self.lastDungeonAttempt = os.clock()
			if self.session and self.session.kind == "dungeon" then self:BeginReturn(reason) end
			return
		end
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
			self:Walk(torso.Position, math.max(3, prompt.MaxActivationDistance - 1))
			if self.navError then self.dungeonTrip = false; state.dungeonStatus = "เดินไป GateKeeper ไม่ถึง"; return false end
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
			state.dungeonStatus = self.detail
		end
		return self.dungeonTrip
	end

	if dungeonPrompt then
		track(dungeonPrompt.OnClientEvent:Connect(function(action, data)
			if action ~= "ready" or type(data) ~= "table" or type(data.Id) ~= "string" then return end
			if not (state.autoDungeon or (director.enabled and director.runDungeons)) or not director.dungeonRequested then return end
			if os.clock() - (director.lastDungeonRequest or 0) > 20 then return end
			director.dungeonRequested = nil
			if remote("DungeonAction") then remote("DungeonAction"):FireServer("ready", data.Id, true) end
		end))
	end

	function director:SelectedDefinition()
		for _, boss in ipairs(bosses) do if boss.id == self.selectedBoss then return boss end end
	end

	function director:BossEngageDistance(size)
		return math.clamp((tonumber(size) or 16) / 2 + 16, 24, 100)
	end

	function director:BossNeedsApproach(position, target, size)
		local delta = position - target
		return Vector2.new(delta.X, delta.Z).Magnitude > self:BossEngageDistance(size)
	end

	function director:BossEntryPoint(zone, fromPosition, size)
		local delta = Vector3.new(fromPosition.X - zone.Position.X, 0, fromPosition.Z - zone.Position.Z)
		local direction = delta.Magnitude > 0.01 and delta.Unit or Vector3.new(0, 0, 1)
		local inset = math.min(math.max(0, math.min(zone.Size.X, zone.Size.Z) / 2 - 12), self:BossEngageDistance(size) + 12)
		return zone.Position + direction * inset + Vector3.new(0, 3, 0)
	end

	function director:SelectPlan()
		if not self.huntBosses then return nil end
		local boss = self:SelectedDefinition()
		if not boss then return nil end
		local definition = MonsterData[boss.id] or {}
		local _, humanoid = self:Character()
		if not humanoid or humanoid.Health <= 0 then return nil end
		if (definition.Level or math.huge) > (player:GetAttribute("Level") or 1) or not self:CanAccess(boss.map) then return nil end
		local presence = self:CurrentBossPresence(boss)
		if presence == "countdown" then return nil end
		local model = self:Monster(boss.id)
		local spawnKey = model and model:GetAttribute("SpawnAt") or self.bossSpawnKeys[boss.id] or "scout"
		self.bossSpawnKeys[boss.id] = spawnKey
		if (self.cooldowns[boss.id] or 0) > os.clock() or self.failedBossSpawns[boss.id] == spawnKey then return nil end
		return {id = boss.id, zone = boss.map, name = boss.name, level = definition.Level, boss = true, model = model, spawnKey = spawnKey, scouting = presence == "scout"}
	end

	function director:CancelNavigation()
		self.navToken += 1
		self.navBusy, self.navGoal, self.navError = false, nil, nil
	end

	function director:WaypointReached(position, point, radius)
		local delta = position - point
		return Vector2.new(delta.X, delta.Z).Magnitude <= radius and math.abs(delta.Y) <= 6
	end

	function director:CanNavigateJump(humanoid)
		return humanoid.UseJumpPower and humanoid.JumpPower > 0 or not humanoid.UseJumpPower and humanoid.JumpHeight > 0
	end

	function director:NavigationDetour(position, goal)
		local delta = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
		if delta.Magnitude < 0.1 then return nil end
		local side = Vector3.new(-delta.Unit.Z, 0, delta.Unit.X)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {workspace:FindFirstChild("Map") or workspace.Terrain}
		params.RespectCanCollide = true
		local offsets = {Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0), Vector3.new(0, 0, 6), Vector3.new(0, 0, -6), side * 6, side * -6, side * 10, side * -10}
		for _, offset in ipairs(offsets) do
			local candidate = position + offset
			local clear = workspace:Blockcast(CFrame.new(position), Vector3.new(2, 4, 1), candidate - position, params) == nil
			for _, height in ipairs({-1, 0, 1.5}) do
				if workspace:Raycast(position + Vector3.new(0, height, 0), candidate - position, params) then clear = false; break end
			end
			local floor = workspace:Raycast(candidate + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
			if clear and floor and floor.Normal.Y > 0.7 then return candidate end
		end
		return nil
	end

	-- A single worker advances waypoints every frame, independently of the UI tick.
	-- Repeated Walk calls for the same goal do not restart a path.
	function director:Walk(goal, tolerance)
		tolerance = tolerance or 7
		local root, humanoid = self:Character()
		if not root or not humanoid then return false end
		if (root.Position - goal).Magnitude <= tolerance then
			if self.navBusy then self:CancelNavigation(); humanoid:MoveTo(root.Position) end
			return true
		end
		if self.navError then return false end
		if self.navBusy and self.navGoal and (self.navGoal - goal).Magnitude < 4 then return false end
		self:CancelNavigation()
		self.navBusy, self.navGoal = true, goal
		local token = self.navToken
		task.spawn(function()
			local function active()
				return runtime.alive and token == self.navToken and (self.enabled or self.travel.active or self.lootTrip ~= nil)
					and root.Parent and humanoid.Health > 0
			end
			local ok, message = pcall(function()
				for attempt = 1, 3 do
					local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = self:CanNavigateJump(humanoid), WaypointSpacing = 5})
					local computed = pcall(path.ComputeAsync, path, root.Position, goal)
					if not active() then return end
					local points = computed and path.Status == Enum.PathStatus.Success and path:GetWaypoints()
						or {{Position = goal, Action = Enum.PathWaypointAction.Walk}}
					local retry = false
					for index, point in ipairs(points) do
						if not active() then return end
						if (root.Position - goal).Magnitude <= tolerance then return end
						local radius = index == #points and tolerance or 2
						if self:WaypointReached(root.Position, point.Position, radius) then continue end
						self.navWaypoint, self.navAttempt = point.Position, attempt
						if point.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
						humanoid:MoveTo(point.Position)
						local sentAt = os.clock()
						local initialDelta = root.Position - point.Position
						local bestDistance, progressAt = Vector2.new(initialDelta.X, initialDelta.Z).Magnitude, os.clock()
						while active() and not self:WaypointReached(root.Position, point.Position, radius) do
							if (root.Position - goal).Magnitude <= tolerance then return end
							local delta = root.Position - point.Position
							local distance = Vector2.new(delta.X, delta.Z).Magnitude
							if distance < bestDistance - 0.5 then bestDistance, progressAt = distance, os.clock() end
							if os.clock() - progressAt > 4 then
								if attempt == 3 then error("เส้นทางติดขัดหลังหาเส้นทางใหม่ 3 ครั้ง") end
								local detour = self:NavigationDetour(root.Position, goal)
								if detour then
									self.lastNavDetour = detour
									local autoRotate = humanoid.AutoRotate
									humanoid.AutoRotate = false
									humanoid:MoveTo(detour)
									local detourDeadline = os.clock() + 2
									while active() and os.clock() < detourDeadline and not self:WaypointReached(root.Position, detour, 2) do RunService.Heartbeat:Wait() end
									humanoid.AutoRotate = autoRotate
								elseif self:CanNavigateJump(humanoid) then humanoid.Jump = true end
								retry = true
								break
							end
							if os.clock() - sentAt > 3 then humanoid:MoveTo(point.Position); sentAt = os.clock() end
							RunService.Heartbeat:Wait()
						end
						if retry then break end
					end
					if not retry then return end
				end
			end)
			if token ~= self.navToken then return end
			self.navBusy = false
			if not ok then self.navError = tostring(message) end
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

	function director:PillarPosition(id)
		local map = workspace:FindFirstChild("Map")
		local pillars = map and map:FindFirstChild("WarpPillars")
		local model = pillars and pillars:FindFirstChild("WarpPillar_" .. tostring(id))
		if not model then return nil end
		local column = model:FindFirstChild("Column")
		-- Streamed-out models retain their pivot even when Column is absent.
		return column and column.Position or model:GetPivot().Position
	end

	function director:NearestPillar(position)
		local map = workspace:FindFirstChild("Map")
		local pillars = map and map:FindFirstChild("WarpPillars")
		local source, distance
		for _, model in ipairs(pillars and pillars:GetChildren() or {}) do
			local column = model:FindFirstChild("Column")
			local prompt = column and column:FindFirstChild("WarpPrompt")
			if column and prompt and prompt.Enabled then
				local d = (column.Position - position).Magnitude
				if not distance or d < distance then source, distance = column, d end
			end
		end
		return source, distance
	end

	function director:PillarApproachPoints(source, fromPosition)
		local delta = Vector3.new(fromPosition.X - source.Position.X, 0, fromPosition.Z - source.Position.Z)
		local toward = delta.Magnitude > 0.01 and delta.Unit or Vector3.new(0, 0, 1)
		local right = Vector3.new(-toward.Z, 0, toward.X)
		local points = {}
		for _, angle in ipairs({0, 45, -45, 90, -90, 135, -135, 180}) do
			local radians = math.rad(angle)
			table.insert(points, source.Position + (toward * math.cos(radians) + right * math.sin(radians)) * 8.5)
		end
		return points
	end

	function director:FindPillarApproach(source, active)
		local root, humanoid = self:Character()
		if not root or not humanoid then return nil end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {workspace:FindFirstChild("Map") or workspace.Terrain}
		params.RespectCanCollide = true
		for _, point in ipairs(self:PillarApproachPoints(source, root.Position)) do
			if active and not active() then return nil end
			local hit = workspace:Raycast(point + Vector3.new(0, 10, 0), Vector3.new(0, -28, 0), params)
			if not hit or hit.Normal.Y < 0.6 then continue end
			local goal = Vector3.new(point.X, hit.Position.Y + humanoid.HipHeight + root.Size.Y / 2, point.Z)
			local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = self:CanNavigateJump(humanoid), WaypointSpacing = 5})
			local ok = pcall(path.ComputeAsync, path, root.Position, goal)
			if active and not active() then return nil end
			if ok and path.Status == Enum.PathStatus.Success then return goal end
		end
		return nil
	end

	function director:TravelRoute(id, returnPosition, fromPosition)
		local root = fromPosition and {Position = fromPosition} or self:Character()
		local zone = self:ZonePart(id)
		local goal = returnPosition or (zone and zone.Position)
		local direct = (id == "Town" or (MapData[id] and MapData[id].BossRoom)) and id or nil
		if direct and self:PillarAvailable(direct) then
			local at = self:PillarPosition(direct)
			if root and at and (root.Position - at).Magnitude <= 35 then return nil, 0 end
			local source = root and self:NearestPillar(root.Position)
			if source and source.Parent:GetAttribute("WarpId") == direct then return nil, 0 end
			return direct, direct == "Town" and 0 or (tonumber(direct:match("%d+")) or 0) * 1000
		end
		if not root or not goal then return nil, 0 end
		local _, sourceDistance = self:NearestPillar(root.Position)
		if not sourceDistance then return nil, 0 end
		local best, bestDistance = nil, (root.Position - goal).Magnitude - 90
		for _, candidate in ipairs({"Town", "Boss01", "Boss02", "Boss03", "Boss04", "Boss05"}) do
			local at = self:PillarPosition(candidate)
			if at and self:PillarAvailable(candidate) and (candidate == "Town" or self:CanAccess(candidate)) then
				local distance = sourceDistance + (at - goal).Magnitude
				if distance < bestDistance then best, bestDistance = candidate, distance end
			end
		end
		return best, best and best ~= "Town" and (tonumber(best:match("%d+")) or 0) * 1000 or 0
	end

	function director:CancelTrip()
		if self.lootTrip then self:CancelBoxTrip(true) end
		self.travel.token += 1
		self.travel.active, self.travel.completed = false, false
		self:CancelNavigation()
		local root, humanoid = self:Character()
		if root and humanoid then humanoid:MoveTo(root.Position) end
		self.travel.status = "ยกเลิกการเดินทางแล้ว"
	end

	function director:ReturnTrip()
		if not self.travel.bookmark then self.travel.status = "ยังไม่มีจุดก่อนเดินทาง"; return end
		self:TravelTo(self.travel.bookmark.zone, self.travel.bookmark.position, true)
	end

	function director:TravelTo(id, returnPosition, returning, internal)
		local travel = self.travel
		travel.completed, travel.lastError = false, nil
		local allowed, reason = true, nil
		if id ~= "Town" then allowed, reason = self:CanAccess(id) end
		if not allowed then travel.status = "ไปไม่ได้: " .. tostring(reason); return false end
		local pillarId, cost = self:TravelRoute(id, returnPosition)
		if (tonumber(player:GetAttribute("Silver")) or 0) < cost then travel.status = "Silver ไม่พอ: วาร์ปนี้ใช้ " .. comma(cost); return false end
		local root = self:Character()
		if not root then travel.status = "รอตัวละครเกิดก่อน"; return false end
		if workspace:GetAttribute("DungeonId") ~= nil then travel.status = "ใช้ปุ่มออกดันของเกมก่อนเดินทาง"; return false end
		local nativeWasOn = self.lootTrip and self.lootTrip.native or player:GetAttribute("AutoOn") == true
		if not internal and self.enabled then self:SetEnabled(false) end
		self:CancelTrip()
		if not returning and not internal then travel.bookmark = {zone = self:CurrentZone(), position = root.Position, auto = nativeWasOn} end
		travel.active, travel.status = true, "เตรียมเดินทางไป " .. id
		local token, deadline = travel.token, os.clock() + 180
		task.spawn(function()
			local function alive() return runtime.alive and travel.active and travel.token == token and os.clock() < deadline end
			local ok, message = xpcall(function()
				setAutoFarm(false)
				local pauseDeadline = os.clock() + 4
				while alive() and player:GetAttribute("AutoOn") == true and os.clock() < pauseDeadline do setAutoFarm(false); task.wait(0.1) end
				if player:GetAttribute("AutoOn") == true then error("ปิด Auto ของเกมก่อนเดินทางไม่สำเร็จ") end
				local function moveTo(goal, label, tolerance)
					self:CancelNavigation()
					while alive() do
						local current, humanoid = self:Character()
						if not current or not humanoid or humanoid.Health <= 0 then error("ตัวละครเสียชีวิตระหว่างเดินทาง") end
						if player:GetAttribute("AutoOn") == true then
							setAutoFarm(false)
							self:CancelNavigation()
							travel.status = "พัก Auto ของเกมก่อนเดินทางต่อ"
							task.wait(0.2)
							continue
						end
						if self.navError then error(self.navError) end
						travel.status = label .. string.format(" • %.0f studs", (current.Position - goal).Magnitude)
						if self:Walk(goal, tolerance or 7) then return true end
						task.wait(0.1)
					end
					return false
				end
				if pillarId then
					local current = self:Character()
					local source = current and self:NearestPillar(current.Position)
					if not source then error("ไม่พบเสาต้นทางที่โหลดอยู่ ลองเดินเข้าใกล้เสา") end
					local prompt = source:FindFirstChild("WarpPrompt")
					travel.status = "หาเส้นทางไปจุดยืนข้างเสาวาร์ป"
					local approach = self:FindPillarApproach(source, alive)
					if not alive() then return end
					if not approach then error("ไม่พบทางเดินไปข้างเสาวาร์ป ลองยืนกลางทางเดินแล้วเลือกอีกครั้ง") end
					if not moveTo(approach, "กำลังเดินไปข้างเสาวาร์ป", 1.8) then return end
					local nearSource = self:Character()
					if not nearSource or (nearSource.Position - source.Position).Magnitude > prompt.MaxActivationDistance then error("ยังอยู่นอกระยะเสาวาร์ป") end
					travel.sourceApproach = {goal = approach, distance = (nearSource.Position - source.Position).Magnitude}
					self:CancelNavigation()
					local openedAt = os.clock()
					local fire = rawget(env, "fireproximityprompt")
					if type(fire) == "function" then fire(prompt) else
						prompt:InputHoldBegin(); task.wait(prompt.HoldDuration + 0.1); prompt:InputHoldEnd()
					end
					local openDeadline = os.clock() + 6
					while alive() and (self.lastPillarOpenAt or 0) < openedAt and os.clock() < openDeadline do task.wait(0.1) end
					if not alive() then return end
					if (self.lastPillarOpenAt or 0) < openedAt then error("เสายังไม่ตอบรับ กดเปิดเมนูเสาแล้วลองอีกครั้ง") end
					local event = remote("PillarWarp")
					if not event then error("ไม่พบ PillarWarp ของเกม") end
					travel.status = "รอเซิร์ฟเวอร์วาร์ปไป " .. pillarId
					event:FireServer(pillarId)
					local responseDeadline, arrived = os.clock() + 15, false
					while alive() and os.clock() < responseDeadline do
						local at = self:PillarPosition(pillarId)
						local here = self:Character()
						if at and here and (here.Position - at).Magnitude < 65 then arrived = true; break end
						task.wait(0.1)
					end
					if not alive() then return end
					if not arrived then error("เซิร์ฟเวอร์ไม่ยืนยันวาร์ป ตรวจสิทธิ์เสาและ Silver") end
				end
				if not alive() then return end
				local zone = self:ZonePart(id)
				if internal and MapData[id] and MapData[id].BossRoom and not returnPosition then
					local zoneDeadline = os.clock() + 8
					while alive() and not zone and os.clock() < zoneDeadline do
						travel.status = "รอเขตห้องบอสโหลดก่อนเดินเข้า"
						task.wait(0.15)
						zone = self:ZonePart(id)
					end
					if not alive() then return end
					if not zone then error("ห้องบอสยังไม่โหลด ลองเดินเข้าใกล้ทางเข้าห้องแล้วเริ่มอีกครั้ง") end
				end
				local pillar = self:PillarPosition(id)
				local bossEntry = internal and MapData[id] and MapData[id].BossRoom and zone
				local current = self:Character()
				local size = MapData[id] and tonumber((MonsterData[MapData[id].Boss] or {}).Size) or 16
				local goal = returnPosition or (bossEntry and self:BossEntryPoint(bossEntry, current.Position, size))
				if not goal and pillar then
					local map = workspace:FindFirstChild("Map")
					local pillars = map and map:FindFirstChild("WarpPillars")
					local model = pillars and pillars:FindFirstChild("WarpPillar_" .. id)
					local column = model and model:FindFirstChild("Column")
					goal = column and self:FindPillarApproach(column, alive)
				end
				goal = goal or (zone and zone.Position + Vector3.new(0, 3, 0))
				if not goal then error("ยังไม่มีพิกัดด่านนี้ ลองวาร์ปไปเสาใกล้ด่านก่อน") end
				if not moveTo(goal, returning and "กำลังกลับจุดเดิม" or "กำลังไปจุดหมาย", 7) then return end
				travel.completed = true
				travel.status = returning and "กลับถึงจุดเดิมแล้ว" or ("ถึง " .. id .. " แล้ว")
				travel.lastArrival = {id = id, returning = returning == true, at = os.clock()}
				if returning and not internal and travel.bookmark and travel.bookmark.auto then setAutoFarm(true) end
			end, debug.traceback)
			if travel.token ~= token then return end
			if not ok then travel.lastError = tostring(message); travel.status = "เดินทางไม่สำเร็จ: " .. displayError(message) end
			if os.clock() >= deadline then travel.status = "เดินทางหมดเวลา"; travel.completed = false end
			travel.active = false
			self:CancelNavigation()
		end)
		return true
	end

	local pillarOpen = remote("PillarOpen")
	if pillarOpen then track(pillarOpen.OnClientEvent:Connect(function(id)
		director.lastPillarOpenAt, director.lastPillarId = os.clock(), id
	end)) end

	function director:BuildTargetExclusions(id, priority, definitions)
		local candidates, preferred = {}, 0
		for monsterId, definition in pairs(definitions or MonsterData) do
			if type(definition) == "table" and monsterId ~= id then
				if priority[monsterId] then preferred += 1 end
				table.insert(candidates, monsterId)
			end
		end
		if preferred > 100 then return nil end
		table.sort(candidates, function(a, b)
			if (priority[a] == true) ~= (priority[b] == true) then return priority[a] == true end
			return a < b
		end)
		local excludes = {}
		for index = 1, math.min(100, #candidates) do excludes[candidates[index]] = true end
		return excludes
	end

	function director:ConfigureTarget(id)
		if self.configuredId == id then return true end
		local settings = decodeAttribute("BotJson")
		local priority, root = {}, self:Character()
		local zone = MapData[spawnZones[id]]
		for _, node in ipairs(nodes) do
			if zone and math.abs(node.data.Order - zone.Order) <= 2 then
				for _, spawn in ipairs(node.data.Spawns or {}) do priority[spawn.Id] = true end
			end
		end
		local folder = workspace:FindFirstChild("Monsters")
		for _, model in ipairs(folder and folder:GetChildren() or {}) do
			local monsterId = model:GetAttribute("MonsterId")
			if monsterId and model.PrimaryPart and root and (model.PrimaryPart.Position - root.Position).Magnitude < 300 then priority[monsterId] = true end
		end
		-- The server retains only 100 exclusions. Prioritize everything in/near
		-- this room, then fill remaining slots deterministically with distant IDs.
		local excludes = self:BuildTargetExclusions(id, priority)
		if not excludes then self.detail = "ตัวกรองมอนสเตอร์ใกล้ตัวเกินขีดจำกัดของเกม"; return false end
		settings.Exclude, settings.Only = excludes, {}
		settings.Mode, settings.Preset = "fight", "normal"
		settings.AttackLeader, settings.NormalAttack, settings.UseSkills = true, true, true
		local targetSize = tonumber((MonsterData[id] or {}).Size) or 16
		local radius = math.clamp(math.max(60, targetSize + 20), 20, 150)
		settings.FixedArea, settings.Range, settings.Radius, settings.Loot = true, radius, radius, true
		local event = remote("SetBotSettings")
		if not event then self.phase, self.detail = "หยุด: ตั้งเป้าหมายไม่ได้", "ไม่พบ SetBotSettings"; return false end
		event:FireServer(settings)
		self.configuredId, self.settingsSentAt, self.sentExcludes = id, os.clock(), excludes
		return true
	end

	function director:SameSettings(a, b)
		if type(a) ~= type(b) then return false end
		if type(a) ~= "table" then return a == b end
		for key, value in pairs(a) do if not self:SameSettings(value, b[key]) then return false end end
		for key in pairs(b) do if a[key] == nil then return false end end
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

	function director:SaveHome()
		if self.session or self.travel.active then toast("รอให้กลับจากทริปก่อนเปลี่ยนจุดฟาร์ม", "info"); return false end
		local root = self:Character()
		if not root then return false end
		self.home = {zone = self:CurrentZone(), position = root.Position}
		self.travel.bookmark = self.home
		self.homeBot, self.homeAuto = decodeAttribute("BotJson"), player:GetAttribute("AutoOn") == true
		toast("จำจุดฟาร์มนี้แล้ว", "good")
		return true
	end

	function director:Preview()
		local boss = self:SelectedDefinition()
		self.phase = "พร้อมเฝ้าบอส"
		self.detail = (boss and ("บอสที่เลือก: " .. boss.name) or "เลือกบอสในหน้า บอส 10 นาที")
			.. "\nยืนจุดฟาร์ม เปิด Auto ของเกม แล้วกดเริ่มเฝ้าบอส"
	end

	function director:RestoreSettings(session, deferPotions)
		if not session then return end
		if not session.restored then
			if session.botChanged and remote("SetBotSettings") then remote("SetBotSettings"):FireServer(session.bot) end
			if session.skillChanged then setRemoteBoolean("SetAutoSkill", session.autoSkill) end
			session.restored, session.restoreAt = true, os.clock()
		end
		if not deferPotions and session.potionChanged and not session.potionRestored then
			if remote("SetPotionSlot") then remote("SetPotionSlot"):FireServer("hp", session.potionSlot) end
			if remote("SetPotionAuto") then remote("SetPotionAuto"):FireServer("hp", session.potionPercent) end
			session.potionRestored, session.potionRestoreAt = true, os.clock()
		end
	end

	function director:SetEnabled(value)
		if value == self.enabled then return end
		if self.lootTrip then self:CancelBoxTrip(true) end
		if value then
			if self.travel.active then self:CancelTrip() end
			if not self:SaveHome() then return end
			self.enabled, self.session = true, nil
			self.hop = {visited = {}, count = 0, max = 10, nextAt = os.clock() + 20}
			self.startedAt, self.startSilver = os.clock(), tonumber(player:GetAttribute("Silver")) or 0
			self.startTotalExp = self:TotalExp(player:GetAttribute("Level"), player:GetAttribute("Exp"))
			self.kills, self.plan, self.configuredId = 0, nil, nil
			self.failedBossSpawns[self.selectedBoss], self.cooldowns[self.selectedBoss] = nil, nil
			self.phase, self.detail = "กำลังเฝ้าบอส", "ให้ Auto ของเกมฟาร์มตามเดิม • จำจุดกลับแล้ว"
		else
			self.enabled = false
			self.hopMode = false
			self.hop.token = (self.hop.token or 0) + 1
			self.hop.busy = false
			if self.travel.active then self:CancelTrip() end
			self:CancelNavigation()
			local session = self.session
			if session then
				setAutoFarm(false)
				self:RestoreSettings(session)
				local root, humanoid = self:Character()
				if root and humanoid then humanoid:MoveTo(root.Position) end
			end
			self.session, self.plan, self.configuredId = nil, nil, nil
			self.dungeonTrip, self.dungeonEntering, self.dungeonRequested = false, nil, nil
			self:Watch(nil)
			self.phase = "หยุดเฝ้าบอสแล้ว"
			self.detail = session and "หยุดทริปแล้ว • กดกลับจุดเดิมได้ที่หน้า วาร์ป / กลับ" or "Auto ของเกมยังใช้ค่าที่คุณตั้งไว้"
		end
	end

	function director:BeginSession(kind, plan)
		local root = self:Character()
		if not root or not self.home then return false end
		local bot, native = decodeAttribute("BotJson"), player:GetAttribute("AutoOn") == true
		if self.hopMode then bot, native = self.homeBot or bot, self.homeAuto == true end
		self.session = {kind = kind, stage = "outbound", bot = bot, native = native,
			autoSkill = player:GetAttribute("AutoSkill") == true, startedAt = os.clock()}
		if kind == "boss" and not self:PreparePotions(self.session) then
			self.session = nil
			self.lastDecision = "ตั้งระบบยาก่อนเข้าห้องบอสไม่ได้"
			return false
		end
		if kind == "dungeon" then self.promptFiredAt, self.dungeonEntering, self.dungeonRequested = nil, nil, nil end
		self.travel.bookmark = {zone = self.home.zone, position = self.home.position, auto = native}
		self.plan, self.configuredId = plan, nil
		self.bossLootUntil, self.fightStarted = nil, nil
		self.bossPotionStart = self:HealingSupply()
		local id = plan and plan.zone or "Town"
		if not self:TravelTo(id, nil, false, true) then
			self.lastDecision = self.travel.status
			self:RestoreSettings(self.session)
			self.session, self.plan = nil, nil
			if plan then self.cooldowns[plan.id] = os.clock() + 60 end
			return false
		end
		return true
	end

	function director:BeginReturn(reason)
		local session = self.session
		if not session then return end
		self.lastDecision = reason
		self:Watch(nil)
		self:CancelNavigation()
		self:SetNativeAuto(false)
		self:RestoreSettings(session, true)
		session.stage = "return"
		self.plan, self.configuredId = nil, nil
		if not self.home or not self:TravelTo(self.home.zone, self.home.position, true, true) then
			self:SetEnabled(false)
			self.detail = "กลับจุดเดิมไม่ได้: " .. self.travel.status
		end
	end

	function director:FinishBoss(reason, killed, missing)
		local plan = self.plan
		if plan then
			self.failedBossSpawns[plan.id] = plan.spawnKey
			self.cooldowns[plan.id] = os.clock() + 60
		end
		self.lastBossResult = {reason = reason, killed = killed == true, missing = missing == true,
			potions = self.session and self.session.potionsUsed or 0}
		if (killed or missing) and self.hopMode then
			self.session.stage = "hop"
			self.lastDecision = reason
			self:SetNativeAuto(false)
			self:RestoreSettings(self.session)
			self:Watch(nil)
			self.plan = nil
			self.hop.nextAt = math.max(self.hop.nextAt or 0, os.clock() + 3)
		else
			if self.hopMode and self.session then self.session.stopAfterReturn = true end
			self:BeginReturn(reason)
		end
	end

	function director:PickServer(data, visited, current, now)
		local candidates = {}
		for _, server in ipairs(type(data) == "table" and data.data or {}) do
			if type(server) == "table" and type(server.id) == "string" and server.id ~= current
				and type(server.playing) == "number" and type(server.maxPlayers) == "number"
				and server.playing < server.maxPlayers and (visited[server.id] or 0) <= now then
				table.insert(candidates, server)
			end
		end
		table.sort(candidates, function(x, y) return x.playing < y.playing end)
		return candidates[1] and candidates[1].id
	end

	function director:QueueHop(target)
		local queue = rawget(env, "queue_on_teleport") or rawget(env, "queueonteleport")
		local syn = rawget(env, "syn")
		if type(queue) ~= "function" and type(syn) == "table" then queue = syn.queue_on_teleport end
		if type(queue) ~= "function" then error("ตัวรันไม่รองรับโหลดต่อหลังย้ายเซิร์ฟ") end
		local home = self.home
		local payload = {version = 1, user = player.UserId, place = game.PlaceId, target = target, at = os.time(),
			selected = self.selectedBoss, count = self.hop.count + 1, max = self.hop.max, visited = self.hop.visited,
			home = {zone = home.zone, x = home.position.X, y = home.position.Y, z = home.position.Z},
			bot = self.homeBot, native = self.homeAuto, equip = self.equipBest,
			sustain = {healAt = self.healAt, potionBudget = self.potionBudget, retreatAt = self.retreatAt,
				potionChoice = self.potionChoice, fightMinutes = self.fightMinutes, autoPickup = self.autoPickup}}
		local encoded = HttpService:JSONEncode(payload)
		local code = string.format([=[
if not game:IsLoaded() then game.Loaded:Wait() end
local data = game:GetService("HttpService"):JSONDecode(%q)
if game.PlaceId == data.place and game.JobId == data.target and os.time() - data.at < 600 then
	getgenv().__DukeHTResume = data
	loadstring(game:HttpGet("https://raw.githubusercontent.com/maxwellisnothere/HTforV4LENTINE/main/loader.luau"))()
end
]=], encoded)
		queue(code)
	end

	function director:HopServer()
		local hop = self.hop
		if hop.busy or os.clock() < hop.nextAt then return end
		if hop.count >= hop.max then
			self.hopMode = false
			self.session = self.session or {kind = "hop", bot = self.homeBot or decodeAttribute("BotJson"),
				native = self.homeAuto == true, autoSkill = player:GetAttribute("AutoSkill") == true}
			self.session.stopAfterReturn = true
			self:BeginReturn("ครบจำนวนย้ายเซิร์ฟ กลับจุดฟาร์ม")
			return
		end
		hop.busy, hop.nextAt = true, os.clock() + 45
		hop.token = (hop.token or 0) + 1
		local token = hop.token
		task.spawn(function()
			local function active() return runtime.alive and self.enabled and self.hopMode and self.hop == hop and hop.token == token end
			local ok, message = pcall(function()
				local cursor, target
				for _ = 1, 3 do
					local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true"
					if cursor then url ..= "&cursor=" .. HttpService:UrlEncode(cursor) end
					local data = HttpService:JSONDecode(game:HttpGet(url))
					if not active() then return end
					target = self:PickServer(data, hop.visited, game.JobId, os.time())
					if target then break end
					cursor = data.nextPageCursor
					if type(cursor) ~= "string" or cursor == "" then break end
					task.wait(1)
				end
				if not target then error("ยังไม่มีเซิร์ฟใหม่ที่เข้าได้ พัก 60 วินาที") end
				if not active() then return end
				hop.visited[game.JobId], hop.visited[target] = os.time() + 1800, os.time() + 1800
				self:QueueHop(target)
				if not active() then return end
				self.phase, self.detail = "กำลังย้ายเซิร์ฟ", "เข้าเซิร์ฟใหม่เพื่อตรวจบอสที่เลือก"
				hop.pending, hop.pendingAt = target, os.clock()
				game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, target, player)
			end)
			if not active() then hop.busy = false; return end
			if not ok then
				hop.busy, hop.pending, hop.nextAt = false, nil, os.clock() + 60
				self.lastDecision = "ย้ายเซิร์ฟไม่สำเร็จ: " .. displayError(message)
			end
		end)
	end

	track(game:GetService("TeleportService").TeleportInitFailed:Connect(function(who, _, message)
		if who ~= player or not director.hop.pending then return end
		director.hop.pending, director.hop.busy, director.hop.nextAt = nil, false, os.clock() + 60
		director.lastDecision = "ย้ายเซิร์ฟไม่สำเร็จ: " .. tostring(message)
	end))

	function director:Tick()
		if not self.enabled then return end
		if self.lootTrip then self.phase, self.detail = "กำลังเก็บกล่อง", self.pickupStatus; return end
		if self.resumeReadyAt and os.clock() < self.resumeReadyAt then return end
		local root, humanoid = self:Character()
		if not root or not humanoid or humanoid.Health <= 0 then
			if self.travel.active then self:CancelTrip() end
			self:CancelNavigation()
			if self.plan then self.failedBossSpawns[self.plan.id] = self.plan.spawnKey end
			if self.session then self.session.stage = "respawn" end
			self.phase, self.detail = "รอเกิดใหม่", "เกิดแล้วจะกลับจุดฟาร์ม • ไม่ใช้การเกิดใหม่เสียเงิน"
			return
		end
		local session = self.session
		if session and session.stage == "respawn" then self:BeginReturn("กลับจุดฟาร์มหลังเกิดใหม่"); return end
		if self.travel.active then self.phase, self.detail = "กำลังเดินทาง", self.travel.status; return end
		if self.hop.pending and os.clock() - self.hop.pendingAt > 25 then
			self.hop.pending, self.hop.busy, self.hop.nextAt = nil, false, os.clock() + 60
			self.lastDecision = "ย้ายเซิร์ฟหมดเวลา พักก่อนลองใหม่"
		end
		if not session and (self.hop.pending or self.hop.busy) then
			self.phase, self.detail = "กำลังย้ายเซิร์ฟ", "กำลังค้นหา/เชื่อมต่อเซิร์ฟใหม่ รอ Roblox"
			return
		end
		if session and session.stage == "return" then
			if not self.travel.completed then
				local reason = self.travel.status; self:SetEnabled(false); self.detail = reason; return
			end
			if os.clock() - (session.restoreAt or 0) < 1 then return end
			self:RestoreSettings(session)
			if session.potionChanged and (player:GetAttribute("PotionHpPercent") ~= session.potionPercent
				or player:GetAttribute("PotionHpNow") ~= session.potionSlot) then
				if os.clock() - (session.potionRestoreAt or os.clock()) > 8 then self:SetEnabled(false); self.detail = "คืนค่าช่องยาของเกมไม่สำเร็จ กรุณาตรวจช่องยา" end
				return
			end
			-- Wait for the original target filter before resuming native combat.
			if session.botChanged then
				local same = self:SameSettings(decodeAttribute("BotJson"), session.bot)
				if not same then
					if os.clock() - session.restoreAt > 8 then self:SetEnabled(false); self.detail = "เกมยังไม่คืนค่าตัวกรอง Auto กรุณาตรวจหน้า Auto ของเกม" end
					return
				end
			end
			self:SetNativeAuto(session.native)
			if (player:GetAttribute("AutoOn") == true) ~= session.native then return end
			self.session, self.plan = nil, nil
			self.phase, self.detail = "กลับมาฟาร์มแล้ว", "คืนจุดและค่า Auto เดิม • เฝ้าบอสรอบต่อไป"
			if session.stopAfterReturn then
				self:SetEnabled(false)
				self.phase, self.detail = "จบรอบย้ายเซิร์ฟแล้ว", "กลับจุดและคืนค่า Auto เดิมแล้ว • กดเริ่มเพื่อเปิดรอบใหม่"
			end
			return
		end
		if session and session.stage == "hop" then
			if not self.hopMode then self:BeginReturn("กลับจุดเดิม"); return end
			self.phase = "เตรียมหาบอสเซิร์ฟถัดไป"
			self.detail = self.hop.pending and "ส่งคำขอย้ายแล้ว รอ Roblox" or string.format("รอย้ายเซิร์ฟอีก %.0f วินาที • %s", math.max(0, self.hop.nextAt - os.clock()), self.lastDecision or "")
			self:HopServer(); return
		end
		if session and session.stage == "outbound" then
			if not self.travel.completed then self:BeginReturn("เดินทางขาไปไม่สำเร็จ: " .. self.travel.status); return end
			session.stage, session.arrivedAt = session.kind == "boss" and "fight" or "service", os.clock()
		end
		if session and session.kind ~= "boss" then
			if os.clock() - session.startedAt > 240 then self:BeginReturn("ทริปหมดเวลา"); return end
			if session.kind == "sell" then
				if nearMerchant() then
					if not session.sellAt then
						session.junkBefore = junkInfo()
						if sellJunk(true) then session.sellAt = os.clock() else self:BeginReturn("ไม่มี Junk ที่ส่งขายได้") end
					elseif junkInfo() < session.junkBefore then self:BeginReturn("ขาย Junk แล้ว กลับจุดฟาร์ม")
					elseif os.clock() - session.sellAt > 8 then self:BeginReturn("เซิร์ฟเวอร์ไม่ยืนยันขาย Junk") end
				else
					local map = workspace:FindFirstChild("Map")
					local npcs = map and map:FindFirstChild("NPCs")
					local merchant = npcs and npcs:FindFirstChild("merchant")
					local part = merchant and (merchant.PrimaryPart or merchant:FindFirstChildWhichIsA("BasePart"))
					if not part then self:BeginReturn("Merchant ยังไม่โหลด"); return end
					self.phase, self.detail = "กำลังไปขาย Junk", "เดินเข้าระยะ Merchant"
					self:Walk(part.Position, 15)
					if self.navError then self:BeginReturn("ไป Merchant ไม่ถึง") end
				end
			else
				if self.dungeonEntering then
					self.phase, self.detail = "รอเข้าดัน", state.dungeonStatus
					if os.clock() > self.dungeonEntering then self:BeginReturn("เข้าดันหมดเวลา") end
				elseif not self:DungeonTrip() then self:BeginReturn(state.dungeonStatus) end
			end
			return
		end
		if session and self.plan then
			local plan = self.plan
			local model = plan.model
			if not model or not model.Parent then model = self:Monster(plan.id); plan.model = model end
			if model then
				plan.spawnKey = model:GetAttribute("SpawnAt") or plan.spawnKey
				self.bossSpawnKeys[plan.id] = plan.spawnKey
				self:Watch(model)
			end
			if model and (tonumber(model:GetAttribute("HP")) or 0) > 0 then session.seenBoss = true end
			local presence = self:CurrentBossPresence({id = plan.id})
			local dead = (model and (tonumber(model:GetAttribute("HP")) or 1) <= 0)
				or (session.seenBoss and presence == "countdown")
			if dead then
				self.bossLootUntil = self.bossLootUntil or os.clock() + 5
				self.phase, self.detail = "บอสตายแล้ว รอเก็บของ", "ให้ Auto Loot เก็บของ 5 วินาที"
				if os.clock() >= self.bossLootUntil then self:FinishBoss("บอสตายแล้ว", true) end
				return
			end
			if not model or not model.PrimaryPart then
				self.phase, self.detail = "สำรวจห้องบอส", plan.name .. " • ตรวจตัวบอสและเวลานับถอยหลัง"
				if presence == "countdown" or os.clock() - session.arrivedAt > 18 then self:FinishBoss("สำรวจแล้วไม่พบบอสในเซิร์ฟนี้", false, true) end
				return
			end
			if not self:PreparePotions(session) then self:FinishBoss("ตั้งระบบยาไม่ได้", false); return end
			self:UpdatePotionUsage()
			local expected = session.potionCapped and 0 or session.healAt
			if player:GetAttribute("PotionHpPercent") ~= expected or player:GetAttribute("PotionHpNow") ~= session.selectedPotion then
				self.phase, self.detail = "รอยืนยันช่องยา", "รอเกมยืนยันเปอร์เซ็นต์และชนิดยา"
				if os.clock() - session.potionSentAt > 6 then self:FinishBoss("เกมไม่ยืนยันชนิดยา/เปอร์เซ็นต์ยา", false) end
				return
			end
			local available = (session.potionSnapshot or {})[session.selectedPotion] or 0
			local retreat = self:RetreatReason(humanoid.Health / math.max(1, humanoid.MaxHealth), plan, session.potionsUsed, available, session.potionBudget, session.retreatPercent)
			if retreat then self:FinishBoss(retreat, false); return end
			if session.fightMinutes > 0 and self.fightStarted and os.clock() - self.fightStarted > session.fightMinutes * 60 then self:FinishBoss("ครบเวลาต่อบอสที่ตั้งไว้", false); return end
			session.botChanged = true
			if not self:ConfigureTarget(plan.id) then self:FinishBoss("ตั้งตัวกรองบอสไม่ได้", false); return end
			local settings, confirmed = decodeAttribute("BotJson"), true
			if type(settings.Exclude) ~= "table" or settings.Exclude[plan.id] == true then confirmed = false else
				for id in pairs(self.sentExcludes or {}) do
					if settings.Exclude[id] ~= true then confirmed = false; break end
				end
			end
			if not confirmed then
				if os.clock() - self.settingsSentAt > 5 then self:FinishBoss("เซิร์ฟเวอร์ไม่ยืนยันตัวกรองบอส", false) end
				return
			end
			local targetSize = tonumber((MonsterData[plan.id] or {}).Size) or 16
			if not self.fightStarted and self:BossNeedsApproach(root.Position, model.PrimaryPart.Position, targetSize) then
				self.phase, self.detail = "เข้าระยะบอส", plan.name
				local target = model.PrimaryPart.Position
				self:Walk(Vector3.new(target.X, root.Position.Y, target.Z), self:BossEngageDistance(targetSize) - 2)
				if self.navError then self:FinishBoss("เดินเข้าระยะบอสไม่ได้", false) end
				return
			end
			self:CancelNavigation()
			if not session.skillChanged then session.skillChanged = true; setRemoteBoolean("SetAutoSkill", true) end
			self.fightStarted = self.fightStarted or os.clock()
			setAutoFarm(true)
			self.phase = "กำลังตี " .. plan.name
			self.detail = string.format("HP บอส %s • ยาใช้ %d/%d ขวด • เหลือ %d\n%s", comma(model:GetAttribute("HP")), session.potionsUsed, session.potionBudget, available,
				session.potionCapped and ("ครบงบยาแล้ว • สู้ต่อจน HP ≤ " .. session.retreatPercent .. "% จึงถอย") or ("ใช้ยาเมื่อ HP < " .. session.healAt .. "% • สู้ต่อได้ขณะยังมียาในงบ"))
			return
		end
		local boss = self:SelectedDefinition()
		local alive = boss and workspace:GetAttribute("BossAlive_" .. boss.id)
		local presence = boss and self:CurrentBossPresence(boss)
		if boss and presence == "countdown" then self.failedBossSpawns[boss.id], self.bossSpawnKeys[boss.id] = nil, nil end
		local plan = self:SelectPlan()
		if plan then self:BeginSession("boss", plan); return end
		self.phase = "กำลังเฝ้าบอส"
		local waitTime = boss and math.max(0, (workspace:GetAttribute("BossNext_" .. boss.id) or 0) - serverNow()) or 0
		self.detail = (boss and boss.name or "ยังไม่เลือกบอส") .. (alive == true and " • เกิดแล้ว" or string.format(" • รอ %02d:%02d", math.floor(waitTime / 60), math.floor(waitTime % 60)))
		self.detail ..= "\nให้ Auto ของเกมฟาร์มตามเดิม • จำจุดกลับแล้ว"
		if boss and alive == true then
			local allowed, reason = self:CanAccess(boss.map)
			if not allowed then self.detail ..= " • " .. tostring(reason)
			elseif self.failedBossSpawns[boss.id] then self.detail ..= " • พักบอสเกิดรอบนี้" end
		end
		if self.hopMode and self.huntBosses and boss and self:CanAccess(boss.map) then
			if presence == "countdown" then
				self.phase = "หาบอสเซิร์ฟถัดไป"
				self.detail = string.format("บอสเซิร์ฟนี้ยังรอเกิด • ย้ายใน %.0f วินาที", math.max(0, self.hop.nextAt - os.clock()))
				self:HopServer(); return
			elseif self.failedBossSpawns[boss.id] then
				self.detail ..= " • พักบอสนี้: ยา/เลือดไม่ไหว ให้ปรับงบแล้วเริ่มใหม่"
			end
		end
		if not self.hopMode and self.runDungeons and self:DungeonStatus() and os.clock() - (self.lastDungeonAttempt or -600) >= 600 then
			self.lastDungeonAttempt, self.dungeonTrip = os.clock(), true
			self:BeginSession("dungeon"); return
		end
		if self.sellTrip and not self.hopMode and junkInfo() >= state.junkThreshold and os.clock() - (self.lastSellTrip or -120) > 120 then
			self.lastSellTrip = os.clock()
			if nearMerchant() then sellJunk(false) else
				local _, value = junkInfo()
				local town = self:PillarPosition("Town")
				local _, returnCost = self:TravelRoute(self.home.zone, self.home.position, town)
				if value > returnCost + 100 then self:BeginSession("sell")
				else self.lastDecision = "รอ Junk มากขึ้น: มูลค่า " .. comma(value) .. " / ค่าเดินทางกลับประมาณ " .. comma(returnCost) end
			end
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
		self.ui.start.Text = self.enabled and "หยุดเฝ้าบอส / ทริป" or "จำจุดนี้และเริ่มเฝ้าบอส"
		self.ui.start.BackgroundColor3 = self.enabled and COLORS.Red or COLORS.Green
		local minutes = math.max(1 / 60, (os.clock() - (self.startedAt > 0 and self.startedAt or os.clock())) / 60)
		local gained = self.startedAt > 0 and math.max(0, self:TotalExp(player:GetAttribute("Level"), player:GetAttribute("Exp")) - (self.startTotalExp or 0)) or 0
		local silver = self.startedAt > 0 and (tonumber(player:GetAttribute("Silver")) or 0) - self.startSilver or 0
		self.ui.stats.Text = string.format("ฆ่า %d ตัว  •  EXP +%s  •  %s EXP/นาที  •  Silver %+d", self.kills, comma(gained), comma(gained / minutes), silver)
		local _, dungeon = self:DungeonStatus()
		local boss = self:SelectedDefinition() or bosses[1]
		local remaining = math.max(0, (workspace:GetAttribute("BossNext_" .. boss.id) or 0) - serverNow())
		local bossText = workspace:GetAttribute("BossAlive_" .. boss.id) == true and (boss.name .. ": เกิดแล้ว") or string.format("%s: %02d:%02d", boss.name, math.floor(remaining / 60), math.floor(remaining % 60))
		self.ui.note.Text = bossText .. "\n" .. dungeon
		self.ui.note.Text ..= "\nโหมด: " .. (self.hopMode and ("ข้ามเซิร์ฟ " .. self.hop.count .. "/" .. self.hop.max) or "ตีบอสแล้วกลับจุดเดิม")
		self.ui.note.Text ..= " • เลือกบอสได้ที่หน้า บอส 10 นาที"
		if self.home then self.ui.note.Text ..= "\nจุดกลับ: " .. self.home.zone .. string.format(" (%.0f, %.0f, %.0f)", self.home.position.X, self.home.position.Y, self.home.position.Z) end
		for id, button in pairs(bossChoices) do
			button.Text = id == self.selectedBoss and "✓ บอสที่เลือก" or "เลือกบอสตัวนี้"
			button.BackgroundColor3 = id == self.selectedBoss and Color3.fromRGB(35, 78, 45) or COLORS.Card2
		end
		self.ui.note.Text ..= "\nAuto Equip: " .. (player:GetAttribute("AutoEquip") == true and "ON • เลือก CP สูงสุดโดยเกม" or "OFF / รอยืนยัน")
		self.ui.note.Text ..= "\n" .. (self.autoPickup and self.pickupStatus or "เก็บกล่อง/ของ: OFF")
		for _, node in ipairs(nodes) do
			local minimum = tonumber(tostring(node.data.LevelText):match("%d+")) or math.huge
			local allowed, reason = self:CanAccess(node.id)
			if not allowed and minimum <= (player:GetAttribute("Level") or 1) then
				self.ui.note.Text ..= "\nโซนถัดไป: " .. tostring(reason)
				break
			end
		end
		if self.lastDecision then self.ui.note.Text ..= "\n" .. self.lastDecision end
		if not self.session or self.session.kind ~= "dungeon" then state.dungeonStatus = dungeon end
	end

	function director:ValidResume(data)
		if type(data) ~= "table" or data.version ~= 1 or data.user ~= player.UserId
			or data.place ~= game.PlaceId or data.target ~= game.JobId or type(data.at) ~= "number"
			or os.time() - data.at < 0 or os.time() - data.at >= 600 then return false end
		local known = false
		for _, boss in ipairs(bosses) do if boss.id == data.selected then known = true end end
		local home = data.home
		return known and type(home) == "table" and type(home.zone) == "string"
			and (home.zone == "Town" or MapData[home.zone] ~= nil)
			and type(home.x) == "number" and type(home.y) == "number" and type(home.z) == "number"
			and math.abs(home.x) < 100000 and math.abs(home.y) < 100000 and math.abs(home.z) < 100000
			and type(data.bot) == "table" and type(data.count) == "number" and data.count >= 1 and data.count <= 10
	end

	director:Preview()
	local resume = env.__DukeHTResume
	env.__DukeHTResume = nil
	if director:ValidResume(resume) then
		director.selectedBoss, director.hopMode, director.enabled = resume.selected, true, true
		director.home = {zone = resume.home.zone, position = Vector3.new(resume.home.x, resume.home.y, resume.home.z)}
		director.homeBot, director.homeAuto, director.equipBest = resume.bot, resume.native == true, resume.equip == true
		director.travel.bookmark = {zone = director.home.zone, position = director.home.position, auto = director.homeAuto}
		director.hop = {visited = type(resume.visited) == "table" and resume.visited or {}, count = resume.count,
			max = math.clamp(tonumber(resume.max) or 10, 1, 10), nextAt = os.clock() + 20}
		director.startedAt, director.startSilver = os.clock(), tonumber(player:GetAttribute("Silver")) or 0
		director.startTotalExp = director:TotalExp(player:GetAttribute("Level"), player:GetAttribute("Exp"))
		director.phase, director.detail = "ต่อจากเซิร์ฟเดิม", "รอข้อมูลบอสในเซิร์ฟนี้"
		director.resumeReadyAt = os.clock() + 15
		if type(resume.sustain) == "table" then
			for _, key in ipairs({"healAt", "potionBudget", "retreatAt", "potionChoice", "fightMinutes", "autoPickup"}) do
				if resume.sustain[key] ~= nil then director[key] = resume.sustain[key] end
			end
		end
	end
	director:RefreshUI()
	task.spawn(function()
		while runtime.alive do
			local ok, message = xpcall(function() director:Tick(); director:RefreshUI() end, debug.traceback)
			if not ok then
				director.lastError = tostring(message)
				pcall(function() director:SetEnabled(false) end)
				director.phase, director.detail = "หยุดเพราะข้อผิดพลาด", "หยุดงานแล้ว ลองเปิดหน้าต่างใหม่ • " .. displayError(message)
				pcall(function() director:RefreshUI() end)
			end
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		while runtime.alive do
			local ok, message = pcall(director.PickupNearby, director)
			if not ok then director.pickupStatus = "เก็บของไม่สำเร็จ: " .. displayError(message) end
			task.wait(0.15)
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
	if director.lootTrip then pcall(function() director:CancelBoxTrip(true) end) end
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
