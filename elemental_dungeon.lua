-- ======================================================
-- AUTOFARM ULTIME – VERSION GUI V11 (CLAYMORPHISM & WINDOWS STYLE)
-- Onglets, Icônes, Équipements intelligents, Réduire/Agrandir/Fermer !
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
	print("❌ Services non trouvés !")
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
	print("❌ Remotes critiques non trouvés !")
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

-- Noclip permanent / temporaire
RunService.Stepped:Connect(function()
	if (isTweening or CONFIG.NoclipPermanent) and LocalPlayer.Character then
		for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
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

local currentTarget = nil
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
		return nil
	end

	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		currentTarget = mobs[1]
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
	
	-- Incrémentation de kills fiable
	if currentTarget and not monitoredMobs[currentTarget] then
		monitoredMobs[currentTarget] = true
		local humanoid = currentTarget:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				STATS.Kills = STATS.Kills + 1
				monitoredMobs[currentTarget] = nil
			end)
		end
		currentTarget.Destroying:Connect(function()
			monitoredMobs[currentTarget] = nil
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
-- 11. CRÉATION DE L'INTERFACE EN CLAYMORPHISM AVEC CONTRÔLES WINDOWS
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

	-- Frame principal (Puffy Claymorphism Style)
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, defaultWidth, 0, defaultHeight)
	mainFrame.Position = UDim2.new(0.5, -defaultWidth/2, 0.5, -defaultHeight/2)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = true
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui

	-- Bordure claymorphic douce (Puffy Stroke)
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = Color3.fromRGB(48, 48, 75)
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = mainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20) -- Coins très arrondis style Clay
	corner.Parent = mainFrame

	-- Barre de titre (Style Windows 11 / Clay)
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 45)
	titleBar.BackgroundColor3 = Color3.fromRGB(38, 38, 58)
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainFrame

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 20)
	titleCorner.Parent = titleBar

	-- Cacher l'arrondi du bas pour la transition avec le corps
	local titleHideBottom = Instance.new("Frame")
	titleHideBottom.Size = UDim2.new(1, 0, 0, 10)
	titleHideBottom.Position = UDim2.new(0, 0, 1, -10)
	titleHideBottom.BackgroundColor3 = Color3.fromRGB(38, 38, 58)
	titleHideBottom.BorderSizePixel = 0
	titleHideBottom.Parent = titleBar

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(0.65, 0, 1, 0)
	titleText.Position = UDim2.new(0, 16, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "⚡ ELEMENTAL FARMER V11"
	titleText.TextColor3 = Color3.fromRGB(240, 240, 255)
	titleText.TextSize = 13
	titleText.Font = Enum.Font.GothamBold
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.Parent = titleBar

	-- Conteneur des boutons Windows
	local winControls = Instance.new("Frame")
	winControls.Size = UDim2.new(0, 130, 1, 0)
	winControls.Position = UDim2.new(1, -130, 0, 0)
	winControls.BackgroundTransparency = 1
	winControls.Parent = titleBar

	local navList = Instance.new("UIListLayout")
	navList.FillDirection = Enum.FillDirection.Horizontal
	navList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	navList.SortOrder = Enum.SortOrder.LayoutOrder
	navList.Parent = winControls

	-- Variables de visibilité pour la minimisation
	local tabBar = Instance.new("Frame")
	local pageContainer = Instance.new("Frame")

	local function createWinBtn(text, order, hoverColor, clickCallback)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 40, 1, 0)
		btn.BackgroundTransparency = 1
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(200, 200, 220)
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
			btn.TextColor3 = Color3.fromRGB(200, 200, 220)
		end)
		btn.MouseButton1Click:Connect(clickCallback)
	end

	-- Bouton Réduire (_) Windows
	createWinBtn("—", 1, Color3.fromRGB(50, 50, 75), function()
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

	-- Bouton Agrandir (▢) Windows
	createWinBtn("▢", 2, Color3.fromRGB(50, 50, 75), function()
		if isWindowMinimized then return end
		isWindowMaximized = not isWindowMaximized
		local targetH = isWindowMaximized and maximizedHeight or defaultHeight
		mainFrame:TweenSize(UDim2.new(0, defaultWidth, 0, targetH), "Out", "Quad", 0.25, true)
	end)

	-- Bouton Fermer (X) Windows (Rouge au survol)
	createWinBtn("✕", 3, Color3.fromRGB(190, 40, 40), function()
		stopFarm()
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
		screenGui:Destroy()
	end)

	-- Bar d'onglets (Navigation Bar)
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.Position = UDim2.new(0, 0, 0, 45)
	tabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 34)
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

	-- Helper de création de ScrollingFrame pour chaque Onglet
	local function createTabPage(name, layoutOrder)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 6
		scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
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
				btn.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
				btn.TextColor3 = Color3.fromRGB(0, 180, 255)
				btn.Font = Enum.Font.GothamBold
			else
				btn.BackgroundColor3 = Color3.fromRGB(20, 20, 34)
				btn.TextColor3 = Color3.fromRGB(160, 160, 180)
				btn.Font = Enum.Font.Gotham
			end
		end
	end

	-- Créateur de boutons d'onglets
	local function createTabButton(name, labelText, layoutOrder)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.2, 0, 1, 0)
		btn.BackgroundColor3 = Color3.fromRGB(20, 20, 34)
		btn.BorderSizePixel = 0
		btn.Text = labelText
		btn.TextColor3 = Color3.fromRGB(160, 160, 180)
		btn.TextSize = 11
		btn.Font = Enum.Font.Gotham
		btn.LayoutOrder = layoutOrder
		btn.Parent = tabBar

		btn.MouseButton1Click:Connect(function()
			selectTab(name)
		end)

		tabButtons[name] = btn
	end

	createTabButton("Status", "🏠 Status", 1)
	createTabButton("Combat", "⚔️ Combat", 2)
	createTabButton("TP", "📍 Parcours", 3)
	createTabButton("Dungeon", "🏰 Donjon", 4)
	createTabButton("System", "⚙️ Système", 5)

	-- ============================================
	-- CONTRÔLES STYLISÉS CLAYMORPHISM (PUFFY LOOK)
	-- ============================================
	local function createToggleRow(parent, label, configKey, layoutOrder)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 34)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		-- Puffy Clay Toggle Button
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 22, 0, 22)
		btn.Position = UDim2.new(0, 4, 0.5, -11)
		btn.BackgroundColor3 = CONFIG[configKey] and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(24, 24, 38)
		btn.Text = CONFIG[configKey] and "✓" or ""
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextSize = 11
		btn.Font = Enum.Font.GothamBold
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6) -- Arrondi doux
		btnCorner.Parent = btn
		
		-- UIStroke pour le relief 3D
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 2
		btnStroke.Color = CONFIG[configKey] and Color3.fromRGB(80, 210, 255) or Color3.fromRGB(42, 42, 62)
		btnStroke.Parent = btn
		btn.Parent = frame

		-- Soft gradient pour l'aspect argileux
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
		})
		gradient.Parent = btn

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -36, 1, 0)
		lbl.Position = UDim2.new(0, 36, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(220, 220, 240)
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = frame

		btn.MouseButton1Click:Connect(function()
			CONFIG[configKey] = not CONFIG[configKey]
			animateColor(btn, "BackgroundColor3", CONFIG[configKey] and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(24, 24, 38))
			btnStroke.Color = CONFIG[configKey] and Color3.fromRGB(80, 210, 255) or Color3.fromRGB(42, 42, 62)
			btn.Text = CONFIG[configKey] and "✓" or ""
		end)

		frame.Parent = parent
		return frame
	end

	local function createDropdownRow(parent, label, initialValue, options, layoutOrder, callback)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 34)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder
		
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.45, 0, 1, 0)
		lbl.Position = UDim2.new(0, 4, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = frame

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.52, 0, 1, 0)
		btn.Position = UDim2.new(0.48, 0, 0, 0)
		btn.BackgroundColor3 = Color3.fromRGB(22, 22, 36)
		btn.Text = tostring(initialValue)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.TextSize = 11
		btn.Font = Enum.Font.GothamSemibold
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8) -- Plus arrondi
		btnCorner.Parent = btn
		
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 2
		btnStroke.Color = Color3.fromRGB(45, 45, 68)
		btnStroke.Parent = btn

		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190))
		})
		gradient.Parent = btn
		btn.Parent = frame

		local optList = options
		btn.MouseButton1Click:Connect(function()
			if label:find("Arme") or label:find("Élément") then
				optList = getAvailableTools()
			end

			local index = table.find(optList, btn.Text) or 1
			index = index % #optList + 1
			btn.Text = tostring(optList[index])
			callback(optList[index])
		end)

		frame.Parent = parent
		return frame
	end

	local function createInputRow(parent, label, initialValue, layoutOrder, callback)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 34)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder
		
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.45, 0, 1, 0)
		lbl.Position = UDim2.new(0, 4, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = Color3.fromRGB(200, 200, 220)
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.Gotham
		lbl.Parent = frame

		local input = Instance.new("TextBox")
		input.Size = UDim2.new(0.52, 0, 1, 0)
		input.Position = UDim2.new(0.48, 0, 0, 0)
		input.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
		input.Text = tostring(initialValue)
		input.TextColor3 = Color3.fromRGB(255, 255, 255)
		input.TextSize = 11
		input.Font = Enum.Font.Gotham
		
		local cornerInput = Instance.new("UICorner")
		cornerInput.CornerRadius = UDim.new(0, 8)
		cornerInput.Parent = input

		local strokeInput = Instance.new("UIStroke")
		strokeInput.Thickness = 2
		strokeInput.Color = Color3.fromRGB(38, 38, 58)
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
		lbl.TextColor3 = Color3.fromRGB(0, 180, 255)
		lbl.TextSize = 10
		lbl.Font = Enum.Font.GothamBold
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.LayoutOrder = layoutOrder
		lbl.Parent = parent
	end

	-- ============================================
	-- ONGLET 1 : STATUS (STATS CLAY)
	-- ============================================
	local mainToggleBtn = Instance.new("TextButton")
	mainToggleBtn.Size = UDim2.new(1, 0, 0, 45)
	mainToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
	mainToggleBtn.Text = "DÉMARRER L'AUTOFARM [F6]"
	mainToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	mainToggleBtn.TextSize = 13
	mainToggleBtn.Font = Enum.Font.GothamBold
	mainToggleBtn.LayoutOrder = 1
	
	local toggleCornerStatus = Instance.new("UICorner")
	toggleCornerStatus.CornerRadius = UDim.new(0, 10)
	toggleCornerStatus.Parent = mainToggleBtn
	
	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Thickness = 2
	toggleStroke.Color = Color3.fromRGB(90, 220, 140)
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
		animateColor(mainToggleBtn, "BackgroundColor3", isRunning and Color3.fromRGB(230, 60, 60) or Color3.fromRGB(50, 210, 120))
	end)
	mainToggleBtn.MouseLeave:Connect(function()
		animateColor(mainToggleBtn, "BackgroundColor3", isRunning and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(40, 180, 100))
	end)

	mainToggleBtn.MouseButton1Click:Connect(function()
		if isRunning then
			stopFarm()
			mainToggleBtn.Text = "DÉMARRER L'AUTOFARM [F6]"
			mainToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
			toggleStroke.Color = Color3.fromRGB(90, 220, 140)
		else
			startFarm()
			mainToggleBtn.Text = "ARRÊTER L'AUTOFARM [F6]"
			mainToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
			toggleStroke.Color = Color3.fromRGB(240, 90, 90)
		end
	end)

	-- Stats Card (Clay look)
	local statusStatsFrame = Instance.new("Frame")
	statusStatsFrame.Size = UDim2.new(1, 0, 0, 110)
	statusStatsFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
	statusStatsFrame.BorderSizePixel = 0
	statusStatsFrame.LayoutOrder = 2
	
	local statusStatsCorner = Instance.new("UICorner")
	statusStatsCorner.CornerRadius = UDim.new(0, 10)
	statusStatsCorner.Parent = statusStatsFrame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 2
	cardStroke.Color = Color3.fromRGB(40, 40, 62)
	cardStroke.Parent = statusStatsFrame

	local statusStatsLabel = Instance.new("TextLabel")
	statusStatsLabel.Size = UDim2.new(1, -20, 1, -20)
	statusStatsLabel.Position = UDim2.new(0, 10, 0, 10)
	statusStatsLabel.BackgroundTransparency = 1
	statusStatsLabel.Text = "💀 Kills : 0\n🏰 Donjons relancés : 0\n⏱ Temps de session : 00:00\n📦 Butins : 0 | 💰 Ventes : 0"
	statusStatsLabel.TextColor3 = Color3.fromRGB(200, 200, 240)
	statusStatsLabel.TextSize = 12
	statusStatsLabel.LineHeight = 1.35
	statusStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusStatsLabel.Font = Enum.Font.Gotham
	statusStatsLabel.Parent = statusStatsFrame
	statusStatsFrame.Parent = pageStatus

	createSectionHeader(pageStatus, "MODULES ACTIFS", 3)
	createToggleRow(pageStatus, "🤖 Auto Attaquer les Monstres", "AutoAttack", 4)
	createToggleRow(pageStatus, "🪙 Auto Collecter le Butin (Loot)", "AutoCollect", 5)
	createToggleRow(pageStatus, "❤️ Auto Soin (Heal)", "AutoHeal", 6)
	createToggleRow(pageStatus, "🛍️ Auto Vendre l'Inventaire", "AutoSell", 7)
	createToggleRow(pageStatus, "🔄 Auto Relancer le Donjon", "AutoRetry", 8)
	createToggleRow(pageStatus, "🚪 Auto Rejoindre en Donjon", "AutoJoinDungeon", 9)

	-- ============================================
	-- ONGLET 2 : COMBAT
	-- ============================================
	createSectionHeader(pageCombat, "LOGIQUE D'ÉQUIPEMENT", 1)
	createDropdownRow(pageCombat, "⚙️ Mode d'Équipement :", CONFIG.EquipMode, {"Both", "Weapon Only", "Element Only", "None"}, 2, function(newVal)
		CONFIG.EquipMode = newVal
	end)

	local toolsList = getAvailableTools()
	createDropdownRow(pageCombat, "⚔️ Arme Principale :", CONFIG.SelectedWeapon, toolsList, 3, function(newVal)
		CONFIG.SelectedWeapon = newVal
	end)

	createDropdownRow(pageCombat, "🔮 Outil Élément :", CONFIG.SelectedElement, toolsList, 4, function(newVal)
		CONFIG.SelectedElement = newVal
	end)

	createSectionHeader(pageCombat, "PARAMÈTRES D'ATTAQUE", 5)
	createDropdownRow(pageCombat, "🔥 Mode de Combat :", CONFIG.AttackMode, {"Sword & Skills", "Sword Only", "Skills Only"}, 6, function(newVal)
		CONFIG.AttackMode = newVal
	end)

	createInputRow(pageCombat, "⏱️ Délai Attaque Min (s) :", CONFIG.SwingDelayMin, 7, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.01 and val <= 2 then CONFIG.SwingDelayMin = val else box.Text = tostring(CONFIG.SwingDelayMin) end
	end)

	createInputRow(pageCombat, "⏱️ Délai Attaque Max (s) :", CONFIG.SwingDelayMax, 8, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.01 and val <= 2 then CONFIG.SwingDelayMax = val else box.Text = tostring(CONFIG.SwingDelayMax) end
	end)

	createInputRow(pageCombat, "📏 Distance d'Attaque (studs) :", CONFIG.MaxAttackDistance, 9, function(box, text)
		local val = tonumber(text)
		if val and val >= 1 and val <= 50 then CONFIG.MaxAttackDistance = val else box.Text = tostring(CONFIG.MaxAttackDistance) end
	end)

	createSectionHeader(pageCombat, "COMPÉTENCES AUTOS (SKILLS)", 10)
	
	-- Flat active slots selector (Clay version)
	local function createSkillsRow(parent, layoutOrder)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 36)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.38, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "🌀 Slots Actifs :"
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
			btn.BackgroundColor3 = isActivated and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(30, 30, 48)
			btn.Text = "Slot " .. slot
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.TextSize = 10
			btn.Font = Enum.Font.GothamBold
			
			local cornerS = Instance.new("UICorner")
			cornerS.CornerRadius = UDim.new(0, 6)
			cornerS.Parent = btn

			local strokeS = Instance.new("UIStroke")
			strokeS.Thickness = 2
			strokeS.Color = isActivated and Color3.fromRGB(80, 210, 255) or Color3.fromRGB(42, 42, 62)
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
					animateColor(btn, "BackgroundColor3", Color3.fromRGB(30, 30, 48))
					strokeS.Color = Color3.fromRGB(42, 42, 62)
				else
					table.insert(CONFIG.SelectedSkills, slot)
					table.sort(CONFIG.SelectedSkills)
					animateColor(btn, "BackgroundColor3", Color3.fromRGB(0, 180, 255))
					strokeS.Color = Color3.fromRGB(80, 210, 255)
				end
			end)
			btn.Parent = frame
		end

		frame.Parent = parent
		return frame
	end
	createSkillsRow(pageCombat, 11)

	createInputRow(pageCombat, "⏱️ Délai entre sorts (s) :", CONFIG.SkillDelay, 12, function(box, text)
		local val = tonumber(text)
		if val and val >= 0 and val <= 10 then CONFIG.SkillDelay = val else box.Text = tostring(CONFIG.SkillDelay) end
	end)

	-- ============================================
	-- ONGLET 3 : PARCOURS & TELEPORTATION
	-- ============================================
	createSectionHeader(pageTP, "RÉGLAGES DES MOUVEMENTS", 1)
	createDropdownRow(pageTP, "📍 Position relative :", CONFIG.TP_Position, {"Top", "Bottom", "Behind", "Front", "Left", "Right"}, 2, function(newVal)
		CONFIG.TP_Position = newVal
	end)

	createInputRow(pageTP, "📏 Distance relative (studs) :", CONFIG.TP_Distance, 3, function(box, text)
		local val = tonumber(text)
		if val and val >= -10 and val <= 25 then CONFIG.TP_Distance = val else box.Text = tostring(CONFIG.TP_Distance) end
	end)

	createInputRow(pageTP, "📐 Offset Manuel (X,Y,Z) :", CONFIG.TP_Offset_X .. "," .. CONFIG.TP_Offset_Y .. "," .. CONFIG.TP_Offset_Z, 4, function(box, text)
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

	createInputRow(pageTP, "⚡ Vitesse de Tween (studs/s) :", CONFIG.TweenSpeed, 5, function(box, text)
		local val = tonumber(text)
		if val and val >= 10 and val <= 250 then CONFIG.TweenSpeed = val else box.Text = tostring(CONFIG.TweenSpeed) end
	end)

	createSectionHeader(pageTP, "SÉCURITÉ & ANTI-BAN", 6)
	createToggleRow(pageTP, "🎲 Activer Déplacement Aléatoire", "RandomizeOffset", 7)
	createInputRow(pageTP, "🎲 Marge Aléatoire (studs) :", CONFIG.RandomOffsetRange, 8, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.1 and val <= 10 then CONFIG.RandomOffsetRange = val else box.Text = tostring(CONFIG.RandomOffsetRange) end
	end)

	createToggleRow(pageTP, "👻 Mode Noclip Permanent (Traverser)", "NoclipPermanent", 9)

	-- ============================================
	-- ONGLET 4 : DONJON & VENTE
	-- ============================================
	createSectionHeader(pageDungeon, "LANCEMENT DE DONJONS", 1)
	createDropdownRow(pageDungeon, "🏰 Nom du Donjon :", CONFIG.DungeonName, DUNGEONS_LIST, 2, function(newVal)
		CONFIG.DungeonName = newVal
	end)

	createDropdownRow(pageDungeon, "🔥 Difficulté :", CONFIG.Difficulty, DIFFICULTIES_LIST, 3, function(newVal)
		CONFIG.Difficulty = newVal
	end)

	createInputRow(pageDungeon, "⏱️ Délai de Relancement (s) :", CONFIG.RetryDelay, 4, function(box, text)
		local val = tonumber(text)
		if val and val >= 0 and val <= 15 then CONFIG.RetryDelay = val else box.Text = tostring(CONFIG.RetryDelay) end
	end)

	createInputRow(pageDungeon, "💚 Seuil auto-soin (vie %) :", math.floor(CONFIG.HealThreshold * 100), 5, function(box, text)
		local val = tonumber(text)
		if val and val >= 5 and val <= 100 then CONFIG.HealThreshold = val / 100 else box.Text = tostring(math.floor(CONFIG.HealThreshold * 100)) end
	end)

	createSectionHeader(pageDungeon, "FILTRES D'AUTO-VENTE", 6)
	createToggleRow(pageDungeon, "🟢 Vendre objets COMMUNS", "SellCommon", 7)
	createToggleRow(pageDungeon, "🔵 Vendre objets PEU COMMUNS", "SellUncommon", 8)
	createToggleRow(pageDungeon, "🟣 Vendre objets RARES", "SellRare", 9)

	-- ============================================
	-- ONGLET 5 : SYSTEME, PHYSIQUE & FERMETURE
	-- ============================================
	createSectionHeader(pageSystem, "PROPRIÉTÉS PHYSIQUES", 1)
	createInputRow(pageSystem, "⚡ Vitesse de marche (WS) :", CONFIG.WalkSpeed, 2, function(box, text)
		local val = tonumber(text)
		if val and val >= 16 and val <= 150 then CONFIG.WalkSpeed = val else box.Text = tostring(CONFIG.WalkSpeed) end
	end)

	createInputRow(pageSystem, "🚀 Puissance de Saut (JP) :", CONFIG.JumpPower, 3, function(box, text)
		local val = tonumber(text)
		if val and val >= 50 and val <= 250 then CONFIG.JumpPower = val else box.Text = tostring(CONFIG.JumpPower) end
	end)

	createSectionHeader(pageSystem, "OPTIMISATION SYSTÈME", 4)
	-- Rendu 3D (Clay style)
	local optiFrame = Instance.new("Frame")
	optiFrame.Size = UDim2.new(1, 0, 0, 34)
	optiFrame.BackgroundTransparency = 1
	optiFrame.LayoutOrder = 5

	local optiBtn = Instance.new("TextButton")
	optiBtn.Size = UDim2.new(0, 18, 0, 18)
	optiBtn.Position = UDim2.new(0, 4, 0.5, -9)
	optiBtn.BackgroundColor3 = CONFIG.Disable3DRendering and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(24, 24, 38)
	optiBtn.Text = CONFIG.Disable3DRendering and "✓" or ""
	optiBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	optiBtn.TextSize = 10
	optiBtn.Font = Enum.Font.GothamBold
	
	local optiCorner = Instance.new("UICorner")
	optiCorner.CornerRadius = UDim.new(0, 5)
	optiCorner.Parent = optiBtn

	local optiStroke = Instance.new("UIStroke")
	optiStroke.Thickness = 2
	optiStroke.Color = CONFIG.Disable3DRendering and Color3.fromRGB(80, 210, 255) or Color3.fromRGB(42, 42, 62)
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
	optiLbl.Text = "🌙 Mode nuit (Désactiver Rendu 3D)"
	optiLbl.TextColor3 = Color3.fromRGB(220, 220, 240)
	optiLbl.TextSize = 11
	optiLbl.TextXAlignment = Enum.TextXAlignment.Left
	optiLbl.Font = Enum.Font.Gotham
	optiLbl.Parent = optiFrame

	optiBtn.MouseButton1Click:Connect(function()
		CONFIG.Disable3DRendering = not CONFIG.Disable3DRendering
		animateColor(optiBtn, "BackgroundColor3", CONFIG.Disable3DRendering and Color3.fromRGB(0, 180, 255) or Color3.fromRGB(24, 24, 38))
		optiStroke.Color = CONFIG.Disable3DRendering and Color3.fromRGB(80, 210, 255) or Color3.fromRGB(42, 42, 62)
		optiBtn.Text = CONFIG.Disable3DRendering and "✓" or ""
		pcall(function()
			RunService:Set3dRenderingEnabled(not CONFIG.Disable3DRendering)
		end)
	end)
	optiFrame.Parent = pageSystem

	-- ============================================
	-- INITIALISATION ET MISE A JOUR
	-- ============================================
	
	-- Par défaut, afficher le premier onglet (Status)
	selectTab("Status")

	-- Update des stats asynchrones
	task.spawn(function()
		while screenGui.Parent do
			local elapsed = os.time() - STATS.StartTime
			local minutes = math.floor(elapsed / 60)
			local seconds = elapsed % 60
			local timeStr = string.format("%02d:%02d", minutes, seconds)

			local fullStatsText = "💀 Kills : "
				.. STATS.Kills
				.. "\n🏰 Donjons relancés : "
				.. STATS.Dungeons
				.. "\n⏱ Temps de session : "
				.. timeStr
				.. "\n📦 Butins : "
				.. STATS.LootCollected
				.. " | 💰 Ventes : "
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
				mainToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 100)
				toggleStroke.Color = Color3.fromRGB(90, 220, 140)
			else
				startFarm()
				mainToggleBtn.Text = "ARRÊTER L'AUTOFARM [F6]"
				mainToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
				toggleStroke.Color = Color3.fromRGB(240, 90, 90)
			end
		end
	end)

	print("✅ GUI ULTIME V11 CLAYMORPHISM & WINDOWS STYLE CHARGÉE !")
end

-- ============================================================
-- 12. LANCEMENT
-- ============================================================

task.wait(0.5)
createUltimateGUI()
