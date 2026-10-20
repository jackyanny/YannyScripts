if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- ==================== SETTINGS ====================
local CONFIG_FILE = "YannyPotions_Config.json"
local POTION_IDS = { "12", "13" }   -- Power Potion, Damage Potion
local ITEM_DELAY = 0.5              -- seconds between each purchase
local CYCLE_DELAY = 1               -- seconds between rounds
-- ==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

-- If executed again, shut the old copy down first
if env.YannyPotionsShutdown then
	pcall(env.YannyPotionsShutdown)
end

local running = true
local connections = {}

local function connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(connections, conn)
	return conn
end

-- ==================== SAVED SETTINGS ====================
local canSave = (writefile and readfile and isfile) and true or false
local cfg = { autoBuy = false }

do
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
	if not saved and type(env.YannyPotionsConfig) == "table" then
		saved = env.YannyPotionsConfig
	end
	if saved and type(saved.autoBuy) == "boolean" then
		cfg.autoBuy = saved.autoBuy
	end
end

local function saveConfig()
	env.YannyPotionsConfig = cfg
	if canSave then
		pcall(function()
			writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
		end)
	end
end

-- ==================== SHOP REMOTE ====================
local ExchangeGoodsRE

task.spawn(function()
	local obj = ReplicatedStorage
	for _, name in ipairs({ "Remote", "Season_Server", "ExchangeGoodsRE" }) do
		obj = obj and obj:WaitForChild(name, 10)
	end
	ExchangeGoodsRE = obj
	if not ExchangeGoodsRE then
		warn("Yanny Scripts: shop remote not found")
	end
end)

-- ==================== BUY LOOP ====================
local looping = false

local function startLoop()
	if looping then return end
	looping = true
	task.spawn(function()
		while running and cfg.autoBuy do
			for _, id in ipairs(POTION_IDS) do
				if not (running and cfg.autoBuy) then break end
				if ExchangeGoodsRE then
					pcall(function()
						ExchangeGoodsRE:FireServer(id)
					end)
				end
				task.wait(ITEM_DELAY)
			end
			task.wait(CYCLE_DELAY)
		end
		looping = false
	end)
end

-- ==================== UI ====================
local BG = Color3.fromRGB(18, 16, 28)
local PURPLE = Color3.fromRGB(104, 84, 255)
local PURPLE_HOVER = Color3.fromRGB(126, 108, 255)
local PURPLE_OFF = Color3.fromRGB(58, 50, 110)
local MUTED = Color3.fromRGB(150, 145, 185)

local function tween(obj, props)
	TweenService:Create(obj, TweenInfo.new(0.15, Enum.EasingStyle.Quad), props):Play()
end

local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("YannyPotions")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "YannyPotions"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 190, 0, 108)
frame.Position = UDim2.new(0, 20, 0.5, -54)
frame.BackgroundColor3 = BG
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 14)
frameCorner.Parent = frame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(70, 60, 130)
frameStroke.Thickness = 1
frameStroke.Transparency = 0.4
frameStroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 24)
title.Position = UDim2.new(0, 0, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Yanny Scripts"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.Parent = frame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 22, 0, 22)
closeButton.Position = UDim2.new(1, -28, 0, 6)
closeButton.BackgroundTransparency = 1
closeButton.Text = "X"
closeButton.TextColor3 = MUTED
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 12
closeButton.AutoButtonColor = false
closeButton.Parent = frame

local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -24, 0, 46)
button.Position = UDim2.new(0, 12, 0, 34)
button.BackgroundColor3 = PURPLE_OFF
button.Text = "Auto Buy: OFF"
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 16
button.AutoButtonColor = false
button.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = button

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, 0, 0, 16)
sub.Position = UDim2.new(0, 0, 0, 86)
sub.BackgroundTransparency = 1
sub.Text = "Power + Damage Potion"
sub.TextColor3 = MUTED
sub.Font = Enum.Font.Gotham
sub.TextSize = 10
sub.Parent = frame

local function render()
	button.Text = cfg.autoBuy and "Auto Buy: ON" or "Auto Buy: OFF"
	tween(button, { BackgroundColor3 = cfg.autoBuy and PURPLE or PURPLE_OFF })
end

connect(button.MouseButton1Click, function()
	cfg.autoBuy = not cfg.autoBuy
	saveConfig()
	render()
	if cfg.autoBuy then
		startLoop()
	end
end)
connect(button.MouseEnter, function()
	tween(button, { BackgroundColor3 = cfg.autoBuy and PURPLE_HOVER or Color3.fromRGB(78, 68, 140) })
end)
connect(button.MouseLeave, function()
	tween(button, { BackgroundColor3 = cfg.autoBuy and PURPLE or PURPLE_OFF })
end)

-- Close
local function shutdown()
	running = false
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
	gui:Destroy()
end
env.YannyPotionsShutdown = shutdown

connect(closeButton.MouseButton1Click, shutdown)
connect(closeButton.MouseEnter, function()
	tween(closeButton, { TextColor3 = Color3.fromRGB(255, 90, 90) })
end)
connect(closeButton.MouseLeave, function()
	tween(closeButton, { TextColor3 = MUTED })
end)

-- Drag
local dragging = false
local dragStart, startPos

connect(frame.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end
end)

connect(UserInputService.InputChanged, function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
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
render()

-- If it was ON before you rejoined, pick up right where it left off
if cfg.autoBuy then
	task.delay(2, startLoop)
end
