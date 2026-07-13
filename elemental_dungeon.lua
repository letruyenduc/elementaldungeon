-- ======================================================
-- AUTOFARM ULTIME – VERSION GUI V18 (COMBAT STABILIZED)
-- Style officiel "Dungeon Creator" - Séparation Mouvement/Combat, Alternance Both, FredokaOne
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
-- 5. SCAN DYNAMIQUE DES DONJONS ET DIFFICULTÉS
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

local function scanDifficulties()
	local list = {}
	pcall(function()
		local sharedModules = ReplicatedStorage.ReplicatedStorage.SharedModules
		local dungeonsFolder = sharedModules and sharedModules:FindFirstChild("Dungeons")
		local dungeonsData = dungeonsFolder and dungeonsFolder:FindFirstChild("DungeonsData")
		if dungeonsData then
			for _, child in ipairs(dungeonsData:GetChildren()) do
				if child:IsA("ModuleScript") then
					local module = require(child)
					if module and module.Difficulties then
						for diff, _ in pairs(module.Difficulties) do
							if not table.find(list, diff) then
								table.insert(list, diff)
							end
						end
					elseif module and module.Rewards then
						for diff, _ in pairs(module.Rewards) do
							if not table.find(list, diff) then
								table.insert(list, diff)
							end
						end
					end
				end
			end
		end
	end)
	if #list == 0 then
		list = { "Easy", "Medium", "Hard", "Hell" }
	end
	table.sort(list)
	return list
end

local DUNGEONS_LIST = scanDungeons()
local DIFFICULTIES_LIST = scanDifficulties()

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
-- 7. CONFIGURATION HAUTEMENT PERSONNALISABLE (DESACTIVÉE PAR DÉFAUT)
-- ============================================================

local CONFIG = {
	AutoFarm = false, -- Le mouvement automatique (tweening de mobs en mobs)
	AutoAttack = false,
	AutoHeal = false,
	AutoCollect = false,
	AutoEquip = false,
	AutoSkills = false,
	AutoSell = false,
	AutoRetry = false,
	AutoJoinDungeon = false,

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
	SellCommon = false,
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

	-- Forcer la position à l'offset configuré par rapport au monstre pour empêcher la chute
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

-- ============================================================
-- 10. FIL PERMANENT D'EXÉCUTION (BACKGROUND LOOP)
-- ============================================================

local function runBackgroundLoop()
	task.spawn(function()
		local loopCounter = 0
		local combatCycle = 0
		while true do
			loopCounter = loopCounter + 1

			-- Auto-heal (soin constant si activé)
			if CONFIG.AutoHeal and UseHeal then
				local character = LocalPlayer.Character
				local humanoid = character and character:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health / humanoid.MaxHealth < CONFIG.HealThreshold then
					pcall(function() UseHeal:InvokeServer() end)
					task.wait(0.2)
				end
			end

			-- 1. DEPLACEMENT (AUTOFARM DE MONSTRES EN MONSTRES)
			if CONFIG.AutoFarm then
				local target = getClosestMob()
				if target then
					tweenToMob(target)
				end
			end

			-- 2. COMBAT LOGIC (AUTO ATTACK ACTIVE)
			if CONFIG.AutoAttack then
				local target = activeTarget or getClosestMob()
				if target then
					local targetPart = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChild("PrimaryPart")
					local character = LocalPlayer.Character
					local hrp = character and character:FindFirstChild("HumanoidRootPart")
					local inRange = false
					if targetPart and hrp then
						-- Si le déplacement automatique est actif, on considère qu'on est à portée.
						-- Sinon, seulement si on s'approche manuellement à moins de 25 studs.
						local maxDist = CONFIG.AutoFarm and CONFIG.MaxAttackDistance or 25
						inRange = (hrp.Position - targetPart.Position).Magnitude <= maxDist
					end

					if inRange then
						combatCycle = combatCycle + 1
						local mode = CONFIG.EquipMode
						
						if mode == "Both" then
							-- Alternance des cycles d'équipements pour éviter le blocage Roblox d'un seul tool actif
							if combatCycle % 2 == 1 then
								-- Tour Épée
								autoEquipSpecific(CONFIG.SelectedWeapon)
								if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
									swing()
								end
							else
								-- Tour Sorts
								autoEquipSpecific(CONFIG.SelectedElement)
								if CONFIG.AutoSkills and UseAbility and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
									for _, slot in ipairs(CONFIG.SelectedSkills) do
										task.spawn(useSkill, slot)
									end
								end
							end
						else
							-- Équipements uniques standards
							if mode == "Weapon Only" then
								autoEquipSpecific(CONFIG.SelectedWeapon)
							elseif mode == "Element Only" then
								autoEquipSpecific(CONFIG.SelectedElement)
							end

							if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
								swing()
							end

							if CONFIG.AutoSkills and UseAbility and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
								for _, slot in ipairs(CONFIG.SelectedSkills) do
									task.spawn(useSkill, slot)
								end
							end
						end
					end
				end
			end

			-- Tâches secondaires (Collect & Sell)
			if CONFIG.AutoCollect and loopCounter % 15 == 0 then
				task.spawn(autoCollect)
			end

			if CONFIG.AutoSell and loopCounter % 50 == 0 then
				task.spawn(autoSell)
			end

			-- Relancement de donjon (uniquement si autofarm actif)
			if CONFIG.AutoFarm and CONFIG.AutoRetry and loopCounter % 12 == 0 then
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
-- 11. CRÉATION DE L'INTERFACE AU STYLE OFFICIEL DU JEU (V18)
-- ============================================================

local function createUltimateGUI()
	-- ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ElementalFarmGUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = CoreGui

	-- Palette de couleurs inspirée du Dungeon Creator (Bleu ardoise et contours noirs)
	local colorSlateBackground = Color3.fromRGB(36, 50, 67)  -- Fond principal
	local colorSlateSidebar = Color3.fromRGB(24, 38, 51)     -- Sidebar & sous-panels
	local colorBorderDark = Color3.fromRGB(15, 22, 30)       -- Contour noir épais
	local colorTextWhite = Color3.fromRGB(255, 255, 255)     -- Texte blanc
	local colorTextInactive = Color3.fromRGB(150, 175, 195)  -- Texte désactivé
	
	local colorGreenActive = Color3.fromRGB(0, 200, 80)      -- Bouton vert (Démarrer)
	local colorRedWarning = Color3.fromRGB(220, 50, 50)      -- Bouton rouge (Quitter / Fermer)
	local colorBlueSelect = Color3.fromRGB(40, 130, 220)     -- Bouton bleu (Medium / Options)

	-- Frame principal (Format Paysage 620x420)
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 620, 0, 420)
	mainFrame.Position = UDim2.new(0.5, -310, 0.5, -210)
	mainFrame.BackgroundColor3 = colorSlateBackground
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = true
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui

	-- Contour 3D épais noir
	local border = Instance.new("UIStroke")
	border.Thickness = 3
	border.Color = colorBorderDark
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = mainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = mainFrame

	-- Titre : "Elemental Dungeon"
	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2.new(0.65, 0, 0, 45)
	titleText.Position = UDim2.new(0, 16, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.Text = "Elemental Dungeon"
	titleText.TextColor3 = colorTextWhite
	titleText.TextSize = 18
	titleText.Font = Enum.Font.FredokaOne
	
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 1.5
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Parent = titleText
	titleText.Parent = mainFrame

	-- Gros bouton Fermer Windows circulaire rouge (Top Right)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 28, 0, 28)
	closeBtn.Position = UDim2.new(1, -38, 0, 8)
	closeBtn.BackgroundColor3 = colorRedWarning
	closeBtn.Text = "X"
	closeBtn.TextColor3 = colorTextWhite
	closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.FredokaOne
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0.5, 0) -- Rond
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

	-- Sidebar (Panneau d'onglets vertical à gauche)
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 135, 1, -55)
	sidebar.Position = UDim2.new(0, 10, 0, 45)
	sidebar.BackgroundColor3 = colorSlateSidebar
	sidebar.BorderSizePixel = 0
	sidebar.Parent = mainFrame

	local sidebarCorner = Instance.new("UICorner")
	sidebarCorner.CornerRadius = UDim.new(0, 12)
	sidebarCorner.Parent = sidebar

	local sidebarStroke = Instance.new("UIStroke")
	sidebarStroke.Thickness = 2
	sidebarStroke.Color = colorBorderDark
	sidebarStroke.Parent = sidebar

	local sidebarLayout = Instance.new("UIListLayout")
	sidebarLayout.Padding = UDim.new(0, 6)
	sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sidebarLayout.Parent = sidebar

	local sidebarPad = Instance.new("UIPadding")
	sidebarPad.PaddingTop = UDim.new(0, 6)
	sidebarPad.PaddingBottom = UDim.new(0, 6)
	sidebarPad.PaddingLeft = UDim.new(0, 6)
	sidebarPad.PaddingRight = UDim.new(0, 6)
	sidebarPad.Parent = sidebar

	-- Conteneur de pages à droite
	local pageContainer = Instance.new("Frame")
	pageContainer.Size = UDim2.new(1, -165, 1, -55)
	pageContainer.Position = UDim2.new(0, 155, 0, 45)
	pageContainer.BackgroundTransparency = 1
	pageContainer.Parent = mainFrame

	local pages = {}
	local tabButtons = {}

	-- Helper de création de ScrollingFrame
	local function createTabPage(name)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1, 0, 1, 0)
		scroll.BackgroundTransparency = 1
		scroll.ScrollBarThickness = 6
		scroll.ScrollBarImageColor3 = colorBlueSelect
		scroll.Visible = false
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.Parent = pageContainer

		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = scroll

		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 15)
		end)

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 2)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 4)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = scroll

		pages[name] = scroll
		return scroll
	end

	-- Initialisation des pages
	local pageStatus = createTabPage("Status")
	local pageCombat = createTabPage("Combat")
	local pageTP = createTabPage("TP")
	local pageDungeon = createTabPage("Dungeon")
	local pageSystem = createTabPage("System")

	-- Navigation switch
	local function selectTab(tabName)
		for name, page in pairs(pages) do
			page.Visible = (name == tabName)
		end
		for name, btn in pairs(tabButtons) do
			if name == tabName then
				btn.BackgroundColor3 = colorSlateBackground
				btn.IconLabel.ImageColor3 = colorTextWhite
				btn.TextLabel.TextColor3 = colorTextWhite
				btn.TextLabel.Font = Enum.Font.FredokaOne
			else
				btn.BackgroundColor3 = colorSlateSidebar
				btn.IconLabel.ImageColor3 = colorTextInactive
				btn.TextLabel.TextColor3 = colorTextInactive
				btn.TextLabel.Font = Enum.Font.FredokaOne
			end
		end
	end

	-- Créateur de boutons d'onglets verticaux
	local function createTabButton(name, iconId, text, layoutOrder)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 36)
		btn.BackgroundColor3 = colorSlateSidebar
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.LayoutOrder = layoutOrder
		btn.Parent = sidebar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0, 14, 0, 14)
		icon.Position = UDim2.new(0, 8, 0.5, -7)
		icon.BackgroundTransparency = 1
		icon.Image = iconId
		icon.ImageColor3 = colorTextInactive
		icon.Name = "IconLabel"
		icon.Parent = btn

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -30, 1, 0)
		lbl.Position = UDim2.new(0, 30, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = text
		lbl.TextColor3 = colorTextInactive
		lbl.TextSize = 11
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		
		local labelStroke = Instance.new("UIStroke")
		labelStroke.Thickness = 1
		labelStroke.Color = Color3.fromRGB(0, 0, 0)
		labelStroke.Parent = lbl
		lbl.Name = "TextLabel"
		lbl.Parent = btn

		btn.MouseButton1Click:Connect(function()
			selectTab(name)
		end)

		tabButtons[name] = btn
	end

	createTabButton("Status", "rbxassetid://6031768426", "Status", 1)
	createTabButton("Combat", "rbxassetid://6035043132", "Combat", 2)
	createTabButton("TP", "rbxassetid://6034855071", "Movement", 3)
	createTabButton("Dungeon", "rbxassetid://6034287517", "Dungeon", 4)
	createTabButton("System", "rbxassetid://6031289116", "System", 5)

	-- ============================================
	-- HELPER WIDGETS
	-- ============================================
	local function createToggleRow(parent, label, iconId, configKey, layoutOrder)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 34)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 22, 0, 22)
		btn.Position = UDim2.new(0, 4, 0.5, -11)
		btn.BackgroundColor3 = CONFIG[configKey] and colorGreenActive or colorSlateSidebar
		btn.Text = CONFIG[configKey] and "✓" or ""
		btn.TextColor3 = colorTextWhite
		btn.TextSize = 12
		btn.Font = Enum.Font.FredokaOne
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn
		
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 2
		btnStroke.Color = colorBorderDark
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
		icon.ImageColor3 = CONFIG[configKey] and colorGreenActive or colorTextInactive
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -56, 1, 0)
		lbl.Position = UDim2.new(0, 56, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		btn.MouseButton1Click:Connect(function()
			CONFIG[configKey] = not CONFIG[configKey]
			animateColor(btn, "BackgroundColor3", CONFIG[configKey] and colorGreenActive or colorSlateSidebar)
			icon.ImageColor3 = CONFIG[configKey] and colorGreenActive or colorTextInactive
			btn.Text = CONFIG[configKey] and "✓" or ""
		end)

		frame.Parent = parent
		return frame
	end

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
		icon.ImageColor3 = colorBlueSelect
		icon.Parent = topRow

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.42, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = topRow

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.5, 0, 0, 26)
		btn.Position = UDim2.new(0.5, 0, 0.5, -13)
		btn.BackgroundColor3 = colorSlateSidebar
		btn.Text = tostring(initialValue) .. "  ▼"
		btn.TextColor3 = colorTextWhite
		btn.TextSize = 11
		btn.Font = Enum.Font.FredokaOne
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn
		
		local btnStroke = Instance.new("UIStroke")
		btnStroke.Thickness = 2
		btnStroke.Color = colorBorderDark
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
		optionsListFrame.BackgroundColor3 = colorSlateSidebar
		optionsListFrame.BorderSizePixel = 0
		optionsListFrame.Visible = false
		optionsListFrame.Parent = frame

		local opCorner = Instance.new("UICorner")
		opCorner.CornerRadius = UDim.new(0, 8)
		opCorner.Parent = optionsListFrame

		local opStroke = Instance.new("UIStroke")
		opStroke.Thickness = 2
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
				optBtn.TextSize = 10
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
		icon.ImageColor3 = colorBlueSelect
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.35, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		-- Track
		local track = Instance.new("Frame")
		track.Size = UDim2.new(0.32, 0, 0, 8)
		track.Position = UDim2.new(0.42, 0, 0.5, -4)
		track.BackgroundColor3 = colorSlateSidebar
		track.BorderSizePixel = 0
		track.Parent = frame

		local trackCorner = Instance.new("UICorner")
		trackCorner.CornerRadius = UDim.new(0, 4)
		trackCorner.Parent = track

		local trackStroke = Instance.new("UIStroke")
		trackStroke.Thickness = 2
		trackStroke.Color = colorBorderDark
		trackStroke.Parent = track

		-- Fill
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new((initialValue - min) / (max - min), 0, 1, 0)
		fill.BackgroundColor3 = colorBlueSelect
		fill.BorderSizePixel = 0
		fill.Parent = track

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 4)
		fillCorner.Parent = fill

		-- Thumb
		local thumb = Instance.new("TextButton")
		thumb.Size = UDim2.new(0, 16, 0, 16)
		thumb.Position = UDim2.new((initialValue - min) / (max - min), -8, 0.5, -8)
		thumb.BackgroundColor3 = colorTextWhite
		thumb.Text = ""
		thumb.Parent = track

		local thumbCorner = Instance.new("UICorner")
		thumbCorner.CornerRadius = UDim.new(1, 0)
		thumbCorner.Parent = thumb

		local thumbStroke = Instance.new("UIStroke")
		thumbStroke.Thickness = 2
		thumbStroke.Color = colorBorderDark
		thumbStroke.Parent = thumb

		-- TextBox
		local box = Instance.new("TextBox")
		box.Size = UDim2.new(0.18, 0, 0, 26)
		box.Position = UDim2.new(0.8, 0, 0.5, -13)
		box.BackgroundColor3 = colorSlateSidebar
		box.Text = tostring(initialValue)
		box.TextColor3 = colorTextWhite
		box.TextSize = 11
		box.Font = Enum.Font.FredokaOne
		
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, 6)
		boxCorner.Parent = box

		local boxStroke = Instance.new("UIStroke")
		boxStroke.Thickness = 2
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
			thumb.Position = UDim2.new(percentage, -8, 0.5, -8)
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
		icon.ImageColor3 = colorBlueSelect
		icon.Parent = frame

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.42, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = label
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		local input = Instance.new("TextBox")
		input.Size = UDim2.new(0.5, 0, 0, 26)
		input.Position = UDim2.new(0.5, 0, 0.5, -13)
		input.BackgroundColor3 = colorSlateSidebar
		input.Text = tostring(initialValue)
		input.TextColor3 = colorTextWhite
		input.TextSize = 11
		input.Font = Enum.Font.FredokaOne
		
		local cornerInput = Instance.new("UICorner")
		cornerInput.CornerRadius = UDim.new(0, 8)
		cornerInput.Parent = input

		local strokeInput = Instance.new("UIStroke")
		strokeInput.Thickness = 2
		strokeInput.Color = colorBorderDark
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
		lbl.TextColor3 = colorBlueSelect
		lbl.TextSize = 10
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.LayoutOrder = layoutOrder
		lbl.Parent = parent
	end

	-- ============================================
	-- PAGES DEFINITIONS (REORGANIZED V18)
	-- ============================================

	-- 1. STATUS TAB (START BUTTON & STATISTICS ONLY)
	local mainToggleBtn = Instance.new("TextButton")
	mainToggleBtn.Size = UDim2.new(1, 0, 0, 45)
	mainToggleBtn.BackgroundColor3 = colorGreenActive
	mainToggleBtn.Text = "START AUTOFARM [F6]"
	mainToggleBtn.TextColor3 = colorTextWhite
	mainToggleBtn.TextSize = 13
	mainToggleBtn.Font = Enum.Font.FredokaOne
	mainToggleBtn.LayoutOrder = 1
	
	local toggleCornerStatus = Instance.new("UICorner")
	toggleCornerStatus.CornerRadius = UDim.new(0, 10)
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
	mainToggleBtn.Parent = pageStatus

	mainToggleBtn.MouseEnter:Connect(function()
		animateColor(mainToggleBtn, "BackgroundColor3", CONFIG.AutoFarm and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(40, 220, 110))
	end)
	mainToggleBtn.MouseLeave:Connect(function()
		animateColor(mainToggleBtn, "BackgroundColor3", CONFIG.AutoFarm and colorRedWarning or colorGreenActive)
	end)

	mainToggleBtn.MouseButton1Click:Connect(function()
		CONFIG.AutoFarm = not CONFIG.AutoFarm
		if CONFIG.AutoFarm then
			mainToggleBtn.Text = "STOP AUTOFARM [F6]"
			mainToggleBtn.BackgroundColor3 = colorRedWarning
		else
			stopFarm()
			mainToggleBtn.Text = "START AUTOFARM [F6]"
			mainToggleBtn.BackgroundColor3 = colorGreenActive
		end
	end)

	-- Stats Card
	local statusStatsFrame = Instance.new("Frame")
	statusStatsFrame.Size = UDim2.new(1, 0, 0, 110)
	statusStatsFrame.BackgroundColor3 = colorSlateSidebar
	statusStatsFrame.BorderSizePixel = 0
	statusStatsFrame.LayoutOrder = 2
	
	local statusStatsCorner = Instance.new("UICorner")
	statusStatsCorner.CornerRadius = UDim.new(0, 10)
	statusStatsCorner.Parent = statusStatsFrame

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 2
	cardStroke.Color = colorBorderDark
	cardStroke.Parent = statusStatsFrame

	local statusStatsLabel = Instance.new("TextLabel")
	statusStatsLabel.Size = UDim2.new(1, -20, 1, -20)
	statusStatsLabel.Position = UDim2.new(0, 10, 0, 10)
	statusStatsLabel.BackgroundTransparency = 1
	statusStatsLabel.Text = "Kills : 0\nRetries : 0\nSession Time : 00:00\nLoots : 0 | Sold : 0"
	statusStatsLabel.TextColor3 = colorTextWhite
	statusStatsLabel.TextSize = 12
	statusStatsLabel.LineHeight = 1.35
	statusStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusStatsLabel.Font = Enum.Font.FredokaOne
	
	local statsStroke = Instance.new("UIStroke")
	statsStroke.Thickness = 1
	statsStroke.Color = Color3.fromRGB(0, 0, 0)
	statsStroke.Parent = statusStatsLabel
	statusStatsLabel.Parent = statusStatsFrame
	statusStatsFrame.Parent = pageStatus


	-- 2. COMBAT TAB (ALL AUTOMATIONS TO ATTACK, GEAR, SKILLS, HEALS)
	createSectionHeader(pageCombat, "COMBAT AUTOMATIONS", 1)
	createToggleRow(pageCombat, "Auto Attack Monsters", "rbxassetid://6035043132", "AutoAttack", 2)
	createToggleRow(pageCombat, "Auto Equip Gear", "rbxassetid://6035043132", "AutoEquip", 3)
	createToggleRow(pageCombat, "Auto Cast Spells", "rbxassetid://6034287517", "AutoSkills", 4)
	createToggleRow(pageCombat, "Auto Health Healing", "rbxassetid://6034287517", "AutoHeal", 5)

	createSectionHeader(pageCombat, "GEAR SELECTION", 6)
	createDropdownRow(pageCombat, "Equip Mode :", "rbxassetid://6031289116", CONFIG.EquipMode, {"Both", "Weapon Only", "Element Only", "None"}, 7, function(newVal)
		CONFIG.EquipMode = newVal
	end)

	local toolsList = getAvailableTools()
	createDropdownRow(pageCombat, "Main Weapon :", "rbxassetid://6035043132", CONFIG.SelectedWeapon, toolsList, 8, function(newVal)
		CONFIG.SelectedWeapon = newVal
	end)

	createDropdownRow(pageCombat, "Magic Element :", "rbxassetid://6034287517", CONFIG.SelectedElement, toolsList, 9, function(newVal)
		CONFIG.SelectedElement = newVal
	end)

	createSectionHeader(pageCombat, "ATTACK PARAMETERS", 10)
	createDropdownRow(pageCombat, "Attack Mode :", "rbxassetid://6035043132", CONFIG.AttackMode, {"Sword & Skills", "Sword Only", "Skills Only"}, 11, function(newVal)
		CONFIG.AttackMode = newVal
	end)

	createInputRow(pageCombat, "Attack Delay Min (s) :", "rbxassetid://6031768426", CONFIG.SwingDelayMin, 12, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.01 and val <= 2 then CONFIG.SwingDelayMin = val else box.Text = tostring(CONFIG.SwingDelayMin) end
	end)

	createInputRow(pageCombat, "Attack Delay Max (s) :", "rbxassetid://6031768426", CONFIG.SwingDelayMax, 13, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.01 and val <= 2 then CONFIG.SwingDelayMax = val else box.Text = tostring(CONFIG.SwingDelayMax) end
	end)

	createInputRow(pageCombat, "Attack Range (studs) :", "rbxassetid://6034855071", CONFIG.MaxAttackDistance, 14, function(box, text)
		local val = tonumber(text)
		if val and val >= 1 and val <= 50 then CONFIG.MaxAttackDistance = val else box.Text = tostring(CONFIG.MaxAttackDistance) end
	end)

	createSectionHeader(pageCombat, "ACTIVE SPELL SKILLS", 15)
	
	local function createSkillsRowCombat(parent, layoutOrder)
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
		lbl.Text = "Active Slots :"
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		for slot = 1, 4 do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 42, 0, 26)
			btn.Position = UDim2.new(0.4 + (slot - 1) * 0.15, 0, 0.5, -13)
			
			local isActivated = table.find(CONFIG.SelectedSkills, slot) ~= nil
			btn.BackgroundColor3 = isActivated and colorBlueSelect or colorSlateSidebar
			btn.Text = "Slot " .. slot
			btn.TextColor3 = colorTextWhite
			btn.TextSize = 10
			btn.Font = Enum.Font.FredokaOne
			
			local cornerS = Instance.new("UICorner")
			cornerS.CornerRadius = UDim.new(0, 6)
			cornerS.Parent = btn

			local strokeS = Instance.new("UIStroke")
			strokeS.Thickness = 2
			strokeS.Color = colorBorderDark
			strokeS.Parent = btn

			btn.MouseButton1Click:Connect(function()
				local idx = table.find(CONFIG.SelectedSkills, slot)
				if idx then
					table.remove(CONFIG.SelectedSkills, idx)
					animateColor(btn, "BackgroundColor3", colorSlateSidebar)
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
	createSkillsRowCombat(pageCombat, 16)

	createInputRow(pageCombat, "Spell Cast Delay (s) :", "rbxassetid://6031768426", CONFIG.SkillDelay, 17, function(box, text)
		local val = tonumber(text)
		if val and val >= 0 and val <= 10 then CONFIG.SkillDelay = val else box.Text = tostring(CONFIG.SkillDelay) end
	end)


	-- 3. MOVEMENT TAB
	createSectionHeader(pageTP, "MOVEMENT CONTROLS", 1)
	createDropdownRow(pageTP, "TP Position :", "rbxassetid://6034855071", CONFIG.TP_Position, {"Top", "Bottom", "Behind", "Front", "Left", "Right"}, 2, function(newVal)
		CONFIG.TP_Position = newVal
	end)

	createSliderRow(pageTP, "Relative Distance :", "rbxassetid://6034855071", CONFIG.TP_Distance, 0, 25, 3, function(newVal)
		CONFIG.TP_Distance = newVal
	end)

	createInputRow(pageTP, "Manual Offset (X,Y,Z) :", "rbxassetid://6034855071", CONFIG.TP_Offset_X .. "," .. CONFIG.TP_Offset_Y .. "," .. CONFIG.TP_Offset_Z, 4, function(box, text)
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

	createInputRow(pageTP, "Tween Speed (s/s) :", "rbxassetid://6031768426", CONFIG.TweenSpeed, 5, function(box, text)
		local val = tonumber(text)
		if val and val >= 10 and val <= 250 then CONFIG.TweenSpeed = val else box.Text = tostring(CONFIG.TweenSpeed) end
	end)

	createSectionHeader(pageTP, "SAFETY", 6)
	createToggleRow(pageTP, "Randomize Movement", "rbxassetid://6031768426", "RandomizeOffset", 7)
	createInputRow(pageTP, "Random Offset range :", "rbxassetid://6031768426", CONFIG.RandomOffsetRange, 8, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.1 and val <= 10 then CONFIG.RandomOffsetRange = val else box.Text = tostring(CONFIG.RandomOffsetRange) end
	end)

	createToggleRow(pageTP, "Permanent Noclip", "rbxassetid://6034855071", "NoclipPermanent", 9)

	createSectionHeader(pageTP, "PHYSICAL SPEEDS", 10)
	createInputRow(pageTP, "Walk Speed (WS) :", "rbxassetid://6031768426", CONFIG.WalkSpeed, 11, function(box, text)
		local val = tonumber(text)
		if val and val >= 16 and val <= 150 then CONFIG.WalkSpeed = val else box.Text = tostring(CONFIG.WalkSpeed) end
	end)

	createInputRow(pageTP, "Jump Power (JP) :", "rbxassetid://6031768426", CONFIG.JumpPower, 12, function(box, text)
		local val = tonumber(text)
		if val and val >= 50 and val <= 250 then CONFIG.JumpPower = val else box.Text = tostring(CONFIG.JumpPower) end
	end)


	-- 4. DUNGEON TAB (LOBBY SETTINGS & AUTO RETRY & HEAL THRESHOLD & AUTO COLLECT DROPS)
	createSectionHeader(pageDungeon, "LOBBY SETTINGS", 1)
	createDropdownRow(pageDungeon, "Dungeon Name :", "rbxassetid://6034287517", CONFIG.DungeonName, DUNGEONS_LIST, 2, function(newVal)
		CONFIG.DungeonName = newVal
	end)

	createDropdownRow(pageDungeon, "Difficulty :", "rbxassetid://6034287517", CONFIG.Difficulty, DIFFICULTIES_LIST, 3, function(newVal)
		CONFIG.Difficulty = newVal
	end)

	createToggleRow(pageDungeon, "Auto Join Lobby", "rbxassetid://6034855071", "AutoJoinDungeon", 4)
	createToggleRow(pageDungeon, "Auto Retry Dungeon", "rbxassetid://6031768426", "AutoRetry", 5)
	
	createInputRow(pageDungeon, "Retry Delay (s) :", "rbxassetid://6031768426", CONFIG.RetryDelay, 6, function(box, text)
		local val = tonumber(text)
		if val and val >= 0 and val <= 15 then CONFIG.RetryDelay = val else box.Text = tostring(CONFIG.RetryDelay) end
	end)

	createSectionHeader(pageDungeon, "HEALING CONFIG", 7)
	createInputRow(pageDungeon, "Heal Threshold (life %) :", "rbxassetid://6034287517", math.floor(CONFIG.HealThreshold * 100), 8, function(box, text)
		local val = tonumber(text)
		if val and val >= 5 and val <= 100 then CONFIG.HealThreshold = val / 100 else box.Text = tostring(math.floor(CONFIG.HealThreshold * 100)) end
	end)

	createSectionHeader(pageDungeon, "LOOT COLLECT", 9)
	createToggleRow(pageDungeon, "Auto Collect Drops", "rbxassetid://6034287523", "AutoCollect", 10) -- Moved here!


	-- 5. SYSTEM TAB (AUTO SELL & NIGHT MODE)
	createSectionHeader(pageSystem, "INVENTORY SELL", 1)
	createToggleRow(pageSystem, "Auto Sell Items", "rbxassetid://6034287514", "AutoSell", 2)
	createToggleRow(pageSystem, "Sell Common items", "rbxassetid://6034287514", "SellCommon", 3)
	createToggleRow(pageSystem, "Sell Uncommon items", "rbxassetid://6034287514", "SellUncommon", 4)
	createToggleRow(pageSystem, "Sell Rare items", "rbxassetid://6034287514", "SellRare", 5)

	createSectionHeader(pageSystem, "SYSTEM OPTIMIZATION", 6)
	
	-- 3D Rendering (Clay style)
	local optiFrame = Instance.new("Frame")
	optiFrame.Size = UDim2.new(1, 0, 0, 34)
	optiFrame.BackgroundTransparency = 1
	optiFrame.LayoutOrder = 7

	local optiBtn = Instance.new("TextButton")
	optiBtn.Size = UDim2.new(0, 18, 0, 18)
	optiBtn.Position = UDim2.new(0, 4, 0.5, -9)
	optiBtn.BackgroundColor3 = CONFIG.Disable3DRendering and colorBlueSelect or colorSlateSidebar
	optiBtn.Text = CONFIG.Disable3DRendering and "✓" or ""
	optiBtn.TextColor3 = colorTextWhite
	optiBtn.TextSize = 10
	optiBtn.Font = Enum.Font.FredokaOne
	
	local optiCorner = Instance.new("UICorner")
	optiCorner.CornerRadius = UDim.new(0, 5)
	optiCorner.Parent = optiBtn

	local optiStroke = Instance.new("UIStroke")
	optiStroke.Thickness = 2
	optiStroke.Color = colorBorderDark
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
	optiLbl.Text = "Night Mode (Disable 3D Rendering)"
	optiLbl.TextColor3 = colorTextWhite
	optiLbl.TextSize = 11
	optiLbl.TextXAlignment = Enum.TextXAlignment.Left
	optiLbl.Font = Enum.Font.GothamBold
	
	local optiLblStroke = Instance.new("UIStroke")
	optiLblStroke.Thickness = 1
	optiLblStroke.Color = Color3.fromRGB(0, 0, 0)
	optiLblStroke.Parent = optiLbl
	optiLbl.Parent = optiFrame

	optiBtn.MouseButton1Click:Connect(function()
		CONFIG.Disable3DRendering = not CONFIG.Disable3DRendering
		animateColor(optiBtn, "BackgroundColor3", CONFIG.Disable3DRendering and colorBlueSelect or colorSlateSidebar)
		optiBtn.Text = CONFIG.Disable3DRendering and "✓" or ""
		pcall(function()
			RunService:Set3dRenderingEnabled(not CONFIG.Disable3DRendering)
		end)
	end)
	optiFrame.Parent = pageSystem
	
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

	-- Touche F6 pour toggle l'autofarm (mouvement)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.F6 then
			CONFIG.AutoFarm = not CONFIG.AutoFarm
			if CONFIG.AutoFarm then
				mainToggleBtn.Text = "STOP AUTOFARM [F6]"
				mainToggleBtn.BackgroundColor3 = colorRedWarning
			else
				stopFarm()
				mainToggleBtn.Text = "START AUTOFARM [F6]"
				mainToggleBtn.BackgroundColor3 = colorGreenActive
			end
		end
	end)

	-- Démarrage du thread de fond permanent pour le combat et les fonctions
	runBackgroundLoop()

	print("GUI ULTIME V18 CHARGEE !")
end

-- ============================================================
-- 12. LANCEMENT
-- ============================================================

task.wait(0.5)
createUltimateGUI()
