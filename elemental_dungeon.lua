-- ======================================================
-- AUTOFARM ULTIME – VERSION GUI V13 (CLAYMORPHISM PRO)
-- Onglets, Icônes Vectorielles, Slider, Dropdowns Dépliants, Anti-Chute
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
	print("Services non trouves !")
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
	print("Remotes critiques non trouves !")
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
local DIFFICULTIES_LIST = { "Easy", "Normal", "Hard", "Hell" }

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
	Difficulty = DIFFICULTIES_LIST[1] or "Easy",
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
local activeTarget = nil -- Cible de combat active pour verrouiller la position

-- Noclip permanent / temporaire & Ancrage de position (Anti-chute gravitationnelle)
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

	-- Forcer la position à l'offset configuré par rapport au monstre pour empêcher la chute
	if CONFIG.AutoFarm and activeTarget and activeTarget.Parent and hrp and not isTweening then
		local mobPart = activeTarget:FindFirstChild("HumanoidRootPart") or activeTarget:FindFirstChild("PrimaryPart")
		if mobPart then
			local targetPos = getPositionOffset(mobPart)
			hrp.CFrame = CFrame.new(targetPos)
		end
	end
end)

-- Physique modifiée
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
	if currentTarget and currentTarget.Parent and currentTarget:FindFirstChild("Humanoid") and currentTarget.Humanoid.Health > 0 then
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local targetPart = currentTarget:FindFirstChild("HumanoidRootPart") or currentTarget:FindFirstChild("PrimaryPart")
		if hrp and targetPart then
			local dist = (hrp.Position - targetPart.Position).Magnitude
			if dist < 80 then
				return currentTarget
			end
		end
	end

	local mobs = getAliveMobs()
	if #mobs == 0 then
		currentTarget = nil
		activeTarget = nil
		return nil
	end

	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		currentTarget = mobs[1]
		activeTarget = currentTarget
		return currentTarget
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
	
	-- Incrémentation de kills fiable
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

function heal()
	if UseHeal then
		pcall(function()
			UseHeal:InvokeServer()
		end)
	end
end

function createDungeon(name, difficulty)
	pcall(function()
		StartDungeon:InvokeServer(name, difficulty)
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

-- Équipement automatique précis
function autoEquipSpecific(toolName)
	if not CONFIG.AutoEquip then return end
	if not toolName or toolName == "Aucun" or toolName == "" then return end
	
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Si déjà équipé
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

-- 10. BOUCLE PRINCIPALE
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

			-- Auto-heal
			if CONFIG.AutoHeal then
				local character = LocalPlayer.Character
				local humanoid = character and character:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health / humanoid.MaxHealth < CONFIG.HealThreshold then
					heal()
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
						-- 1. Équiper arme principale pour taper
						if mode == "Weapon Only" or mode == "Both" then
							autoEquipSpecific(CONFIG.SelectedWeapon)
							if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
								swing()
							end
						end

						-- 2. Équiper l'élément pour lancer les sorts
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

			-- Tâches secondaires asynchrones
			if CONFIG.AutoCollect and loopCounter % 15 == 0 then
				task.spawn(autoCollect)
			end

			if CONFIG.AutoSell and loopCounter % 50 == 0 then
				task.spawn(autoSell)
			end

			-- Retry & Auto-Join Dungeon
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
-- 11. CRÉATION DE L'INTERFACE EN EMERALD CLAYMORPHISM PRO (NO EMOJIS)
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

	-- Tailles par défaut
	local defaultWidth = 440
	local defaultHeight = 580
	local minimizedHeight = 45
	local maximizedHeight = 720
	local isWindowMaximized = false
	local isWindowMinimized = false

	-- Palette de couleurs orientée Vert (Émeraude & Menthe) + Rose Corail (complémentaire)
	local colorEmeraldBackground = Color3.fromRGB(12, 28, 22) -- Fond émeraude sombre
	local colorEmeraldTitle = Color3.fromRGB(18, 42, 32)      -- Titre émeraude moyen
	local colorEmeraldBorder = Color3.fromRGB(30, 60, 48)     -- Bordure relief 3D
	local colorMintActive = Color3.fromRGB(0, 220, 120)       -- Vert menthe (néon)
	local colorCoralWarning = Color3.fromRGB(240, 75, 110)    -- Rose Corail (complémentaire)
	local colorTextLight = Color3.fromRGB(230, 245, 235)      -- Texte clair doux

	-- Frame principal (Emerald Claymorphism PRO)
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, defaultWidth, 0, defaultHeight)
	mainFrame.Position = UDim2.new(0.5, -defaultWidth/2, 0.5, -defaultHeight/2)
	mainFrame.BackgroundColor3 = colorEmeraldBackground
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = true
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui

	-- Bordure claymorphic émeraude douce
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = colorEmeraldBorder
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = mainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 24) -- Coins plus prononcés
	corner.Parent = mainFrame

	-- Barre de titre
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 45)
	titleBar.BackgroundColor3 = colorEmeraldTitle
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 24)
	titleCorner.Parent = titleBar

	local titleHideBottom = Instance.new("Frame")
	titleHideBottom.Size = UDim2.new(1, 0, 0, 10)
	titleHideBottom.Position = UDim2.new(0, 0, 1, -10)
	titleHideBottom.BackgroundColor3 = colorEmeraldTitle
	titleHideBottom.BorderSizePixel = 0
	titleHideBottom.Parent = titleBar

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(0.65, 0, 1, 0)
	titleText.Position = UDim2.new(0, 16, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "ELEMENTAL FARMER V13 PRO"
	titleText.TextColor3 = colorTextLight
	titleText.TextSize = 13
	titleText.Font = Enum.Font.GothamBold
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.Parent = titleBar

	-- Conteneur des boutons Windows
	local winControls = Instance.new("Frame")
	winControls.Size = UDim2.new(0, 120, 1, 0)
	winControls.Position = UDim2.new(1, -120, 0, 0)
	winControls.BackgroundTransparency = 1
	winControls.Parent = titleBar

	local navList = Instance.new("UIListLayout")
	navList.FillDirection = Enum.FillDirection.Horizontal
	navList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	navList.SortOrder = Enum.SortOrder.LayoutOrder
	navList.Parent = winControls

	local tabBar = Instance.new("Frame")
	local pageContainer = Instance.new("Frame")

	local function createWinBtn(text, order, hoverColor, clickCallback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 36, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(150, 180, 160)
		btn.TextSize = 13
		btn.Font = Enum.Font.GothamBold
		btn.LayoutOrder = order
		btn.Parent = winControls

		btn.MouseEnter:Connect(function()
			btn.BackgroundTransparency = 0
			btn.BackgroundColor3 = hoverColor
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundTransparency = 1
			btn.TextColor3 = Color3.fromRGB(150, 180, 160)
		end)
		btn.MouseButton1Click:Connect(clickCallback)
	end

	-- Boutons Windows (Minimize, Maximize, Close Corail)
	createWinBtn("—", 1, colorEmeraldBorder, function()
		isWindowMinimized = not isWindowMinimized
		if isWindowMinimized then
			tabBar.Visible = false
			pageContainer.Visible = false
			mainFrame:TweenSize(UDim2.new(0, defaultWidth, 0, minimizedHeight), "Out", "Quad", 0.25, true)
		else
			mainFrame:TweenSize(UDim2.new(0, defaultWidth, 0, isWindowMaximized and maximizedHeight or defaultHeight), "Out", "Quad", 0.25, true, function()
				tabBar.Visible = true
				pageContainer.Visible = true
			end)
		end
	end)

	createWinBtn("▢", 2, colorEmeraldBorder, function()
		if isWindowMinimized then return end
		isWindowMaximized = not isWindowMaximized
		local targetH = isWindowMaximized and maximizedHeight or defaultHeight
		mainFrame:TweenSize(UDim2.new(0, defaultWidth, 0, targetH), "Out", "Quad", 0.25, true)
	end)

	createWinBtn("✕", 3, colorCoralWarning, function()
		stopFarm()
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
		screenGui:Destroy()
	end)

	-- Bar d'onglets
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.Position = UDim2.new(0, 0, 0, 45)
	tabBar.BackgroundColor3 = Color3.fromRGB(10, 22, 17)
	tabBar.BorderSizePixel = 0
	tabBar.Parent = mainFrame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	-- Conteneur de pages
	pageContainer.Size = UDim2.new(1, -16, 1, -95)
	pageContainer.Position = UDim2.new(0, 8, 0, 87)
	pageContainer.BackgroundTransparency = 1
	pageContainer.Parent = mainFrame

	local pages = {}
	local tabButtons = {}

	-- Helper de création de ScrollingFrame
	local function createTabPage(name, layoutOrder)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 6
		scroll.ScrollBarImageColor3 = colorMintActive
		scroll.Visible = false
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Parent = pageContainer

		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll

		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
		end)

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 14)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = scroll

		pages[name] = scroll
		return scroll
	end

	-- Initialisation des pages
	local pageStatus = createTabPage("Status", 1)
	local pageCombat = createTabPage("Combat", 2)
	local pageTP = createTabPage("TP", 3)
	local pageDungeon = createTabPage("Dungeon", 4)
	local pageSystem = createTabPage("System", 5)

	-- Navigation switch
	local function selectTab(tabName)
		for name, page in pairs(pages) do
			page.Visible = (name == tabName)
		end
		for name, btn in pairs(tabButtons) do
			if name == tabName then
				btn.BackgroundColor3 = colorEmeraldBackground
				btn.IconLabel.ImageColor3 = colorMintActive
				btn.TextLabel.TextColor3 = colorMintActive
				btn.TextLabel.Font = Enum.Font.GothamBold
			else
				btn.BackgroundColor3 = Color3.fromRGB(10, 22, 17)
				btn.IconLabel.ImageColor3 = Color3.fromRGB(130, 160, 140)
				btn.TextLabel.TextColor3 = Color3.fromRGB(130, 160, 140)
				btn.TextLabel.Font = Enum.Font.Gotham
			end
		end
	end

	-- Boutons d'onglets (avec ImageLabel - NO EMOJIS)
	local function createTabButton(name, iconId, text, layoutOrder)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.2, 0, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(10, 22, 17)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.LayoutOrder = layoutOrder
		btn.Parent = tabBar

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0.12, 0, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = Color3.fromRGB(130, 160, 140)
		icon.Name = "IconLabel"
		icon.Parent = btn

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.7, 0, 1, 0)
		lbl.Position = UDim2.new(0.3, 0, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = Color3.fromRGB(130, 160, 140)
		lbl.TextSize = 10
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Name = "TextLabel"
		lbl.Parent = btn

		btn.MouseButton1Click:Connect(function()
			selectTab(name)
		end)

		tabButtons[name] = btn
	end

	createTabButton("Status", "rbxassetid://6031768426", "Stats", 1)
	createTabButton("Combat", "rbxassetid://6035043132", "Combat", 2)
	createTabButton("TP", "rbxassetid://6034855071", "Parcours", 3)
	createTabButton("Dungeon", "rbxassetid://6034287517", "Donjon", 4)
	createTabButton("System", "rbxassetid://6031289116", "Systeme", 5)

	-- ============================================
	-- CONTRÔLES STYLISÉS CLAYMORPHISM (PRO - NO EMOJIS)
	-- ============================================
	local function createToggleRow(parent, label, iconId, configKey, layoutOrder)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 34)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 22, 0, 22)
		btn.Position = UDim2.new(0, 4, 0.5, -11)
		btn.BackgroundColor3 = CONFIG[configKey] and colorMintActive or Color3.fromRGB(18, 38, 30)
		btn.Text = CONFIG[configKey] and "✓" or ""
		btn.TextColor3 = Color3.fromRGB(12, 28, 22)
		btn.TextSize = 12
		btn.Font = Enum.Font.GothamBold
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
		
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 2
		btnStroke.Color = CONFIG[configKey] and Color3.fromRGB(180, 255, 220) or colorEmeraldBorder
		btnStroke.Parent = btn
		btn.Parent = frame

		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
		})
		gradient.Parent = btn

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 36, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = CONFIG[configKey] and colorMintActive or Color3.fromRGB(150, 180, 160)
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -56, 1, 0)
		lbl.Position = UDim2.new(0, 56, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextLight
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = frame

		btn.MouseButton1Click:Connect(function()
			CONFIG[configKey] = not CONFIG[configKey]
			animateColor(btn, "BackgroundColor3", CONFIG[configKey] and colorMintActive or Color3.fromRGB(18, 38, 30))
			btnStroke.Color = CONFIG[configKey] and Color3.fromRGB(180, 255, 220) or colorEmeraldBorder
			icon.ImageColor3 = CONFIG[configKey] and colorMintActive or Color3.fromRGB(150, 180, 160)
			btn.Text = CONFIG[configKey] and "✓" or ""
		end)

		frame.Parent = parent
		return frame
	end

	-- DROPDOWN DEPLIANT INTERACTIF
	local function createDropdownRow(parent, label, iconId, initialValue, options, layoutOrder, callback)
		local isOpened = false
		local itemHeight = 26
		local dropdownRowHeight = 34

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, dropdownRowHeight)
		frame.BackgroundTransparency = 1
		frame.ClipsDescendants = true
		frame.LayoutOrder = layoutOrder

		local topRow = Instance.new("Frame")
		topRow.Size = UDim2.new(1, 0, 0, dropdownRowHeight)
		topRow.BackgroundTransparency = 1
		topRow.Parent = frame

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 4, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = colorMintActive
		icon.Parent = topRow

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.42, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(200, 220, 210)
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = topRow

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.5, 0, 0, 26)
		btn.Position = UDim2.new(0.5, 0, 0.5, -13)
		btn.BackgroundColor3 = Color3.fromRGB(18, 38, 30)
		btn.Text = tostring(initialValue) .. "  ▼"
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextSize = 11
		btn.Font = Enum.Font.GothamSemibold
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn
		
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 2
		btnStroke.Color = colorEmeraldBorder
		btnStroke.Parent = btn

		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190))
		})
		gradient.Parent = btn
		btn.Parent = topRow

		local optionsListFrame = Instance.new("Frame")
		optionsListFrame.Size = UDim2.new(0.5, 0, 0, 0)
		optionsListFrame.Position = UDim2.new(0.5, 0, 0, dropdownRowHeight)
		optionsListFrame.BackgroundColor3 = Color3.fromRGB(15, 34, 26)
		optionsListFrame.BorderSizePixel = 0
		optionsListFrame.Visible = false
		optionsListFrame.Parent = frame

		local opCorner = Instance.new("UICorner")
		opCorner.CornerRadius = UDim.new(0, 8)
		opCorner.Parent = optionsListFrame

		local opStroke = Instance.new("UIStroke")
		opStroke.Thickness = 1
		opStroke.Color = colorEmeraldBorder
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
				optBtn.TextColor3 = Color3.fromRGB(200, 220, 205)
				optBtn.TextSize = 10
				optBtn.Font = Enum.Font.Gotham
				optBtn.LayoutOrder = idx
				
				optBtn.MouseEnter:Connect(function()
					optBtn.BackgroundTransparency = 0
					optBtn.BackgroundColor3 = colorMintActive
					optBtn.TextColor3 = Color3.fromRGB(12, 28, 22)
				end)
				optBtn.MouseLeave:Connect(function()
					optBtn.BackgroundTransparency = 1
					optBtn.TextColor3 = Color3.fromRGB(200, 220, 205)
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
			if label:find("Arme") or label:find("Element") then
				local updatedList = getAvailableTools()
				rebuildDropdownItems(updatedList)
			end

			isOpened = not isOpened
			if isOpened then
				optionsListFrame.Visible = true
				local totalHeight = listLayout.AbsoluteContentSize.Y + 8
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

	-- SLIDER AVEC TEXTBOX INTEGRÉE POUR LA DISTANCE
	local function createSliderRow(parent, label, iconId, initialValue, min, max, layoutOrder, callback)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 36)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 4, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = colorMintActive
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.35, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(200, 220, 210)
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = frame

		-- Track
		local track = Instance.new("Frame")
		track.Size = UDim2.new(0.32, 0, 0, 6)
		track.Position = UDim2.new(0.42, 0, 0.5, -3)
		track.BackgroundColor3 = Color3.fromRGB(20, 40, 32)
		track.BorderSizePixel = 0
		track.Parent = frame

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0, 3)
		trackCorner.Parent = track

		-- Fill
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new((initialValue - min) / (max - min), 0, 1, 0)
		fill.BackgroundColor3 = colorMintActive
		fill.BorderSizePixel = 0
		fill.Parent = track

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 3)
		fillCorner.Parent = fill

		-- Thumb
		local thumb = Instance.new("TextButton")
		thumb.Size = UDim2.new(0, 14, 0, 14)
		thumb.Position = UDim2.new((initialValue - min) / (max - min), -7, 0.5, -7)
		thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		thumb.Text = ""
		thumb.Parent = track

		local thumbCorner = Instance.new("UICorner")
		thumbCorner.CornerRadius = UDim.new(1, 0)
		thumbCorner.Parent = thumb

		local thumbStroke = Instance.new("UIStroke")
		thumbStroke.Thickness = 2
		thumbStroke.Color = colorMintActive
		thumbStroke.Parent = thumb

		-- TextBox
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0.18, 0, 0, 26)
		box.Position = UDim2.new(0.8, 0, 0.5, -13)
		box.BackgroundColor3 = Color3.fromRGB(15, 34, 26)
		box.Text = tostring(initialValue)
		box.TextColor3 = Color3.fromRGB(255, 255, 255)
		box.TextSize = 11
		box.Font = Enum.Font.Gotham
		
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, 6)
		boxCorner.Parent = box

		local boxStroke = Instance.new("UIStroke")
		boxStroke.Thickness = 2
		boxStroke.Color = colorEmeraldBorder
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

	local function createInputRow(parent, label, iconId, initialValue, layoutOrder, callback)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 34)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder
		
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 4, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = colorMintActive
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.42, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = frame

		local input = Instance.new("TextBox")
		input.Size = UDim2.new(0.5, 0, 0, 26)
		input.Position = UDim2.new(0.5, 0, 0.5, -13)
		input.BackgroundColor3 = Color3.fromRGB(15, 34, 26)
		input.Text = tostring(initialValue)
		input.TextColor3 = Color3.fromRGB(255, 255, 255)
		input.TextSize = 11
		input.Font = Enum.Font.Gotham
		
		local cornerInput = Instance.new("UICorner")
		cornerInput.CornerRadius = UDim.new(0, 8)
		cornerInput.Parent = input

		local strokeInput = Instance.new("UIStroke")
		strokeInput.Thickness = 2
		strokeInput.Color = colorEmeraldBorder
		strokeInput.Parent = input
		input.Parent = frame

		input.FocusLost:Connect(function()
			callback(input, input.Text)
		end)

		frame.Parent = parent
		return frame
	end

	local function createSectionHeader(parent, text, layoutOrder)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 28)
		lbl.BackgroundTransparency = 1
		lbl.Text = "──  " .. text .. "  ──"
		lbl.TextColor3 = colorMintActive
		lbl.TextSize = 10
		lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.LayoutOrder = layoutOrder
		lbl.Parent = parent
	end

	-- ============================================
	-- ONGLET 1 : STATUS (STATS & MODULES RAPIDES)
	-- ============================================
	local mainToggleBtn = Instance.new("TextButton")
	mainToggleBtn.Size = UDim2.new(1, 0, 0, 45)
	mainToggleBtn.BackgroundColor3 = colorMintActive
	mainToggleBtn.Text = "DÉMARRER L'AUTOFARM [F6]"
	mainToggleBtn.TextColor3 = Color3.fromRGB(12, 28, 22)
	mainToggleBtn.TextSize = 13
	mainToggleBtn.Font = Enum.Font.GothamBold
	mainToggleBtn.LayoutOrder = 1
	
	local toggleCornerStatus = Instance.new("UICorner")
	toggleCornerStatus.CornerRadius = UDim.new(0, 10)
	toggleCornerStatus.Parent = mainToggleBtn
	
	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Thickness = 2
	toggleStroke.Color = Color3.fromRGB(180, 255, 220)
	toggleStroke.Parent = mainToggleBtn

	local toggleGrad = Instance.new("UIGradient")
	toggleGrad.Rotation = 90
	toggleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180))
	})
	toggleGrad.Parent = mainToggleBtn
	mainToggleBtn.Parent = pageStatus

	mainToggleBtn.MouseEnter:Connect(function()
		animateColor(mainToggleBtn, "BackgroundColor3", isRunning and colorCoralWarning or Color3.fromRGB(0, 255, 136))
	end)
	mainToggleBtn.MouseLeave:Connect(function()
		animateColor(mainToggleBtn, "BackgroundColor3", isRunning and colorCoralWarning or colorMintActive)
	end)

	mainToggleBtn.MouseButton1Click:Connect(function()
		if isRunning then
			stopFarm()
			mainToggleBtn.Text = "DÉMARRER L'AUTOFARM [F6]"
			mainToggleBtn.BackgroundColor3 = colorMintActive
			toggleStroke.Color = Color3.fromRGB(180, 255, 220)
		else
			startFarm()
			mainToggleBtn.Text = "ARRÊTER L'AUTOFARM [F6]"
			mainToggleBtn.BackgroundColor3 = colorCoralWarning
			toggleStroke.Color = Color3.fromRGB(255, 180, 190)
		end
	end)

	-- Stats Card
	local statusStatsFrame = Instance.new("Frame")
	statusStatsFrame.Size = UDim2.new(1, 0, 0, 110)
	statusStatsFrame.BackgroundColor3 = Color3.fromRGB(18, 38, 30)
	statusStatsFrame.BorderSizePixel = 0
	statusStatsFrame.LayoutOrder = 2
	
	local statusStatsCorner = Instance.new("UICorner")
	statusStatsCorner.CornerRadius = UDim.new(0, 10)
	statusStatsCorner.Parent = statusStatsFrame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 2
	cardStroke.Color = colorEmeraldBorder
	cardStroke.Parent = statusStatsFrame

	local statusStatsLabel = Instance.new("TextLabel")
	statusStatsLabel.Size = UDim2.new(1, -20, 1, -20)
	statusStatsLabel.Position = UDim2.new(0, 10, 0, 10)
	statusStatsLabel.BackgroundTransparency = 1
	statusStatsLabel.Text = "Kills : 0\nDonjons relances : 0\nTemps de session : 00:00\nButins : 0 | Ventes : 0"
	statusStatsLabel.TextColor3 = colorTextLight
	statusStatsLabel.TextSize = 12
	statusStatsLabel.LineHeight = 1.35
	statusStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusStatsLabel.Font = Enum.Font.Gotham
	statusStatsLabel.Parent = statusStatsFrame
	statusStatsFrame.Parent = pageStatus

	createSectionHeader(pageStatus, "AUTOMATISATIONS RAPIDES", 3)
	createToggleRow(pageStatus, "Auto Attaquer les Monstres", "rbxassetid://6035043132", "AutoAttack", 4)
	createToggleRow(pageStatus, "Auto Collecter le Butin", "rbxassetid://6034287523", "AutoCollect", 5)
	createToggleRow(pageStatus, "Auto Soin", "rbxassetid://6034287517", "AutoHeal", 6)
	createToggleRow(pageStatus, "Auto Vendre l'Inventaire", "rbxassetid://6034287514", "AutoSell", 7)
	createToggleRow(pageStatus, "Auto Relancer le Donjon", "rbxassetid://6031768426", "AutoRetry", 8)
	createToggleRow(pageStatus, "Auto Rejoindre en Donjon", "rbxassetid://6034855071", "AutoJoinDungeon", 9)

	-- ============================================
	-- ONGLET 2 : COMBAT
	-- ============================================
	createSectionHeader(pageCombat, "LOGIQUE D'EQUIPEMENT", 1)
	createDropdownRow(pageCombat, "Mode d'Equipement :", "rbxassetid://6031289116", CONFIG.EquipMode, {"Both", "Weapon Only", "Element Only", "None"}, 2, function(newVal)
		CONFIG.EquipMode = newVal
	end)

	local toolsList = getAvailableTools()
	createDropdownRow(pageCombat, "Arme Principale :", "rbxassetid://6035043132", CONFIG.SelectedWeapon, toolsList, 3, function(newVal)
		CONFIG.SelectedWeapon = newVal
	end)

	createDropdownRow(pageCombat, "Outil Element :", "rbxassetid://6034287517", CONFIG.SelectedElement, toolsList, 4, function(newVal)
		CONFIG.SelectedElement = newVal
	end)

	createSectionHeader(pageCombat, "PARAMETRES D'ATTAQUE", 5)
	createDropdownRow(pageCombat, "Mode de Combat :", "rbxassetid://6035043132", CONFIG.AttackMode, {"Sword & Skills", "Sword Only", "Skills Only"}, 6, function(newVal)
		CONFIG.AttackMode = newVal
	end)

	createInputRow(pageCombat, "Delai Attaque Min (s) :", "rbxassetid://6031768426", CONFIG.SwingDelayMin, 7, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.01 and val <= 2 then CONFIG.SwingDelayMin = val else box.Text = tostring(CONFIG.SwingDelayMin) end
	end)

	createInputRow(pageCombat, "Delai Attaque Max (s) :", "rbxassetid://6031768426", CONFIG.SwingDelayMax, 8, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.01 and val <= 2 then CONFIG.SwingDelayMax = val else box.Text = tostring(CONFIG.SwingDelayMax) end
	end)

	createInputRow(pageCombat, "Distance d'Attaque (studs) :", "rbxassetid://6034855071", CONFIG.MaxAttackDistance, 9, function(box, text)
		local val = tonumber(text)
		if val and val >= 1 and val <= 50 then CONFIG.MaxAttackDistance = val else box.Text = tostring(CONFIG.MaxAttackDistance) end
	end)

	createSectionHeader(pageCombat, "SORTS & MAGIES ACTIVES", 10)
	
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
		icon.ImageColor3 = colorMintActive
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.32, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Slots Actifs :"
		lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = frame

		for slot = 1, 4 do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 42, 0, 26)
			btn.Position = UDim2.new(0.4 + (slot - 1) * 0.15, 0, 0.5, -13)
			
			local isActivated = table.find(CONFIG.SelectedSkills, slot) ~= nil
			btn.BackgroundColor3 = isActivated and colorMintActive or Color3.fromRGB(18, 38, 30)
			btn.Text = "Slot " .. slot
			btn.TextColor3 = isActivated and Color3.fromRGB(12, 28, 22) or Color3.fromRGB(255, 255, 255)
			btn.TextSize = 10
			btn.Font = Enum.Font.GothamBold
			
			local cornerS = Instance.new("UICorner")
			cornerS.CornerRadius = UDim.new(0, 6)
			cornerS.Parent = btn

			local strokeS = Instance.new("UIStroke")
			strokeS.Thickness = 2
			strokeS.Color = isActivated and Color3.fromRGB(180, 255, 220) or colorEmeraldBorder
			strokeS.Parent = btn

			local gradS = Instance.new("UIGradient")
			gradS.Rotation = 90
			gradS.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180))
			})
			gradS.Parent = btn

			btn.MouseButton1Click:Connect(function()
				local idx = table.find(CONFIG.SelectedSkills, slot)
				if idx then
					table.remove(CONFIG.SelectedSkills, idx)
					animateColor(btn, "BackgroundColor3", Color3.fromRGB(18, 38, 30))
					btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					strokeS.Color = colorEmeraldBorder
				else
					table.insert(CONFIG.SelectedSkills, slot)
					table.sort(CONFIG.SelectedSkills)
					animateColor(btn, "BackgroundColor3", colorMintActive)
					btn.TextColor3 = Color3.fromRGB(12, 28, 22)
					strokeS.Color = Color3.fromRGB(180, 255, 220)
				end
			end)
			btn.Parent = frame
		end

		frame.Parent = parent
		return frame
	end
	createSkillsRow(pageCombat, 11)

	createInputRow(pageCombat, "Delai entre sorts (s) :", "rbxassetid://6031768426", CONFIG.SkillDelay, 12, function(box, text)
		local val = tonumber(text)
		if val and val >= 0 and val <= 10 then CONFIG.SkillDelay = val else box.Text = tostring(CONFIG.SkillDelay) end
	end)

	-- ============================================
	-- ONGLET 3 : PARCOURS & TELEPORTATION
	-- ============================================
	createSectionHeader(pageTP, "REGLAGES DES MOUVEMENTS", 1)
	createDropdownRow(pageTP, "Position relative :", "rbxassetid://6034855071", CONFIG.TP_Position, {"Top", "Bottom", "Behind", "Front", "Left", "Right"}, 2, function(newVal)
		CONFIG.TP_Position = newVal
	end)

	-- SLIDER + TEXTBOX POUR LA DISTANCE RELATIVE
	createSliderRow(pageTP, "Distance relative :", "rbxassetid://6034855071", CONFIG.TP_Distance, 0, 25, 3, function(newVal)
		CONFIG.TP_Distance = newVal
	end)

	createInputRow(pageTP, "Offset Manuel (X,Y,Z) :", "rbxassetid://6034855071", CONFIG.TP_Offset_X .. "," .. CONFIG.TP_Offset_Y .. "," .. CONFIG.TP_Offset_Z, 4, function(box, text)
		local parts = {}
		for part in text:gmatch("[^,]+") do table.insert(parts, tonumber(part)) end
		if #parts == 3 then
			CONFIG.TP_Offset_X = parts[1] or 0
			CONFIG.TP_Offset_Y = parts[2] or 0
			CONFIG.TP_Offset_Z = parts[3] or 0
		else
			box.Text = CONFIG.TP_Offset_X .. "," .. CONFIG.TP_Offset_Y .. "," .. CONFIG.TP_Offset_Z
		end
	end)

	createInputRow(pageTP, "Vitesse de Tween (studs/s) :", "rbxassetid://6031768426", CONFIG.TweenSpeed, 5, function(box, text)
		local val = tonumber(text)
		if val and val >= 10 and val <= 250 then CONFIG.TweenSpeed = val else box.Text = tostring(CONFIG.TweenSpeed) end
	end)

	createSectionHeader(pageTP, "SECURITE & MOUVEMENTS", 6)
	createToggleRow(pageTP, "Activer Deplacement Aleatoire", "rbxassetid://6031768426", "RandomizeOffset", 7)
	createInputRow(pageTP, "Marge Aleatoire (studs) :", "rbxassetid://6031768426", CONFIG.RandomOffsetRange, 8, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.1 and val <= 10 then CONFIG.RandomOffsetRange = val else box.Text = tostring(CONFIG.RandomOffsetRange) end
	end)

	createToggleRow(pageTP, "Mode Noclip Permanent", "rbxassetid://6034855071", "NoclipPermanent", 9)

	-- ============================================
	-- ONGLET 4 : DONJON & VENTE
	-- ============================================
	createSectionHeader(pageDungeon, "LANCEMENT DE DONJONS", 1)
	createDropdownRow(pageDungeon, "Nom du Donjon :", "rbxassetid://6034287517", CONFIG.DungeonName, DUNGEONS_LIST, 2, function(newVal)
		CONFIG.DungeonName = newVal
	end)

	createDropdownRow(pageDungeon, "Difficulte :", "rbxassetid://6034287517", CONFIG.Difficulty, DIFFICULTIES_LIST, 3, function(newVal)
		CONFIG.Difficulty = newVal
	end)

	createInputRow(pageDungeon, "Delai de Relancement (s) :", "rbxassetid://6031768426", CONFIG.RetryDelay, 4, function(box, text)
		local val = tonumber(text)
		if val and val >= 0 and val <= 15 then CONFIG.RetryDelay = val else box.Text = tostring(CONFIG.RetryDelay) end
	end)

	createInputRow(pageDungeon, "Seuil auto-soin (vie %) :", "rbxassetid://6034287517", math.floor(CONFIG.HealThreshold * 100), 5, function(box, text)
		local val = tonumber(text)
		if val and val >= 5 and val <= 100 then CONFIG.HealThreshold = val / 100 else box.Text = tostring(math.floor(CONFIG.HealThreshold * 100)) end
	end)

	createSectionHeader(pageDungeon, "AUTO-VENTE D'INVENTAIRE", 6)
	createToggleRow(pageDungeon, "Vendre objets COMMUNS", "rbxassetid://6034287514", "SellCommon", 7)
	createToggleRow(pageDungeon, "Vendre objets PEU COMMUNS", "rbxassetid://6034287514", "SellUncommon", 8)
	createToggleRow(pageDungeon, "Vendre objets RARES", "rbxassetid://6034287514", "SellRare", 9)

	-- ============================================
	-- ONGLET 5 : SYSTEME
	-- ============================================
	createSectionHeader(pageSystem, "PROPRIETES PHYSIQUES", 1)
	createInputRow(pageSystem, "Vitesse de marche (WS) :", "rbxassetid://6031768426", CONFIG.WalkSpeed, 2, function(box, text)
		local val = tonumber(text)
		if val and val >= 16 and val <= 150 then CONFIG.WalkSpeed = val else box.Text = tostring(CONFIG.WalkSpeed) end
	end)

	createInputRow(pageSystem, "Puissance de Saut (JP) :", "rbxassetid://6031768426", CONFIG.JumpPower, 3, function(box, text)
		local val = tonumber(text)
		if val and val >= 50 and val <= 250 then CONFIG.JumpPower = val else box.Text = tostring(CONFIG.JumpPower) end
	end)

	createSectionHeader(pageSystem, "OPTIMISATION", 4)
	
	-- 3D Rendering (Clay Mint Style)
	local optiFrame = Instance.new("Frame")
	optiFrame.Size = UDim2.new(1, 0, 0, 34)
	optiFrame.BackgroundTransparency = 1
	optiFrame.LayoutOrder = 5

	local optiBtn = Instance.new("TextButton")
	optiBtn.Size = UDim2.new(0, 18, 0, 18)
	optiBtn.Position = UDim2.new(0, 4, 0.5, -9)
	optiBtn.BackgroundColor3 = CONFIG.Disable3DRendering and colorMintActive or Color3.fromRGB(18, 38, 30)
	optiBtn.Text = CONFIG.Disable3DRendering and "✓" or ""
	optiBtn.TextColor3 = Color3.fromRGB(12, 28, 22)
	optiBtn.TextSize = 10
	optiBtn.Font = Enum.Font.GothamBold
	
	local optiCorner = Instance.new("UICorner")
	optiCorner.CornerRadius = UDim.new(0, 5)
	optiCorner.Parent = optiBtn

	local optiStroke = Instance.new("UIStroke")
	optiStroke.Thickness = 2
	optiStroke.Color = CONFIG.Disable3DRendering and Color3.fromRGB(180, 255, 220) or colorEmeraldBorder
	optiStroke.Parent = optiBtn

	local optiGrad = Instance.new("UIGradient")
	optiGrad.Rotation = 90
	optiGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180))
	})
	optiGrad.Parent = optiBtn
	optiBtn.Parent = optiFrame

	local optiLbl = Instance.new("TextLabel")
	optiLbl.Size = UDim2.new(1, -34, 1, 0)
	optiLbl.Position = UDim2.new(0, 34, 0, 0)
	optiLbl.BackgroundTransparency = 1
	optiLbl.Text = "Mode nuit (Desactiver Rendu 3D)"
	optiLbl.TextColor3 = colorTextLight
	optiLbl.TextSize = 11
	optiLbl.TextXAlignment = Enum.TextXAlignment.Left
	optiLbl.Font = Enum.Font.Gotham
	optiLbl.Parent = optiFrame

	optiBtn.MouseButton1Click:Connect(function()
		CONFIG.Disable3DRendering = not CONFIG.Disable3DRendering
		animateColor(optiBtn, "BackgroundColor3", CONFIG.Disable3DRendering and colorMintActive or Color3.fromRGB(18, 38, 30))
		optiStroke.Color = CONFIG.Disable3DRendering and Color3.fromRGB(180, 255, 220) or colorEmeraldBorder
		optiBtn.Text = CONFIG.Disable3DRendering and "✓" or ""
		pcall(function()
			RunService:Set3dRenderingEnabled(not CONFIG.Disable3DRendering)
		end)
	end)
	optiFrame.Parent = pageSystem

	createSectionHeader(pageSystem, "FERMETURE", 6)
	
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(1, 0, 0, 36)
	closeBtn.BackgroundColor3 = colorCoralWarning
	closeBtn.Text = "QUITTER & FERMER L'INTERFACE"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 12
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.LayoutOrder = 7
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Thickness = 2
	closeStroke.Color = Color3.fromRGB(255, 180, 190)
	closeStroke.Parent = closeBtn
	
	closeBtn.MouseEnter:Connect(function()
		animateColor(closeBtn, "BackgroundColor3", Color3.fromRGB(255, 95, 128))
	end)
	closeBtn.MouseLeave:Connect(function()
		animateColor(closeBtn, "BackgroundColor3", colorCoralWarning)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		stopFarm()
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
		screenGui:Destroy()
	end)
	closeBtn.Parent = pageSystem

	-- ============================================
	-- INITIALISATION ET MISE A JOUR
	-- ============================================
	selectTab("Status")

	-- Update des stats asynchrones
	task.spawn(function()
		while screenGui.Parent do
			local elapsed = os.time() - STATS.StartTime
			local minutes = math.floor(elapsed / 60)
			local seconds = elapsed % 60
			local timeStr = string.format("%02d:%02d", minutes, seconds)

			local fullStatsText = "Kills : "
				.. STATS.Kills
				.. "\nDonjons relances : "
				.. STATS.Dungeons
				.. "\nTemps de session : "
				.. timeStr
				.. "\nButins : "
				.. STATS.LootCollected
				.. " | Ventes : "
				.. STATS.ItemsSold

			statusStatsLabel.Text = fullStatsText
			task.wait(1)
		end
	end)

	-- Touche F6
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.F6 then
			if isRunning then
				stopFarm()
				mainToggleBtn.Text = "DÉMARRER L'AUTOFARM [F6]"
				mainToggleBtn.BackgroundColor3 = colorMintActive
				toggleStroke.Color = Color3.fromRGB(180, 255, 220)
			else
				startFarm()
				mainToggleBtn.Text = "ARRÊTER L'AUTOFARM [F6]"
				mainToggleBtn.BackgroundColor3 = colorCoralWarning
				toggleStroke.Color = Color3.fromRGB(255, 180, 190)
			end
		end
	end)

	print("GUI ULTIME V13 CLAYMORPHISM CHARGEE !")
end

-- ============================================================
-- 12. LANCEMENT
-- ============================================================

task.wait(0.5)
createUltimateGUI()
