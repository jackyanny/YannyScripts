if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- ==================== SETTINGS ====================
-- 1) Upload this file to your GitHub repo (name it yanny_hub.lua)
-- 2) Click "Raw" on the file and paste that link below
local SCRIPT_URL = "https://raw.githubusercontent.com/YOURUSERNAME/YannyScripts/main/yanny_hub.lua"

local CONFIG_FILE = "YannyScripts_Config.json"

local SHOP_ITEMS = {
	{ name = "Protection Scroll", id = 4 },
	{ name = "Race Roll",         id = 5 },
	{ name = "Season Ticket",     id = 7 },
	{ name = "Power Potion",      id = 12 },
	{ name = "Damage Potion",     id = 13 },
}

local BUY_ITEM_DELAY = 0.5   -- seconds between each purchase
local BUY_CYCLE_DELAY = 1    -- seconds between full rounds
local SPIN_DELAY = 0.1       -- seconds between pet spins
-- ==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

-- If the hub is executed again, shut the old copy down first
if env.YannyHubShutdown then
	pcall(env.YannyHubShutdown)
end

local running = true
local connections = {}

local function connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(connections, conn)
	return conn
end

-- ==================== CONFIG (autosave) ====================
local canSave = (writefile and readfile and isfile) and true or false

local cfg = {
	autoBuy = false,
	petSpin = false,
	autoExec = false,
	items = {},
}
for _, item in ipairs(SHOP_ITEMS) do
	cfg.items[item.name] = true
end

local function loadConfig()
	local saved
	if canSave then
		local ok, data = pcall(function()
			if isfile(CONFIG_FILE) then
				return HttpService:JSONDecode(readfile(CONFIG_FILE))
			end
		end)
		if ok and type(data) == "table" then
			saved = data
		end
	end
	if not saved and type(env.YannyConfig) == "table" then
		saved = env.YannyConfig
	end
	if not saved then return end

	for key, value in pairs(saved) do
		if key == "items" and type(value) == "table" then
			for name, state in pairs(value) do
				if cfg.items[name] ~= nil then
					cfg.items[name] = state and true or false
				end
			end
		elseif cfg[key] ~= nil and type(value) == "boolean" then
			cfg[key] = value
		end
	end
end

local function saveConfig()
	env.YannyConfig = cfg
	if canSave then
		pcall(function()
			writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
		end)
	end
end

loadConfig()

-- ==================== REMOTES ====================
local ExchangeGoodsRE, LuckPetRF

task.spawn(function()
	local function find(path)
		local obj = ReplicatedStorage
		for _, name in ipairs(path) do
			obj = obj and obj:WaitForChild(name, 10)
		end
		return obj
	end
	ExchangeGoodsRE = find({ "Remote", "Season_Server", "ExchangeGoodsRE" })
	LuckPetRF = find({ "Remote", "Season_Server", "LuckPetRF" })
	if not ExchangeGoodsRE then warn("Yanny Scripts: shop remote not found") end
	if not LuckPetRF then warn("Yanny Scripts: pet spin remote not found") end
end)

-- ==================== UI HELPERS ====================
local C = {
	BG = Color3.fromRGB(18, 16, 28),
	Surface = Color3.fromRGB(30, 26, 48),
	Surface2 = Color3.fromRGB(24, 21, 38),
	Border = Color3.fromRGB(70, 60, 130),
	Text = Color3.fromRGB(240, 238, 250),
	Muted = Color3.fromRGB(150, 145, 185),
	Purple = Color3.fromRGB(104, 84, 255),
	PurpleHover = Color3.fromRGB(126, 108, 255),
	PurpleLight = Color3.fromRGB(150, 130, 255),
	Off = Color3.fromRGB(52, 46, 84),
	Success = Color3.fromRGB(110, 225, 150),
	Danger = Color3.fromRGB(255, 90, 90),
}

local function tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

local function new(class, props, parent)
	local obj = Instance.new(class)
	for key, value in pairs(props) do
		obj[key] = value
	end
	obj.Parent = parent
	return obj
end

local function round(obj, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius) }, obj)
end

local function stroke(obj, color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, obj)
end

local function notify(title, text)
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 5 })
	end)
end

-- ==================== WINDOW ====================
local WIDTH, HEIGHT, TOPBAR = 470, 300, 34

local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("YannyHub")
if oldGui then
	oldGui:Destroy()
end

local gui = new("ScreenGui", {
	Name = "YannyHub",
	ResetOnSpawn = false,
	DisplayOrder = 999,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local main = new("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(WIDTH, HEIGHT),
	Position = UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2),
	BackgroundColor3 = C.BG,
	BorderSizePixel = 0,
	Active = true,
	ClipsDescendants = true,
}, gui)
round(main, 14)
stroke(main, C.Border, 1, 0.3)

-- Top bar
local topbar = new("Frame", {
	Size = UDim2.new(1, 0, 0, TOPBAR),
	BackgroundTransparency = 1,
	Active = true,
}, main)

new("TextLabel", {
	Size = UDim2.new(1, -90, 1, 0),
	Position = UDim2.fromOffset(14, 0),
	BackgroundTransparency = 1,
	RichText = true,
	Text = 'Yanny Scripts  <font color="rgb(150,145,185)" size="11">Loot To Forge</font>',
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = C.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
}, topbar)

local function makeTopButton(text, xOffset)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(26, 22),
		Position = UDim2.new(1, xOffset, 0, 6),
		BackgroundColor3 = C.Surface,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.Muted,
		AutoButtonColor = false,
	}, topbar)
	round(b, 6)
	return b
end

local minButton = makeTopButton("–", -64)
local closeButton = makeTopButton("×", -34)

new("Frame", {
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.fromOffset(0, TOPBAR),
	BackgroundColor3 = C.Border,
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
}, main)

-- Body (everything under the top bar)
local body = new("Frame", {
	Size = UDim2.new(1, 0, 1, -(TOPBAR + 1)),
	Position = UDim2.fromOffset(0, TOPBAR + 1),
	BackgroundTransparency = 1,
}, main)

-- Sidebar
local SIDEBAR_W = 120
local sidebar = new("Frame", {
	Size = UDim2.new(0, SIDEBAR_W, 1, 0),
	BackgroundTransparency = 1,
	Active = true,
}, body)

new("Frame", {
	Size = UDim2.new(0, 1, 1, 0),
	Position = UDim2.fromOffset(SIDEBAR_W, 0),
	BackgroundColor3 = C.Border,
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
}, body)

-- User chip (bottom of sidebar)
local chip = new("Frame", {
	Size = UDim2.new(1, -16, 0, 40),
	Position = UDim2.new(0, 8, 1, -48),
	BackgroundColor3 = C.Surface,
}, sidebar)
round(chip, 10)
stroke(chip, C.Border, 1, 0.6)

local avatar = new("Frame", {
	Size = UDim2.fromOffset(24, 24),
	Position = UDim2.new(0, 8, 0.5, -12),
	BackgroundColor3 = C.Purple,
	BorderSizePixel = 0,
}, chip)
round(avatar, 12)
new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = string.upper(string.sub(player.DisplayName, 1, 1)),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = Color3.new(1, 1, 1),
}, avatar)

new("TextLabel", {
	Size = UDim2.new(1, -44, 0, 16),
	Position = UDim2.fromOffset(38, 5),
	BackgroundTransparency = 1,
	Text = player.DisplayName,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = C.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, chip)

local statusLabel = new("TextLabel", {
	Size = UDim2.new(1, -44, 0, 14),
	Position = UDim2.fromOffset(38, 21),
	BackgroundTransparency = 1,
	Text = "Idle",
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextColor3 = C.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
}, chip)

local function refreshStatus()
	local active = cfg.autoBuy or cfg.petSpin
	statusLabel.Text = active and "Running" or "Idle"
	statusLabel.TextColor3 = active and C.Success or C.Muted
end

-- Content area
local content = new("Frame", {
	Size = UDim2.new(1, -(SIDEBAR_W + 1), 1, 0),
	Position = UDim2.fromOffset(SIDEBAR_W + 1, 0),
	BackgroundTransparency = 1,
}, body)

local function makePage()
	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Purple,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, content)
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, page)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, page)
	return page
end

-- ==================== ROW BUILDERS ====================
local function makeSection(page, order, text)
	return new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = string.upper(text),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = C.PurpleLight,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, page)
end

local function makeHint(page, order, text)
	return new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = C.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = order,
	}, page)
end

local function makeRowLabel(parent, text)
	return new("TextLabel", {
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
end

local function makeInfoRow(page, order, text)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = C.Surface2,
		LayoutOrder = order,
	}, page)
	round(row, 10)
	stroke(row, C.Border, 1, 0.7)
	local label = makeRowLabel(row, text)
	label.TextColor3 = C.Muted
	label.TextSize = 12
	return new("TextLabel", {
		Size = UDim2.new(0, 60, 1, 0),
		Position = UDim2.new(1, -72, 0, 0),
		BackgroundTransparency = 1,
		Text = "0",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
end

local function makeToggleRow(page, order, text, initial, onChange)
	local row = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C.Surface,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
	}, page)
	round(row, 10)
	stroke(row, C.Border, 1, 0.5)
	makeRowLabel(row, text)

	local track = new("Frame", {
		Size = UDim2.fromOffset(40, 20),
		Position = UDim2.new(1, -54, 0.5, -10),
		BackgroundColor3 = C.Off,
		BorderSizePixel = 0,
	}, row)
	round(track, 10)

	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = Color3.fromRGB(190, 185, 215),
		BorderSizePixel = 0,
	}, track)
	round(knob, 7)

	local state = initial
	local function render(animate)
		local t = animate and 0.15 or 0
		tween(track, { BackgroundColor3 = state and C.Purple or C.Off }, t)
		tween(knob, {
			Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(190, 185, 215),
		}, t)
	end
	render(false)

	connect(row.MouseButton1Click, function()
		local nextState = not state
		if onChange and onChange(nextState) == false then
			return
		end
		state = nextState
		render(true)
	end)
end

local function makeButtonRow(page, order, text, buttonText, onClick)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C.Surface,
		LayoutOrder = order,
	}, page)
	round(row, 10)
	stroke(row, C.Border, 1, 0.5)
	makeRowLabel(row, text)

	local button = new("TextButton", {
		Size = UDim2.fromOffset(96, 26),
		Position = UDim2.new(1, -108, 0.5, -13),
		BackgroundColor3 = C.Purple,
		Text = buttonText,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
	}, row)
	round(button, 8)

	connect(button.MouseEnter, function()
		tween(button, { BackgroundColor3 = C.PurpleHover })
	end)
	connect(button.MouseLeave, function()
		tween(button, { BackgroundColor3 = C.Purple })
	end)
	connect(button.MouseButton1Click, onClick)
	return button
end

local function makeDropdown(page, order, text, options, selectedMap, onChange)
	local ROW, OPT = 40, 30
	local listHeight = #options * OPT + 8
	local open = false

	local container = new("Frame", {
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, page)

	local header = new("TextButton", {
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundColor3 = C.Surface,
		Text = "",
		AutoButtonColor = false,
	}, container)
	round(header, 10)
	stroke(header, C.Border, 1, 0.5)
	makeRowLabel(header, text)

	local summary = new("TextLabel", {
		Size = UDim2.new(0, 110, 1, 0),
		Position = UDim2.new(1, -122, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = C.PurpleLight,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, header)

	local list = new("Frame", {
		Size = UDim2.new(1, 0, 0, listHeight),
		Position = UDim2.fromOffset(0, ROW + 4),
		BackgroundColor3 = C.Surface2,
		Visible = false,
	}, container)
	round(list, 10)
	stroke(list, C.Border, 1, 0.5)

	local function updateSummary()
		local count = 0
		for _, name in ipairs(options) do
			if selectedMap[name] then
				count += 1
			end
		end
		local label
		if count == 0 then
			label = "None"
		elseif count == #options then
			label = "All"
		else
			label = count .. " selected"
		end
		summary.Text = label .. (open and "  ▲" or "  ▼")
	end

	for i, name in ipairs(options) do
		local opt = new("TextButton", {
			Size = UDim2.new(1, -12, 0, OPT - 4),
			Position = UDim2.fromOffset(6, 4 + (i - 1) * OPT),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
		}, list)

		local box = new("Frame", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 8, 0.5, -8),
			BackgroundColor3 = C.Off,
			BorderSizePixel = 0,
		}, opt)
		round(box, 4)

		local check = new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "✓",
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.new(1, 1, 1),
			Visible = false,
		}, box)

		new("TextLabel", {
			Size = UDim2.new(1, -40, 1, 0),
			Position = UDim2.fromOffset(34, 0),
			BackgroundTransparency = 1,
			Text = name,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = C.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, opt)

		local function render()
			local on = selectedMap[name]
			box.BackgroundColor3 = on and C.Purple or C.Off
			check.Visible = on and true or false
		end
		render()

		connect(opt.MouseButton1Click, function()
			selectedMap[name] = not selectedMap[name]
			render()
			updateSummary()
			if onChange then
				onChange()
			end
		end)
	end

	connect(header.MouseButton1Click, function()
		open = not open
		list.Visible = open
		container.Size = UDim2.new(1, 0, 0, open and (ROW + 4 + listHeight) or ROW)
		updateSummary()
	end)

	updateSummary()
end

-- ==================== FEATURE LOOPS ====================
local buyActive, spinActive = false, false
local buyCount, spinCount = 0, 0
local buyLabel, spinLabel

local function startBuyLoop()
	if buyActive then return end
	buyActive = true
	task.spawn(function()
		while running and cfg.autoBuy do
			local didBuy = false
			for _, item in ipairs(SHOP_ITEMS) do
				if not (running and cfg.autoBuy) then break end
				if cfg.items[item.name] and ExchangeGoodsRE then
					pcall(function()
						ExchangeGoodsRE:FireServer(item.id)
					end)
					buyCount += 1
					if buyLabel and buyLabel.Parent then
						buyLabel.Text = tostring(buyCount)
					end
					didBuy = true
					task.wait(BUY_ITEM_DELAY)
				end
			end
			task.wait(didBuy and BUY_CYCLE_DELAY or 1)
		end
		buyActive = false
	end)
end

local function startSpinLoop()
	if spinActive then return end
	spinActive = true
	task.spawn(function()
		while running and cfg.petSpin do
			if LuckPetRF then
				local ok, err = pcall(function()
					return LuckPetRF:InvokeServer()
				end)
				if ok then
					spinCount += 1
					if spinLabel and spinLabel.Parent then
						spinLabel.Text = tostring(spinCount)
					end
					task.wait(SPIN_DELAY)
				else
					warn("LuckPetRF error:", err)
					task.wait(1)
				end
			else
				task.wait(1)
			end
		end
		spinActive = false
	end)
end

-- ==================== REJOIN / AUTO EXECUTE ====================
local queueFn = queue_on_teleport
	or (syn and syn.queue_on_teleport)
	or (fluxus and fluxus.queue_on_teleport)

local function urlReady()
	return not string.find(SCRIPT_URL, "YOURUSERNAME", 1, true)
end

local busy = false
local queued = false
local rejoinButton

local function rejoinFailed()
	queued = false
	if rejoinButton and rejoinButton.Parent then
		rejoinButton.Text = "Failed"
	end
	task.delay(2, function()
		busy = false
		if rejoinButton and rejoinButton.Parent then
			rejoinButton.Text = "Rejoin"
		end
	end)
end

local function rejoin()
	if busy then return end
	busy = true
	if rejoinButton and rejoinButton.Parent then
		rejoinButton.Text = "Rejoining..."
	end

	local ok, err = pcall(function()
		local isPrivate = game.PrivateServerId ~= ""
		if #Players:GetPlayers() <= 1 and not isPrivate then
			-- Alone in a public server: it closes when you leave, so join a fresh one
			TeleportService:Teleport(game.PlaceId, player)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		end
	end)

	if not ok then
		warn("Rejoin failed:", err)
		rejoinFailed()
	end
end

-- Queue the hub to run again whenever a teleport starts
connect(player.OnTeleport, function(state)
	if cfg.autoExec and queueFn and urlReady() and not queued
		and state == Enum.TeleportState.Started then
		queued = true
		pcall(queueFn, string.format('loadstring(game:HttpGet("%s"))()', SCRIPT_URL))
	end
end)

connect(TeleportService.TeleportInitFailed, function(plr, result, message)
	if plr == player then
		warn("Teleport failed:", result, message)
		rejoinFailed()
	end
end)

-- ==================== PAGES ====================
local tabs = {}
local tabOrder = { "Shop", "Pets", "System" }

-- Shop
local shopPage = makePage()
makeSection(shopPage, 1, "Season Exchange")
makeToggleRow(shopPage, 2, "Auto buy", cfg.autoBuy, function(state)
	cfg.autoBuy = state
	saveConfig()
	refreshStatus()
	if state then
		startBuyLoop()
	end
end)

local itemNames = {}
for _, item in ipairs(SHOP_ITEMS) do
	table.insert(itemNames, item.name)
end
makeDropdown(shopPage, 3, "Items to buy", itemNames, cfg.items, saveConfig)
buyLabel = makeInfoRow(shopPage, 4, "Purchases sent")
makeHint(shopPage, 5, "Only checked items are bought. Your selection is saved automatically.")

-- Pets
local petsPage = makePage()
makeSection(petsPage, 1, "Pet Spin")
makeToggleRow(petsPage, 2, "Auto pet spin", cfg.petSpin, function(state)
	cfg.petSpin = state
	saveConfig()
	refreshStatus()
	if state then
		startSpinLoop()
	end
end)
spinLabel = makeInfoRow(petsPage, 3, "Spins sent")

-- System
local systemPage = makePage()
makeSection(systemPage, 1, "Rejoin")
rejoinButton = makeButtonRow(systemPage, 2, "Rejoin server", "Rejoin", rejoin)
makeSection(systemPage, 3, "Auto Execute")
makeToggleRow(systemPage, 4, "Auto execute after rejoin", cfg.autoExec, function(state)
	if state then
		if not queueFn then
			notify("Yanny Scripts", "Your executor doesn't support queue_on_teleport.")
			return false
		end
		if not urlReady() then
			notify("Yanny Scripts", "Set SCRIPT_URL at the top of the script first.")
			return false
		end
	end
	cfg.autoExec = state
	saveConfig()
end)
makeHint(systemPage, 5, "All toggles and selections save automatically and come back after you rejoin.")

local pages = { Shop = shopPage, Pets = petsPage, System = systemPage }

-- ==================== SIDEBAR TABS ====================
local function setTab(name)
	for tabName, data in pairs(tabs) do
		local active = tabName == name
		data.page.Visible = active
		data.bar.Visible = active
		data.button.TextColor3 = active and C.Text or C.Muted
		tween(data.button, { BackgroundTransparency = active and 0 or 1 }, 0.12)
	end
end

for i, name in ipairs(tabOrder) do
	local button = new("TextButton", {
		Size = UDim2.new(1, -16, 0, 32),
		Position = UDim2.new(0, 8, 0, 10 + (i - 1) * 38),
		BackgroundColor3 = C.Surface,
		BackgroundTransparency = 1,
		Text = name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	}, sidebar)
	round(button, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16) }, button)

	local bar = new("Frame", {
		Size = UDim2.fromOffset(3, 16),
		Position = UDim2.new(0, -12, 0.5, -8),
		BackgroundColor3 = C.Purple,
		BorderSizePixel = 0,
		Visible = false,
	}, button)
	round(bar, 2)

	tabs[name] = { button = button, page = pages[name], bar = bar }
	connect(button.MouseButton1Click, function()
		setTab(name)
	end)
end

-- ==================== TOP BAR BUTTONS ====================
local minimized = false
connect(minButton.MouseButton1Click, function()
	minimized = not minimized
	body.Visible = not minimized
	main.Size = UDim2.fromOffset(WIDTH, minimized and TOPBAR or HEIGHT)
	minButton.Text = minimized and "+" or "–"
end)

local function shutdown()
	running = false
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
	gui:Destroy()
end
env.YannyHubShutdown = shutdown

connect(closeButton.MouseButton1Click, shutdown)
connect(closeButton.MouseEnter, function()
	tween(closeButton, { TextColor3 = C.Danger })
end)
connect(closeButton.MouseLeave, function()
	tween(closeButton, { TextColor3 = C.Muted })
end)
connect(minButton.MouseEnter, function()
	tween(minButton, { TextColor3 = C.Text })
end)
connect(minButton.MouseLeave, function()
	tween(minButton, { TextColor3 = C.Muted })
end)

-- ==================== DRAGGING ====================
local dragging = false
local dragStart, startPos

local function makeDraggable(handle)
	connect(handle.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
end
makeDraggable(topbar)
makeDraggable(sidebar)

connect(UserInputService.InputChanged, function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

-- ==================== START ====================
setTab("Shop")
refreshStatus()

-- Bring back whatever was running before the rejoin
if cfg.autoBuy then
	task.delay(2, startBuyLoop)
end
if cfg.petSpin then
	task.delay(2, startSpinLoop)
end
