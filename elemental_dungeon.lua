-- ======================================================
-- AUTOFARM ULTIME – VERSION GUI V15 (GAME OFFICIAL 3-COLUMN LAYOUT)
-- Style officiel "Dungeon Creator" - Format Paysage, FredokaOne, Zéro Emojis, Tout en Anglais
-- ======================================================

repeat
	task.wait()
until game:IsLoaded()

-- 1. SERVICES DE BASE
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

-- 2. CHEMINS DIRECTS VERS LES SERVICES
local Services = ReplicatedStorage.ReplicatedStorage.Packages.Knit.Services

-- 3. RÉCUPÉRATION DES SERVICES
local WeaponService = Services:FindFirstChild("WeaponService")
local AttackService = Services:FindFirstChild("AttackService")
local DungeonService = Services:FindFirstChild("DungeonService")
local PartyService = Services:FindFirstChild("PartyService")
local InventoryService = Services:FindFirstChild("InventoryService")
local DropsService = Services:FindFirstChild("DropsService")
local HealingService = Services:FindFirstChild("HealingService")
local AFKService = Services:FindFirstChild("AFKService")

if not WeaponService or not DungeonService then
	print("Knit Services not found!")
	return
end

-- 4. REMOTES
local UseSword = WeaponService.RF and WeaponService.RF:FindFirstChild("UseSword")
local UseAbility = AttackService and AttackService.RF and AttackService.RF:FindFirstChild("UseAbility")
local StartDungeon = DungeonService.RF and DungeonService.RF:FindFirstChild("StartDungeon")
local VoteOn = PartyService and PartyService.RF and PartyService.RF:FindFirstChild("VoteOn")
local CollectDrop = DropsService and DropsService.RF and DropsService.RF:FindFirstChild("CollectDrop")
local UseHeal = HealingService and HealingService.RF and HealingService.RF:FindFirstChild("UseHeal")
local Sell = InventoryService and InventoryService.RF and InventoryService.RF:FindFirstChild("Sell")

if not UseSword or not StartDungeon then
	print("Critical Remotes not found!")
	return
end

-- ============================================================
-- 5. SCAN DES DONJONS ET DIFFICULTÉS
-- ============================================================

local function scanDungeons()
	local list = {}
	local sharedModules = ReplicatedStorage.ReplicatedStorage.SharedModules
	if sharedModules then
		local dungeonsFolder = sharedModules:FindFirstChild("Dungeons")
		if dungeonsFolder then
			local dungeonsData = dungeonsFolder:FindFirstChild("DungeonsData")
			if dungeonsData then
				for _, child in ipairs(dungeonsData:GetChildren()) do
					if child:IsA("ModuleScript") then
						local name = child.Name:gsub("Dungeon", "")
						if name ~= "" and not name:find("Misc") then
							table.insert(list, name)
						end
					end
				end
			end
		end
	end
	if #list == 0 then
		list = { "Beginners", "Jungle", "Underwater", "Fire", "Cloud", "SnowCastle" }
	end
	table.sort(list)
	return list
end

local DUNGEONS_LIST = scanDungeons()
local DIFFICULTIES_LIST = { "Easy", "Medium", "Hard", "Hell" } -- Updated to match screenshot

-- ============================================================
-- 6. SCAN DES ARMES ET COMPÉTENCES
-- ============================================================

function getAvailableTools()
	local tools = {"Aucun"}
	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool.Name)
			end
		end
	end
	local character = LocalPlayer.Character
	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") and not table.find(tools, tool.Name) then
				table.insert(tools, tool.Name)
			end
		end
	end
	return tools
end

-- ============================================================
-- 7. CONFIGURATION HAUTEMENT PERSONNALISABLE
-- ============================================================

local CONFIG = {
	AutoFarm = false,
	AutoAttack = true,
	AutoHeal = true,
	AutoCollect = true,
	AutoEquip = true,
	AutoSkills = true,
	AutoSell = true,
	AutoRetry = true,
	AutoJoinDungeon = true,

	-- Équipement intelligent
	EquipMode = "Both",
	SelectedWeapon = "Aucun",
	SelectedElement = "Aucun",

	-- Combat Settings
	SwingDelayMin = 0.08,
	SwingDelayMax = 0.20,
	AttackMode = "Sword & Skills",
	MaxAttackDistance = 15,
	
	-- Position & TP
	TP_Offset_X = 0,
	TP_Offset_Y = -3,
	TP_Offset_Z = 0,
	TP_Distance = 3,
	TP_Position = "Bottom",
	RandomizeOffset = false,
	RandomOffsetRange = 1,
	
	-- Skills
	SelectedSkills = { 1, 2, 3, 4 },
	SkillDelay = 0.5,

	-- Dungeon
	DungeonName = DUNGEONS_LIST[1] or "Beginners",
	Difficulty = "Easy",
	RetryDelay = 2.5,

	-- Healing
	HealThreshold = 0.3,
	
	-- AutoSell Rarities
	SellCommon = true,
	SellUncommon = false,
	SellRare = false,
	
	-- Safety & Physics & Rendering
	TweenSpeed = 60,
	NoclipPermanent = false,
	WalkSpeed = 16,
	JumpPower = 50,
	Disable3DRendering = false,
}

-- 8. STATISTIQUES
local STATS = {
	Kills = 0,
	Dungeons = 0,
	LootCollected = 0,
	ItemsSold = 0,
	StartTime = os.time(),
}

-- ============================================================
-- 9. FONCTIONS DE L'AUTOFARM
-- ============================================================

local isTweening = false
local monitoredMobs = {}
local activeTarget = nil

RunService.Stepped:Connect(function()
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")

	if (isTweening or CONFIG.NoclipPermanent or (CONFIG.AutoFarm and activeTarget)) and character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end

	if CONFIG.AutoFarm and activeTarget and activeTarget.Parent and hrp and not isTweening then
		local mobPart = activeTarget:FindFirstChild("HumanoidRootPart") or activeTarget:FindFirstChild("PrimaryPart")
		if mobPart then
			local targetPos = getPositionOffset(mobPart)
			hrp.CFrame = CFrame.new(targetPos)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		pcall(function()
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChild("Humanoid")
			if humanoid then
				if CONFIG.WalkSpeed ~= 16 then
					humanoid.WalkSpeed = CONFIG.WalkSpeed
				end
				if CONFIG.JumpPower ~= 50 then
					humanoid.JumpPower = CONFIG.JumpPower
				end
			end
		end)
	end
end)

function getPositionOffset(mobPart)
	local mobPos = mobPart.Position
	local offset = Vector3.new(CONFIG.TP_Offset_X, CONFIG.TP_Offset_Y, CONFIG.TP_Offset_Z)
	local distance = CONFIG.TP_Distance
	local posMode = CONFIG.TP_Position

	local direction = Vector3.new(0, 0, 0)
	if posMode == "Top" then
		direction = Vector3.new(0, distance, 0)
	elseif posMode == "Bottom" then
		direction = Vector3.new(0, -distance, 0)
	elseif posMode == "Behind" then
		direction = -mobPart.CFrame.LookVector * distance
	elseif posMode == "Front" then
		direction = mobPart.CFrame.LookVector * distance
	elseif posMode == "Left" then
		direction = -mobPart.CFrame.RightVector * distance
	elseif posMode == "Right" then
		direction = mobPart.CFrame.RightVector * distance
	end

	local baseTarget = mobPos + direction + offset
	if CONFIG.RandomizeOffset then
		local rRange = CONFIG.RandomOffsetRange
		local rx = math.random(-rRange * 100, rRange * 100) / 100
		local ry = math.random(-rRange * 100, rRange * 100) / 100
		local rz = math.random(-rRange * 100, rRange * 100) / 100
		baseTarget = baseTarget + Vector3.new(rx, ry, rz)
	end
	return baseTarget
end

function tweenToPosition(position)
	local character = LocalPlayer.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local distance = (hrp.Position - position).Magnitude
	local duration = distance / CONFIG.TweenSpeed
	if duration < 0.05 then duration = 0.05 end

	isTweening = true
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tween = TweenService:Create(hrp, tweenInfo, { CFrame = CFrame.new(position) })
	tween:Play()
	tween.Completed:Wait()
	isTweening = false
end

function tweenToMob(mob)
	local mobPart = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("PrimaryPart")
	if not mobPart then return end
	local targetPos = getPositionOffset(mobPart)
	tweenToPosition(targetPos)
end

function getAliveMobs()
	local mobs = {}
	local mobContainer = Workspace:FindFirstChild("Mobs")
	if not mobContainer then return mobs end

	for _, mob in ipairs(mobContainer:GetChildren()) do
		if mob:IsA("Model") then
			local humanoid = mob:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local primaryPart = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("PrimaryPart")
				if primaryPart then
					table.insert(mobs, mob)
				end
			end
		end
	end
	return mobs
end

function getClosestMob()
	local currentTarget = nil
	local mobs = getAliveMobs()
	if #mobs == 0 then
		activeTarget = nil
		return nil
	end

	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		activeTarget = mobs[1]
		return mobs[1]
	end

	local closest = nil
	local closestDist = math.huge
	for _, mob in ipairs(mobs) do
		local mobPart = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("PrimaryPart")
		if mobPart then
			local dist = (hrp.Position - mobPart.Position).Magnitude
			if dist < closestDist then
				closestDist = dist
				closest = mob
			end
		end
	end
	
	currentTarget = closest or mobs[1]
	activeTarget = currentTarget
	
	-- Increment kills reliably
	if currentTarget and not monitoredMobs[currentTarget] then
		monitoredMobs[currentTarget] = true
		local humanoid = currentTarget:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				STATS.Kills = STATS.Kills + 1
				monitoredMobs[currentTarget] = nil
				if activeTarget == currentTarget then activeTarget = nil end
			end)
		end
		currentTarget.Destroying:Connect(function()
			monitoredMobs[currentTarget] = nil
			if activeTarget == currentTarget then activeTarget = nil end
		end)
	end

	return currentTarget
end

function swing()
	pcall(function()
		UseSword:InvokeServer()
	end)
end

function useSkill(slot)
	if UseAbility then
		pcall(function()
			UseAbility:InvokeServer(slot)
		end)
	end
end

-- Map difficulty names for the remote
local DIFFICULTY_MAP = {
	["Easy"] = "Easy",
	["Medium"] = "Normal",
	["Hard"] = "Hard",
	["Hell"] = "Hell"
}

function createDungeon(name, difficulty)
	local remoteDiff = DIFFICULTY_MAP[difficulty] or "Easy"
	pcall(function()
		StartDungeon:InvokeServer(name, remoteDiff)
	end)
end

function retry()
	if VoteOn then
		pcall(function()
			VoteOn:InvokeServer("Retry")
		end)
	end
end

function collectDrop(drop)
	if CollectDrop then
		pcall(function()
			CollectDrop:InvokeServer(drop)
		end)
	end
end

function autoEquipSpecific(toolName)
	if not CONFIG.AutoEquip then return end
	if not toolName or toolName == "Aucun" or toolName == "" then return end
	
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool and equippedTool.Name == toolName then
		return
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		local tool = backpack:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then
			humanoid:EquipTool(tool)
			task.wait(0.05)
		end
	end
end

function autoCollect()
	if not CONFIG.AutoCollect then return end
	local drops = Workspace:FindFirstChild("Drops")
	if not drops then return end

	for _, drop in ipairs(drops:GetChildren()) do
		if drop:IsA("Part") and drop:FindFirstChild("TouchInterest") then
			collectDrop(drop)
			STATS.LootCollected = STATS.LootCollected + 1
			task.wait(0.05)
		end
	end
end

function autoSell()
	if not CONFIG.AutoSell or not Sell then return end
	local inventory = LocalPlayer:FindFirstChild("Inventory")
	if not inventory then return end

	for _, item in ipairs(inventory:GetChildren()) do
		local rarity = item:FindFirstChild("Rarity")
		if rarity then
			local shouldSell = false
			if rarity.Value == "Common" and CONFIG.SellCommon then
				shouldSell = true
			elseif rarity.Value == "Uncommon" and CONFIG.SellUncommon then
				shouldSell = true
			elseif rarity.Value == "Rare" and CONFIG.SellRare then
				shouldSell = true
			end

			if shouldSell then
				pcall(function()
					Sell:InvokeServer(item)
					STATS.ItemsSold = STATS.ItemsSold + 1
					task.wait(0.08)
				end)
			end
		end
	end
end

function antiAFK()
	task.spawn(function()
		while CONFIG.AutoFarm do
			task.wait(20)
			pcall(function()
				VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
				task.wait(0.05)
				VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
			end)
		end
	end)
end

-- 10. MAIN BOT LOOP
local isRunning = false
local loopThread = nil

function stopFarm()
	isRunning = false
	activeTarget = nil
	if loopThread then
		task.cancel(loopThread)
		loopThread = nil
	end
end

function startFarm()
	if isRunning then return end
	isRunning = true
	STATS.StartTime = os.time()
	antiAFK()

	loopThread = task.spawn(function()
		local loopCounter = 0
		while isRunning do
			loopCounter = loopCounter + 1

			-- Auto-heal (using game standard healing remote)
			if CONFIG.AutoHeal and UseHeal then
				local character = LocalPlayer.Character
				local humanoid = character and character:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health / humanoid.MaxHealth < CONFIG.HealThreshold then
					pcall(function() UseHeal:InvokeServer() end)
					task.wait(0.3)
				end
			end

			-- Auto-Attack
			if CONFIG.AutoAttack then
				local target = getClosestMob()
				if target then
					tweenToMob(target)
					
					local targetPart = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("PrimaryPart")
					local character = LocalPlayer.Character
					local hrp = character and character:FindFirstChild("HumanoidRootPart")
					local inRange = true
					if targetPart and hrp then
						inRange = (hrp.Position - targetPart.Position).Magnitude <= CONFIG.MaxAttackDistance
					end

					if inRange then
						local mode = CONFIG.EquipMode
						if mode == "Weapon Only" or mode == "Both" then
							autoEquipSpecific(CONFIG.SelectedWeapon)
							if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
								swing()
							end
						end

						if CONFIG.AutoSkills and UseAbility and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
							if mode == "Element Only" or mode == "Both" then
								autoEquipSpecific(CONFIG.SelectedElement)
							end
							for _, slot in ipairs(CONFIG.SelectedSkills) do
								if math.random(1, 3) == 1 then
									task.spawn(useSkill, slot)
								end
							end
						end
					end
				else
					activeTarget = nil
				end
			end

			if CONFIG.AutoCollect and loopCounter % 15 == 0 then
				task.spawn(autoCollect)
			end

			if CONFIG.AutoSell and loopCounter % 50 == 0 then
				task.spawn(autoSell)
			end

			-- Retry & Auto Join Dungeon
			if CONFIG.AutoRetry and loopCounter % 12 == 0 then
				local mobs = getAliveMobs()
				if #mobs == 0 then
					activeTarget = nil
					retry()
					task.wait(1.5)
					if #getAliveMobs() == 0 and CONFIG.AutoJoinDungeon then
						task.wait(CONFIG.RetryDelay)
						createDungeon(CONFIG.DungeonName, CONFIG.Difficulty)
						task.wait(2.5)
						STATS.Dungeons = STATS.Dungeons + 1
					end
				end
			end

			local delay = math.random(CONFIG.SwingDelayMin * 100, CONFIG.SwingDelayMax * 100) / 100
			task.wait(delay)
		end
	end)
end

-- ============================================================
-- 11. CRÉATION DE L'INTERFACE AU STYLE OFFICIEL 3 COLONNES
-- ============================================================

local function animateColor(guiObject, property, targetColor, duration)
	TweenService:Create(guiObject, TweenInfo.new(duration or 0.2), {[property] = targetColor}):Play()
end

local function createUltimateGUI()
	-- ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ElementalFarmGUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = CoreGui

	-- Dark Slate Blue color scheme (Roblox Dungeon Creator UI)
	local colorSlateBackground = Color3.fromRGB(36, 50, 67)  -- Main background
	local colorSlatePanel = Color3.fromRGB(24, 38, 51)       -- Dark inner panel boxes
	local colorBorderDark = Color3.fromRGB(15, 22, 30)       -- Black outline
	local colorTextWhite = Color3.fromRGB(255, 255, 255)     -- Plain white text
	
	-- Button gradients (Fredoka style)
	local colorGreenActive = Color3.fromRGB(0, 200, 80)      -- Easy/Create Green
	local colorRedWarning = Color3.fromRGB(220, 50, 50)      -- Exit/Back Red
	local colorBlueSelect = Color3.fromRGB(40, 130, 220)     -- Option Blue

	-- Main Window (Format Paysage 780x450)
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 780, 0, 450)
	mainFrame.Position = UDim2.new(0.5, -390, 0.5, -225)
	mainFrame.BackgroundColor3 = colorSlateBackground
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = true
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui

	-- Thick black 3D border outline
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = colorBorderDark
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = mainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = mainFrame

	-- Window Title: "Dungeon Creator"
	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(0.5, 0, 0, 45)
	titleText.Position = UDim2.new(0, 16, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "Dungeon Creator"
	titleText.TextColor3 = colorTextWhite
	titleText.TextSize = 22
	titleText.Font = Enum.Font.FredokaOne
	
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 1.5
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Parent = titleText
	titleText.Parent = mainFrame

	-- Red round Close Button (Top Right)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -38, 0, 8)
	closeBtn.BackgroundColor3 = colorRedWarning
	closeBtn.Text = "X"
	closeBtn.TextColor3 = colorTextWhite
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.FredokaOne
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0.5, 0)
	closeCorner.Parent = closeBtn

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Thickness = 2
	closeStroke.Color = colorBorderDark
	closeStroke.Parent = closeBtn
	
	local closeGrad = Instance.new("UIGradient")
	closeGrad.Rotation = 90
	closeGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 20, 20))
	})
	closeGrad.Parent = closeBtn
	closeBtn.Parent = mainFrame

	closeBtn.MouseEnter:Connect(function()
		animateColor(closeBtn, "BackgroundColor3", Color3.fromRGB(255, 80, 80))
	end)
	closeBtn.MouseLeave:Connect(function()
		animateColor(closeBtn, "BackgroundColor3", colorRedWarning)
	end)
	closeBtn.MouseButton1Click:Connect(function()
		stopFarm()
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
		screenGui:Destroy()
	end)

	-- ============================================
	-- HELPER WIDGETS
	-- ============================================
	local function createSectionHeader(parent, text)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 24)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 12
		lbl.Font = Enum.Font.FredokaOne
		
		local labelStroke = Instance.new("UIStroke")
		labelStroke.Thickness = 1
		labelStroke.Color = Color3.fromRGB(0, 0, 0)
		labelStroke.Parent = lbl
		return lbl
	end

	local function createToggleRow(parent, label, iconId, configKey, callback)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 32)
		frame.BackgroundTransparency = 1

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 20, 0, 20)
		btn.Position = UDim2.new(0, 4, 0.5, -10)
		btn.BackgroundColor3 = CONFIG[configKey] and colorGreenActive or colorSlateBackground
		btn.Text = CONFIG[configKey] and "✓" or ""
		btn.TextColor3 = colorTextWhite
		btn.TextSize = 11
		btn.Font = Enum.Font.FredokaOne
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
		
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 1.5
		btnStroke.Color = colorBorderDark
		btnStroke.Parent = btn
		btn.Parent = frame

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 32, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = CONFIG[configKey] and colorGreenActive or colorTextInactive
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -52, 1, 0)
		lbl.Position = UDim2.new(0, 52, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		btn.MouseButton1Click:Connect(function()
			CONFIG[configKey] = not CONFIG[configKey]
			animateColor(btn, "BackgroundColor3", CONFIG[configKey] and colorGreenActive or colorSlateBackground)
			icon.ImageColor3 = CONFIG[configKey] and colorGreenActive or colorTextInactive
			btn.Text = CONFIG[configKey] and "✓" or ""
			if callback then callback(CONFIG[configKey]) end
		end)

		frame.Parent = parent
		return frame
	end

	local function createDropdownRow(parent, label, iconId, initialValue, options, callback)
		local isOpened = false
		local itemHeight = 24
		local dropdownRowHeight = 32

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, dropdownRowHeight)
		frame.BackgroundTransparency = 1
		frame.ClipsDescendants = true

		local topRow = Instance.new("Frame")
		topRow.Size = UDim2.new(1, 0, 0, dropdownRowHeight)
		topRow.BackgroundTransparency = 1
		topRow.Parent = frame

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 4, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = colorBlueSelect
		icon.Parent = topRow

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.42, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = topRow

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.5, 0, 0, 24)
		btn.Position = UDim2.new(0.5, 0, 0.5, -12)
		btn.BackgroundColor3 = colorSlateBackground
		btn.Text = tostring(initialValue) .. "  ▼"
		btn.TextColor3 = colorTextWhite
		btn.TextSize = 10
		btn.Font = Enum.Font.FredokaOne
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
		
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 1.5
		btnStroke.Color = colorBorderDark
		btnStroke.Parent = btn
		btn.Parent = topRow

		local optionsListFrame = Instance.new("Frame")
		optionsListFrame.Size = UDim2.new(0.5, 0, 0, 0)
		optionsListFrame.Position = UDim2.new(0.5, 0, 0, dropdownRowHeight)
		optionsListFrame.BackgroundColor3 = colorSlateBackground
		optionsListFrame.BorderSizePixel = 0
		optionsListFrame.Visible = false
		optionsListFrame.Parent = frame

		local opCorner = Instance.new("UICorner")
		opCorner.CornerRadius = UDim.new(0, 6)
		opCorner.Parent = optionsListFrame

		local opStroke = Instance.new("UIStroke")
		opStroke.Thickness = 1.5
		opStroke.Color = colorBorderDark
		opStroke.Parent = optionsListFrame

		local listLayout = Instance.new("UIListLayout")
		listLayout.Padding = UDim.new(0, 0)
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Parent = optionsListFrame

		local function rebuildDropdownItems(optList)
			for _, child in ipairs(optionsListFrame:GetChildren()) do
				if child:IsA("TextButton") then child:Destroy() end
			end

			for idx, option in ipairs(optList) do
				local optBtn = Instance.new("TextButton")
				optBtn.Size = UDim2.new(1, 0, 0, itemHeight)
				optBtn.BackgroundTransparency = 1
				optBtn.Text = tostring(option)
				optBtn.TextColor3 = colorTextWhite
				optBtn.TextSize = 9
				optBtn.Font = Enum.Font.FredokaOne
				optBtn.LayoutOrder = idx
				
				optBtn.MouseEnter:Connect(function()
					optBtn.BackgroundTransparency = 0
					optBtn.BackgroundColor3 = colorBlueSelect
				end)
				optBtn.MouseLeave:Connect(function()
					optBtn.BackgroundTransparency = 1
				end)

				optBtn.MouseButton1Click:Connect(function()
					btn.Text = tostring(option) .. "  ▼"
					callback(option)
					isOpened = false
					optionsListFrame.Visible = false
					frame:TweenSize(UDim2.new(1, 0, 0, dropdownRowHeight), "Out", "Quad", 0.15, true)
				end)

				optBtn.Parent = optionsListFrame
			end
		end

		rebuildDropdownItems(options)

		btn.MouseButton1Click:Connect(function()
			if label:find("Weapon") or label:find("Element") then
				local updatedList = getAvailableTools()
				rebuildDropdownItems(updatedList)
			end

			isOpened = not isOpened
			if isOpened then
				optionsListFrame.Visible = true
				local totalHeight = listLayout.AbsoluteContentSize.Y + 4
				optionsListFrame.Size = UDim2.new(0.5, 0, 0, totalHeight)
				frame:TweenSize(UDim2.new(1, 0, 0, dropdownRowHeight + totalHeight + 4), "Out", "Quad", 0.15, true)
			else
				optionsListFrame.Visible = false
				frame:TweenSize(UDim2.new(1, 0, 0, dropdownRowHeight), "Out", "Quad", 0.15, true)
			end
		end)

		frame.Parent = parent
		return frame
	end

	local function createSliderRow(parent, label, iconId, initialValue, min, max, callback)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 32)
		frame.BackgroundTransparency = 1

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 4, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = colorBlueSelect
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.35, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		-- Track
		local track = Instance.new("Frame")
		track.Size = UDim2.new(0.32, 0, 0, 6)
		track.Position = UDim2.new(0.42, 0, 0.5, -3)
		track.BackgroundColor3 = colorSlateBackground
		track.BorderSizePixel = 0
		track.Parent = frame

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0, 3)
		trackCorner.Parent = track

		local trackStroke = Instance.new("UIStroke")
		trackStroke.Thickness = 1.5
		trackStroke.Color = colorBorderDark
		trackStroke.Parent = track

		-- Fill
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new((initialValue - min) / (max - min), 0, 1, 0)
		fill.BackgroundColor3 = colorBlueSelect
		fill.BorderSizePixel = 0
		fill.Parent = track

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 3)
		fillCorner.Parent = fill

		-- Thumb
		local thumb = Instance.new("TextButton")
		thumb.Size = UDim2.new(0, 14, 0, 14)
		thumb.Position = UDim2.new((initialValue - min) / (max - min), -7, 0.5, -7)
		thumb.BackgroundColor3 = colorTextWhite
		thumb.Text = ""
		thumb.Parent = track

		local thumbCorner = Instance.new("UICorner")
		thumbCorner.CornerRadius = UDim.new(1, 0)
		thumbCorner.Parent = thumb

		local thumbStroke = Instance.new("UIStroke")
		thumbStroke.Thickness = 1.5
		thumbStroke.Color = colorBorderDark
		thumbStroke.Parent = thumb

		-- TextBox
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0.18, 0, 0, 24)
		box.Position = UDim2.new(0.8, 0, 0.5, -12)
		box.BackgroundColor3 = colorSlateBackground
		box.Text = tostring(initialValue)
		box.TextColor3 = colorTextWhite
		box.TextSize = 10
		box.Font = Enum.Font.FredokaOne
		
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, 6)
		boxCorner.Parent = box

		local boxStroke = Instance.new("UIStroke")
		boxStroke.Thickness = 1.5
		boxStroke.Color = colorBorderDark
		boxStroke.Parent = box
		box.Parent = frame

		-- Drag Logic
		local dragging = false

		local function updateValue(percentage)
			percentage = math.clamp(percentage, 0, 1)
			local rawVal = min + (max - min) * percentage
			local val = math.floor(rawVal * 10 + 0.5) / 10
			fill.Size = UDim2.new(percentage, 0, 1, 0)
			thumb.Position = UDim2.new(percentage, -7, 0.5, -7)
			box.Text = tostring(val)
			callback(val)
		end

		thumb.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local absolutePosition = track.AbsolutePosition
				local absoluteSize = track.AbsoluteSize
				local mouseX = input.Position.X
				local percentage = (mouseX - absolutePosition.X) / absoluteSize.X
				updateValue(percentage)
			end
		end)

		box.FocusLost:Connect(function()
			local val = tonumber(box.Text)
			if val then
				val = math.clamp(val, min, max)
				local percentage = (val - min) / (max - min)
				updateValue(percentage)
			else
				box.Text = tostring(CONFIG.TP_Distance)
			end
		end)

		frame.Parent = parent
		return frame
	end

	local function createInputRow(parent, label, iconId, initialValue, callback)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 32)
		frame.BackgroundTransparency = 1
		
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 4, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = colorBlueSelect
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.42, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		local input = Instance.new("TextBox")
		input.Size = UDim2.new(0.5, 0, 0, 24)
		input.Position = UDim2.new(0.5, 0, 0.5, -12)
		input.BackgroundColor3 = colorSlateBackground
		input.Text = tostring(initialValue)
		input.TextColor3 = colorTextWhite
		input.TextSize = 10
		input.Font = Enum.Font.FredokaOne
		
		local cornerInput = Instance.new("UICorner")
		cornerInput.CornerRadius = UDim.new(0, 6)
		cornerInput.Parent = input

		local strokeInput = Instance.new("UIStroke")
		strokeInput.Thickness = 1.5
		strokeInput.Color = colorBorderDark
		strokeInput.Parent = input
		input.Parent = frame

		input.FocusLost:Connect(function()
			callback(input, input.Text)
		end)

		frame.Parent = parent
		return frame
	end

	-- ============================================================
	-- PANELS / COLUMNS LAYOUT (3 COLUMNS)
	-- ============================================================
	
	-- Helper: Create Box Panel Frame
	local function createPanel(xPos, width, titleTextStr)
		local panel = Instance.new("Frame")
		panel.Size = UDim2.new(0, width, 1, -65)
		panel.Position = UDim2.new(0, xPos, 0, 50)
		panel.BackgroundColor3 = colorSlatePanel
		panel.BorderSizePixel = 0
		panel.Parent = mainFrame

		local panelCorner = Instance.new("UICorner")
		panelCorner.CornerRadius = UDim.new(0, 12)
		panelCorner.Parent = panel

		local panelStroke = Instance.new("UIStroke")
		panelStroke.Thickness = 2
		panelStroke.Color = colorBorderDark
		panelStroke.Parent = panel

		-- Panel Header textless but has a clean title label inside
		local head = Instance.new("TextLabel")
		head.Size = UDim2.new(1, 0, 0, 28)
		head.Position = UDim2.new(0, 0, 0, 4)
		head.BackgroundTransparency = 1
		head.Text = titleTextStr
		head.TextColor3 = colorBlueSelect
		head.TextSize = 13
		head.Font = Enum.Font.FredokaOne
		
		local headStroke = Instance.new("UIStroke")
		headStroke.Thickness = 1.2
		headStroke.Color = Color3.fromRGB(0, 0, 0)
		headStroke.Parent = head
		head.Parent = panel

		-- Content ScrollFrame inside the panel to support scrolling options
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, -12, 1, -38)
		scroll.Position = UDim2.new(0, 6, 0, 32)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 4
		scroll.ScrollBarImageColor3 = colorBlueSelect
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Parent = panel

		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll

		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 10)
		end)

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 2)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 4)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = scroll

		return scroll
	end

	-- Create the 3 Columns
	local colDungeon = createPanel(15, 240, "Dungeon Settings")
	local colCombat = createPanel(270, 240, "Combat & Spells")
	local colMovement = createPanel(525, 240, "Movement & Loots")

	-- ============================================
	-- COLUMN 1: DUNGEON SETTINGS & CONTROLS
	-- ============================================
	local mainToggleBtn = Instance.new("TextButton")
	mainToggleBtn.Size = UDim2.new(1, 0, 0, 42)
	mainToggleBtn.BackgroundColor3 = colorGreenActive
	mainToggleBtn.Text = "START AUTOFARM [F6]"
	mainToggleBtn.TextColor3 = colorTextWhite
	mainToggleBtn.TextSize = 12
	mainToggleBtn.Font = Enum.Font.FredokaOne
	mainToggleBtn.LayoutOrder = 1
	
	local toggleCornerStatus = Instance.new("UICorner")
	toggleCornerStatus.CornerRadius = UDim.new(0, 8)
	toggleCornerStatus.Parent = mainToggleBtn
	
	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Thickness = 2
	toggleStroke.Color = colorBorderDark
	toggleStroke.Parent = mainToggleBtn

	local toggleGrad = Instance.new("UIGradient")
	toggleGrad.Rotation = 90
	toggleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180))
	})
	toggleGrad.Parent = mainToggleBtn
	mainToggleBtn.Parent = colDungeon

	mainToggleBtn.MouseEnter:Connect(function()
		animateColor(mainToggleBtn, "BackgroundColor3", isRunning and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(40, 220, 110))
	end)
	mainToggleBtn.MouseLeave:Connect(function()
		animateColor(mainToggleBtn, "BackgroundColor3", isRunning and colorRedWarning or colorGreenActive)
	end)

	mainToggleBtn.MouseButton1Click:Connect(function()
		if isRunning then
			stopFarm()
			mainToggleBtn.Text = "START AUTOFARM [F6]"
			mainToggleBtn.BackgroundColor3 = colorGreenActive
		else
			startFarm()
			mainToggleBtn.Text = "STOP AUTOFARM [F6]"
			mainToggleBtn.BackgroundColor3 = colorRedWarning
		end
	end)

	-- Stats Card
	local statusStatsFrame = Instance.new("Frame")
	statusStatsFrame.Size = UDim2.new(1, 0, 0, 100)
	statusStatsFrame.BackgroundColor3 = colorSlateBackground
	statusStatsFrame.BorderSizePixel = 0
	statusStatsFrame.LayoutOrder = 2
	
	local statusStatsCorner = Instance.new("UICorner")
	statusStatsCorner.CornerRadius = UDim.new(0, 8)
	statusStatsCorner.Parent = statusStatsFrame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 1.5
	cardStroke.Color = colorBorderDark
	cardStroke.Parent = statusStatsFrame

	local statusStatsLabel = Instance.new("TextLabel")
	statusStatsLabel.Size = UDim2.new(1, -16, 1, -16)
	statusStatsLabel.Position = UDim2.new(0, 8, 0, 8)
	statusStatsLabel.BackgroundTransparency = 1
	statusStatsLabel.Text = "Kills : 0\nRetries : 0\nSession Time : 00:00\nLoots : 0 | Sold : 0"
	statusStatsLabel.TextColor3 = colorTextWhite
	statusStatsLabel.TextSize = 11
	statusStatsLabel.LineHeight = 1.3
	statusStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusStatsLabel.Font = Enum.Font.FredokaOne
	
	local statsStroke = Instance.new("UIStroke")
	statsStroke.Thickness = 1
	statsStroke.Color = Color3.fromRGB(0, 0, 0)
	statsStroke.Parent = statusStatsLabel
	statusStatsLabel.Parent = statusStatsFrame
	statusStatsFrame.Parent = colDungeon

	createSectionHeader(colDungeon, "Lobby Controls").LayoutOrder = 3
	createDropdownRow(colDungeon, "Dungeon Name :", "rbxassetid://6034287517", CONFIG.DungeonName, DUNGEONS_LIST, function(newVal)
		CONFIG.DungeonName = newVal
	end).LayoutOrder = 4

	createDropdownRow(colDungeon, "Difficulty :", "rbxassetid://6034287517", CONFIG.Difficulty, DIFFICULTIES_LIST, function(newVal)
		CONFIG.Difficulty = newVal
	end).LayoutOrder = 5

	createToggleRow(colDungeon, "Auto Join Lobby", "rbxassetid://6034855071", "AutoJoinDungeon").LayoutOrder = 6
	createToggleRow(colDungeon, "Auto Retry Dungeon", "rbxassetid://6031768426", "AutoRetry").LayoutOrder = 7
	createInputRow(colDungeon, "Retry Delay (s) :", "rbxassetid://6031768426", CONFIG.RetryDelay, function(box, text)
		local val = tonumber(text)
		if val and val >= 0 and val <= 15 then CONFIG.RetryDelay = val else box.Text = tostring(CONFIG.RetryDelay) end
	end).LayoutOrder = 8

	-- ============================================
	-- COLUMN 2: COMBAT & SPELLS
	-- ============================================
	createSectionHeader(colCombat, "Logic & Gear Selection").LayoutOrder = 1
	createToggleRow(colCombat, "Auto Attack Mobs", "rbxassetid://6035043132", "AutoAttack").LayoutOrder = 2
	createToggleRow(colCombat, "Auto Cast Spells", "rbxassetid://6034287517", "AutoSkills").LayoutOrder = 3
	createToggleRow(colCombat, "Auto Equip Gear", "rbxassetid://6035043132", "AutoEquip").LayoutOrder = 4

	createDropdownRow(colCombat, "Equip Mode :", "rbxassetid://6031289116", CONFIG.EquipMode, {"Both", "Weapon Only", "Element Only", "None"}, function(newVal)
		CONFIG.EquipMode = newVal
	end).LayoutOrder = 5

	local toolsList = getAvailableTools()
	createDropdownRow(colCombat, "Main Weapon :", "rbxassetid://6035043132", CONFIG.SelectedWeapon, toolsList, function(newVal)
		CONFIG.SelectedWeapon = newVal
	end).LayoutOrder = 6

	createDropdownRow(colCombat, "Magic Element :", "rbxassetid://6034287517", CONFIG.SelectedElement, toolsList, function(newVal)
		CONFIG.SelectedElement = newVal
	end).LayoutOrder = 7

	createSectionHeader(colCombat, "Attack Parameters").LayoutOrder = 8
	createDropdownRow(colCombat, "Attack Mode :", "rbxassetid://6035043132", CONFIG.AttackMode, {"Sword & Skills", "Sword Only", "Skills Only"}, function(newVal)
		CONFIG.AttackMode = newVal
	end).LayoutOrder = 9

	createInputRow(colCombat, "Attack Delay Min (s) :", "rbxassetid://6031768426", CONFIG.SwingDelayMin, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.01 and val <= 2 then CONFIG.SwingDelayMin = val else box.Text = tostring(CONFIG.SwingDelayMin) end
	end).LayoutOrder = 10

	createInputRow(colCombat, "Attack Delay Max (s) :", "rbxassetid://6031768426", CONFIG.SwingDelayMax, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.01 and val <= 2 then CONFIG.SwingDelayMax = val else box.Text = tostring(CONFIG.SwingDelayMax) end
	end).LayoutOrder = 11

	createInputRow(colCombat, "Attack Range (studs) :", "rbxassetid://6034855071", CONFIG.MaxAttackDistance, function(box, text)
		local val = tonumber(text)
		if val and val >= 1 and val <= 50 then CONFIG.MaxAttackDistance = val else box.Text = tostring(CONFIG.MaxAttackDistance) end
	end).LayoutOrder = 12

	createSectionHeader(colCombat, "Active Spell Slots").LayoutOrder = 13
	
	local function createSkillsRow(parent, layoutOrder)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 36)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 4, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = "rbxassetid://6034287517"
		icon.ImageColor3 = colorBlueSelect
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.32, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Slots :"
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 10
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		for slot = 1, 4 do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 34, 0, 22)
			btn.Position = UDim2.new(0.42 + (slot - 1) * 0.14, 0, 0.5, -11)
			
			local isActivated = table.find(CONFIG.SelectedSkills, slot) ~= nil
			btn.BackgroundColor3 = isActivated and colorBlueSelect or colorSlateBackground
			btn.Text = "S" .. slot
			btn.TextColor3 = colorTextWhite
			btn.TextSize = 9
			btn.Font = Enum.Font.FredokaOne
			
			local cornerS = Instance.new("UICorner")
			cornerS.CornerRadius = UDim.new(0, 5)
			cornerS.Parent = btn

			local strokeS = Instance.new("UIStroke")
			strokeS.Thickness = 1.5
			strokeS.Color = colorBorderDark
			strokeS.Parent = btn

			btn.MouseButton1Click:Connect(function()
				local idx = table.find(CONFIG.SelectedSkills, slot)
				if idx then
					table.remove(CONFIG.SelectedSkills, idx)
					animateColor(btn, "BackgroundColor3", colorSlateBackground)
				else
					table.insert(CONFIG.SelectedSkills, slot)
					table.sort(CONFIG.SelectedSkills)
					animateColor(btn, "BackgroundColor3", colorBlueSelect)
				end
			end)
			btn.Parent = frame
		end

		frame.Parent = parent
		return frame
	end
	createSkillsRow(colCombat, 14)

	createInputRow(colCombat, "Skill Cast Delay (s) :", "rbxassetid://6031768426", CONFIG.SkillDelay, function(box, text)
		local val = tonumber(text)
		if val and val >= 0 and val <= 10 then CONFIG.SkillDelay = val else box.Text = tostring(CONFIG.SkillDelay) end
	end).LayoutOrder = 15

	-- ============================================
	-- COLUMN 3: MOVEMENT & LOOTS
	-- ============================================
	createSectionHeader(colMovement, "Relative TP Position").LayoutOrder = 1
	createDropdownRow(colMovement, "TP Position :", "rbxassetid://6034855071", CONFIG.TP_Position, {"Top", "Bottom", "Behind", "Front", "Left", "Right"}, function(newVal)
		CONFIG.TP_Position = newVal
	end).LayoutOrder = 2

	createSliderRow(colMovement, "TP Distance :", "rbxassetid://6034855071", CONFIG.TP_Distance, 0, 25, function(newVal)
		CONFIG.TP_Distance = newVal
	end).LayoutOrder = 3

	createInputRow(colMovement, "Manual Offset (X,Y,Z) :", "rbxassetid://6034855071", CONFIG.TP_Offset_X .. "," .. CONFIG.TP_Offset_Y .. "," .. CONFIG.TP_Offset_Z, function(box, text)
		local parts = {}
		for part in text:gmatch("[^,]+") do table.insert(parts, tonumber(part)) end
		if #parts == 3 then
			CONFIG.TP_Offset_X = parts[1] or 0
			CONFIG.TP_Offset_Y = parts[2] or 0
			CONFIG.TP_Offset_Z = parts[3] or 0
		else
			box.Text = CONFIG.TP_Offset_X .. "," .. CONFIG.TP_Offset_Y .. "," .. CONFIG.TP_Offset_Z
		end
	end).LayoutOrder = 4

	createInputRow(colMovement, "Tween Speed (s/s) :", "rbxassetid://6031768426", CONFIG.TweenSpeed, function(box, text)
		local val = tonumber(text)
		if val and val >= 10 and val <= 250 then CONFIG.TweenSpeed = val else box.Text = tostring(CONFIG.TweenSpeed) end
	end).LayoutOrder = 5

	createToggleRow(colMovement, "Randomize Movement", "rbxassetid://6031768426", "RandomizeOffset").LayoutOrder = 6
	createToggleRow(colMovement, "Permanent Noclip", "rbxassetid://6034855071", "NoclipPermanent").LayoutOrder = 7

	createSectionHeader(colMovement, "Physical Adjustments").LayoutOrder = 8
	createInputRow(colMovement, "Walk Speed :", "rbxassetid://6031768426", CONFIG.WalkSpeed, function(box, text)
		local val = tonumber(text)
		if val and val >= 16 and val <= 150 then CONFIG.WalkSpeed = val else box.Text = tostring(CONFIG.WalkSpeed) end
	end).LayoutOrder = 9

	createInputRow(colMovement, "Jump Power :", "rbxassetid://6031768426", CONFIG.JumpPower, function(box, text)
		local val = tonumber(text)
		if val and val >= 50 and val <= 250 then CONFIG.JumpPower = val else box.Text = tostring(CONFIG.JumpPower) end
	end).LayoutOrder = 10

	createSectionHeader(colMovement, "Drops & Auto Sell").LayoutOrder = 11
	createToggleRow(colMovement, "Auto Collect Drops", "rbxassetid://6034287523", "AutoCollect").LayoutOrder = 12
	createToggleRow(colMovement, "Auto Sell Inventory", "rbxassetid://6034287514", "AutoSell").LayoutOrder = 13
	createToggleRow(colMovement, "Sell Common items", "rbxassetid://6034287514", "SellCommon").LayoutOrder = 14
	createToggleRow(colMovement, "Sell Uncommon items", "rbxassetid://6034287514", "SellUncommon").LayoutOrder = 15
	createToggleRow(colMovement, "Sell Rare items", "rbxassetid://6034287514", "SellRare").LayoutOrder = 16

	createSectionHeader(colMovement, "Optimization").LayoutOrder = 17
	createToggleRow(colMovement, "Night Mode (No 3D)", "rbxassetid://6031289116", "Disable3DRendering", function(state)
		pcall(function()
			RunService:Set3dRenderingEnabled(not state)
		end)
	end).LayoutOrder = 18

	-- ============================================
	-- ASYNCHRONOUS DATA REFRESH
	-- ============================================
	task.spawn(function()
		while screenGui.Parent do
			local elapsed = os.time() - STATS.StartTime
			local minutes = math.floor(elapsed / 60)
			local seconds = elapsed % 60
			local timeStr = string.format("%02d:%02d", minutes, seconds)

			local fullStatsText = "Kills : "
				.. STATS.Kills
				.. "\nRetries : "
				.. STATS.Dungeons
				.. "\nSession Time : "
				.. timeStr
				.. "\nLoots : "
				.. STATS.LootCollected
				.. " | Sold : "
				.. STATS.ItemsSold

			statusStatsLabel.Text = fullStatsText
			task.wait(1)
		end
	end)

	-- F6 Shortcut Trigger
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.F6 then
			if isRunning then
				stopFarm()
				mainToggleBtn.Text = "START AUTOFARM [F6]"
				mainToggleBtn.BackgroundColor3 = colorGreenActive
			else
				startFarm()
				mainToggleBtn.Text = "STOP AUTOFARM [F6]"
				mainToggleBtn.BackgroundColor3 = colorRedWarning
			end
		end
	end)

	print("GUI ULTIME V15 CHARGEE !")
end

-- ============================================================
-- 12. RUN LAUNCHER
-- ============================================================

task.wait(0.5)
createUltimateGUI()
