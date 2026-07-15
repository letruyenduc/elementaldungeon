-- ======================================================
-- AUTOFARM ULTIME – VERSION GUI V19 (DECOUPLED SKILLS)
-- Style officiel "Dungeon Creator" - Compétences Épée vs Élément Découplées
-- ======================================================

if getgenv().ElementalFarmRunning then
	getgenv().ElementalFarmRunning = false
	task.wait(0.5)
end
getgenv().ElementalFarmRunning = true

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
local VirtualInputManager = game:GetService("VirtualInputManager")

-- 2. DYNAMIC KNIT SERVICES SCANNER
local function getKnitServicesFolder()
	local found = ReplicatedStorage:FindFirstChild("Services", true)
	if found then return found end
	
	local knit = ReplicatedStorage:FindFirstChild("Knit", true)
	if knit then
		local services = knit:FindFirstChild("Services")
		if services then return services end
	end
	
	return ReplicatedStorage:FindFirstChild("ReplicatedStorage") 
		and ReplicatedStorage.ReplicatedStorage:FindFirstChild("Packages")
		and ReplicatedStorage.ReplicatedStorage.Packages:FindFirstChild("Knit")
		and ReplicatedStorage.ReplicatedStorage.Packages.Knit:FindFirstChild("Services")
end

local Services = getKnitServicesFolder()
if not Services then
	print("Knit Services folder not found!")
	return
end

local WeaponService = Services:FindFirstChild("WeaponService")
local AttackService = Services:FindFirstChild("AttackService")
local DungeonService = Services:FindFirstChild("DungeonService")
local PartyService = Services:FindFirstChild("PartyService")
local InventoryService = Services:FindFirstChild("InventoryService")
local DropsService = Services:FindFirstChild("DropsService")
local HealingService = Services:FindFirstChild("HealingService")
local AFKService = Services:FindFirstChild("AFKService")

-- 4. REMOTES
local UseSword = WeaponService and WeaponService.RF and WeaponService.RF:FindFirstChild("UseSword")
local UseWeapon = WeaponService and WeaponService.RF and WeaponService.RF:FindFirstChild("UseWeapon")
local UseAbility = AttackService and AttackService.RF and AttackService.RF:FindFirstChild("UseAbility")
local SwordActivated = AttackService and AttackService.RE and AttackService.RE:FindFirstChild("SwordActivated")
local StartDungeon = DungeonService.RF and DungeonService.RF:FindFirstChild("StartDungeon")
local StartParty = PartyService and PartyService.RF and PartyService.RF:FindFirstChild("StartParty")
local VoteOn = PartyService and PartyService.RF and PartyService.RF:FindFirstChild("VoteOn")
local CollectDrop = DropsService and DropsService.RF and DropsService.RF:FindFirstChild("CollectDrop")
local UseHeal = HealingService and HealingService.RF and HealingService.RF:FindFirstChild("UseHeal")
local Sell = InventoryService and InventoryService.RF and InventoryService.RF:FindFirstChild("Sell")

if not UseSword then
	print("Critical Remotes not found (Weapon required)!")
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
		list = { "Beginners", "Jungle", "Underwater", "Fire", "Cloud", "SnowCastle", "InfiniteTime" }
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
					-- Scan dynamique des répertoires CustomDifficulties sans require()
					local customFolder = child:FindFirstChild("CustomDifficulties")
					if customFolder then
						for _, diffFile in ipairs(customFolder:GetChildren()) do
							if not table.find(list, diffFile.Name) then
								table.insert(list, diffFile.Name)
							end
						end
					end
				end
			end
		end
	end)
	if #list == 0 then
		list = { "Easy", "Medium", "Hard", "Hell", "Nightmare", "Mythic", "Hardcore", "Timelost", "Infinite" }
	else
		-- Insérer les difficultés standard indispensables si non scannées
		for _, std in ipairs({"Easy", "Medium", "Hard", "Hell", "Nightmare", "Mythic", "Hardcore", "Infinite"}) do
			if not table.find(list, std) then
				table.insert(list, std)
			end
		end
	end
	table.sort(list)
	return list
end

local function scanDungeonDifficulties()
	local map = {}
	local sharedModules = ReplicatedStorage.ReplicatedStorage.SharedModules
	local dungeonsFolder = sharedModules and sharedModules:FindFirstChild("Dungeons")
	local dungeonsData = dungeonsFolder and dungeonsFolder:FindFirstChild("DungeonsData")
	
	local dungeonsList = scanDungeons()
	for _, dgName in ipairs(dungeonsList) do
		-- Par défaut, tout donjon possède les difficultés de base
		local diffs = { "Easy", "Medium", "Hard", "Hell", "Nightmare", "Mythic", "Hardcore", "Infinite" }
		
		if dungeonsData then
			local moduleName = dgName .. "Dungeon"
			local child = dungeonsData:FindFirstChild(moduleName)
			if child then
				local customFolder = child:FindFirstChild("CustomDifficulties")
				if customFolder then
					for _, diffFile in ipairs(customFolder:GetChildren()) do
						if not table.find(diffs, diffFile.Name) then
							table.insert(diffs, diffFile.Name)
						end
					end
				end
			end
		end
		table.sort(diffs)
		map[dgName] = diffs
	end
	return map
end

local DUNGEONS_LIST = scanDungeons()
local DIFFICULTIES_LIST = scanDifficulties()
local DUNGEON_DIFFICULTIES = scanDungeonDifficulties()

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
	AutoFarm = false, -- Mouvement de mobs en mobs
	AutoAttack = true,
	AutoHeal = true,
	AutoCollect = true,
	CollectPotions = true,
	CollectLoot = true,
	AutoEquip = true,
	AutoSkillsElement = true, -- Auto cast sorts magiques
	AutoSkillsSword = true,   -- Auto cast sorts d'épées
	AutoSell = false,
	AutoRetry = false,
	AutoJoinDungeon = false,
	HitboxExpander = true,
	HitboxSize = 40,

	-- Équipement intelligent
	EquipMode = "Weapon Only",
	SelectedWeapon = "Auto-Detect",
	SelectedElement = "Auto-Detect",

	-- Combat Settings
	SwingDelay = 0.35,
	AttackMode = "Sword & Skills",
	MaxAttackDistance = 15,
	
	-- Position & TP
	TP_Offset_X = 0,
	TP_Offset_Y = 0,
	TP_Offset_Z = 0,
	TP_Distance = 10,
	TP_Position = "Behind",
	RandomizeOffset = true,
	RandomOffsetRange = 1,
	
	-- Skills Découplés
	SelectedSkillsElement = { 1, 2, 3, 4 },
	SelectedSkillsSword = { 1, 2, 3, 4 },
	SkillDelay = 1.2,

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
	TravelMode = "Tween",
	TweenSpeed = 45,
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
	LogHistory = {},
}

local onLogAdded = nil
local function logMessage(text)
	local timeStr = os.date("%H:%M:%S")
	local formatted = string.format("[%s] %s", timeStr, text)
	table.insert(STATS.LogHistory, formatted)
	if #STATS.LogHistory > 100 then
		table.remove(STATS.LogHistory, 1)
	end
	print(formatted)
	if onLogAdded then
		pcall(onLogAdded)
	end
end

local function scanKnitRemotes()
	logMessage("--- SCANNING COMBAT SERVICES ---")
	pcall(function()
		local replicated = game:GetService("ReplicatedStorage")
		local rFolder = replicated:FindFirstChild("ReplicatedStorage")
		local packages = rFolder and rFolder:FindFirstChild("Packages")
		local knitPkg = packages and packages:FindFirstChild("Knit")
		local knit = knitPkg and knitPkg:FindFirstChild("Services")
			
		if knit then
			for _, service in ipairs(knit:GetChildren()) do
				if service.Name:find("Attack") or service.Name:find("Weapon") or service.Name:find("Skill") or service.Name:find("Ability") then
					logMessage("Service: " .. service.Name)
					local rf = service:FindFirstChild("RF")
					if rf then
						for _, r in ipairs(rf:GetChildren()) do
							logMessage("  -> RF: " .. r.Name)
						end
					end
					local re = service:FindFirstChild("RE")
					if re then
						for _, r in ipairs(re:GetChildren()) do
							logMessage("  -> RE: " .. r.Name)
						end
					end
				end
			end
		else
			logMessage("Knit Services folder not found in ReplicatedStorage.")
		end
	end)
	logMessage("--------------------------------")
end

-- ============================================================
-- 9. FONCTIONS DE L'AUTOFARM
-- ============================================================

local isTweening = false
local monitoredMobs = {}
local activeTarget = nil

local farmPlatform -- forward declaration

local function stopFarm()
	activeTarget = nil
	isTweening = false
	pcall(function()
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
		end
	end)
end

-- Création de la plateforme locale de support (Désactivée en V78)
farmPlatform = Instance.new("Part")
farmPlatform.Name = "FarmPlatform"
farmPlatform.Size = Vector3.new(8, 1, 8)
farmPlatform.Anchored = true
farmPlatform.CanCollide = false
farmPlatform.Transparency = 1
farmPlatform.Parent = nil

local steppedConnection
steppedConnection = RunService.Stepped:Connect(function()
	if not getgenv().ElementalFarmRunning then
		if steppedConnection then
			steppedConnection:Disconnect()
			steppedConnection = nil
		end
		return
	end
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")

	-- Noclip seulement pendant le déplacement (isTweening) ou si activé de manière permanente
	local shouldNoclip = isTweening or CONFIG.NoclipPermanent
	if character then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if shouldNoclip then
					part.CanCollide = false
				else
					-- Réactiver les collisions pour se tenir debout sur la plateforme
					if part.Name == "HumanoidRootPart" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" or part.Name == "Head" then
						part.CanCollide = true
					end
				end
			end
		end
	end

	-- Gérer la stabilisation au sol pour l'autofarm
	if CONFIG.AutoFarm and activeTarget and activeTarget.Parent and hrp then
		local mobPart = activeTarget:FindFirstChild("HumanoidRootPart") or activeTarget:FindFirstChild("PrimaryPart")
		if mobPart then
			local targetPos = getPositionOffset(mobPart)
			
			-- Stabilisation physique par vélocité neutre et verrouillage de CFrame (sans ancrage ni plateforme)
			hrp.Anchored = false
			if not isTweening then
				hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				local lookPos = Vector3.new(mobPart.Position.X, hrp.Position.Y, mobPart.Position.Z)
				-- Micro-fluctuations trigonométriques pour casser la rigidité mathématique
				local jitterX = math.sin(os.clock() * 5) * 0.05
				local jitterZ = math.cos(os.clock() * 5) * 0.05
				local jitterPos = targetPos + Vector3.new(jitterX, 0, jitterZ)
				hrp.CFrame = CFrame.lookAt(jitterPos, lookPos)
			end
			
			if CONFIG.TravelMode == "Teleport" then
				-- Téléportation à la demande si le monstre sort de notre portée d'attaque
				local distToMob = (hrp.Position - mobPart.Position).Magnitude
				if distToMob > (CONFIG.MaxAttackDistance - 2) then
					local lookPos = Vector3.new(mobPart.Position.X, hrp.Position.Y, mobPart.Position.Z)
					local jitterX = math.sin(os.clock() * 5) * 0.05
					local jitterZ = math.cos(os.clock() * 5) * 0.05
					local jitterPos = targetPos + Vector3.new(jitterX, 0, jitterZ)
					hrp.CFrame = CFrame.lookAt(jitterPos, lookPos)
				end
			else
				-- Mode Tween
				if not isTweening and (hrp.Position - targetPos).Magnitude > 6 then
					local lookPos = Vector3.new(mobPart.Position.X, hrp.Position.Y, mobPart.Position.Z)
					local jitterX = math.sin(os.clock() * 5) * 0.05
					local jitterZ = math.cos(os.clock() * 5) * 0.05
					local jitterPos = targetPos + Vector3.new(jitterX, 0, jitterZ)
					hrp.CFrame = CFrame.lookAt(jitterPos, lookPos)
				end
			end
		else
			if hrp then hrp.Anchored = false end
		end
	else
		if hrp then hrp.Anchored = false end
	end
end)

task.spawn(function()
	while getgenv().ElementalFarmRunning do
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

local lastTarget = nil
local savedOffset = Vector3.new(0, 0, 0)

function getPositionOffset(mobPart)
	local mobPos = mobPart.Position
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

	local offset = Vector3.new(CONFIG.TP_Offset_X, CONFIG.TP_Offset_Y, CONFIG.TP_Offset_Z)
	
	if CONFIG.RandomizeOffset then
		if activeTarget ~= lastTarget or not lastTarget then
			lastTarget = activeTarget
			local rRange = CONFIG.RandomOffsetRange or 1
			local rx = math.random(-rRange * 100, rRange * 100) / 100
			local ry = math.random(-rRange * 100, rRange * 100) / 100
			local rz = math.random(-rRange * 100, rRange * 100) / 100
			savedOffset = Vector3.new(rx, ry, rz)
		end
		offset = offset + savedOffset
	else
		savedOffset = Vector3.new(0, 0, 0)
	end

	return mobPos + direction + offset
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
	
	isTweening = true
	task.wait(0.01) -- Laisser le temps à Stepped de désancrer
	
	if CONFIG.TravelMode == "Teleport" then
		local character = LocalPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = CFrame.new(targetPos)
		end
		task.wait(0.02) -- Laisser une frame au moteur Roblox
	else
		tweenToPosition(targetPos)
	end
	
	isTweening = false
end

local function restoreMobHitbox(mob)
	pcall(function()
		local hrp = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("PrimaryPart")
		if hrp and hrp:IsA("BasePart") then
			local origSize = hrp:GetAttribute("OriginalSize")
			local origCollide = hrp:GetAttribute("OriginalCanCollide")
			local origTrans = hrp:GetAttribute("OriginalTransparency")
			if origSize then
				hrp.Size = origSize
				hrp.CanCollide = origCollide
				hrp.Transparency = origTrans
			end
			local box = hrp:FindFirstChild("HitboxVisual")
			if box then
				box:Destroy()
			end
		end
	end)
end

local function expandMobHitbox(mob)
	pcall(function()
		local hrp = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("PrimaryPart")
		if hrp and hrp:IsA("BasePart") then
			if not hrp:GetAttribute("OriginalSize") then
				hrp:SetAttribute("OriginalSize", hrp.Size)
				hrp:SetAttribute("OriginalCanCollide", hrp.CanCollide)
				hrp:SetAttribute("OriginalTransparency", hrp.Transparency)
			end
			local sz = CONFIG.HitboxSize or 30
			hrp.Size = Vector3.new(sz, sz, sz)
			hrp.CanCollide = false
			hrp.Transparency = 0.8
			
			local box = hrp:FindFirstChild("HitboxVisual")
			if not box then
				box = Instance.new("SelectionBox")
				box.Name = "HitboxVisual"
				box.Color3 = Color3.fromRGB(255, 0, 100)
				box.LineThickness = 0.05
				box.Adornee = hrp
				box.Parent = hrp
			end
		end
	end)
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
					if CONFIG.HitboxExpander then
						expandMobHitbox(mob)
					else
						restoreMobHitbox(mob)
					end
				end
			end
		end
	end
	return mobs
end

local currentTarget = nil
function getClosestMob()
	if currentTarget and currentTarget.Parent then
		local humanoid = currentTarget:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 then
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
		local connections = {}
		monitoredMobs[currentTarget] = connections
		local humanoid = currentTarget:FindFirstChild("Humanoid")
		if humanoid then
			connections.died = humanoid.Died:Connect(function()
				STATS.Kills = STATS.Kills + 1
				pcall(function()
					if connections.died then connections.died:Disconnect() end
					if connections.destroying then connections.destroying:Disconnect() end
				end)
				monitoredMobs[currentTarget] = nil
				if activeTarget == currentTarget then activeTarget = nil end
			end)
		end
		connections.destroying = currentTarget.Destroying:Connect(function()
			pcall(function()
				if connections.died then connections.died:Disconnect() end
				if connections.destroying then connections.destroying:Disconnect() end
			end)
			monitoredMobs[currentTarget] = nil
			if activeTarget == currentTarget then activeTarget = nil end
		end)
	end

	return currentTarget
end

function swing(target)
	logMessage("Combat: Swing Weapon")
	pcall(function()
		local character = LocalPlayer.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		
		local camera = Workspace.CurrentCamera
		local safeClickPos = Vector2.new(100, 100) -- Fallback
		if camera then
			local viewportSize = camera.ViewportSize
			safeClickPos = Vector2.new(viewportSize.X * 0.5, viewportSize.Y * 0.5)
		end
		
		-- 1. Simulation VirtualInputManager (Simule l'input matériel Roblox)
		local successVIM = false
		if VirtualInputManager then
			pcall(function()
				VirtualInputManager:SendMouseButtonEvent(safeClickPos.X, safeClickPos.Y, 0, true, game, 1)
				task.wait(0.01)
				VirtualInputManager:SendMouseButtonEvent(safeClickPos.X, safeClickPos.Y, 0, false, game, 1)
				successVIM = true
			end)
		end
		
		-- 2. Activation du Tool (Roblox Engine standard - toujours lancé pour assurer la réplication locale)
		if tool then
			pcall(function() tool:Activate() end)
		end
		
		-- 3. Fallbacks injecteur ou VirtualUser si VirtualInputManager a échoué ou n'est pas présent
		if not successVIM then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:Button1Down(safeClickPos)
				task.wait(0.01)
				VirtualUser:Button1Up(safeClickPos)
			end)
			
			if mouse1click then
				pcall(function()
					if click_mouse or mouseclick then
						local clickFn = click_mouse or mouseclick
						clickFn(safeClickPos.X, safeClickPos.Y)
					else
						mouse1click()
					end
				end)
			end
		end
	end)
end

local lastSkillCastTime = {}
function useSkill(slot, isSwordSkill)
	local now = os.clock()
	local lastCast = lastSkillCastTime[tostring(slot) .. "_" .. tostring(isSwordSkill)] or 0
	local jitter = math.random(-150, 150) / 1000
	local delay = (CONFIG.SkillDelay or 1.2) + jitter
	if delay < 0.1 then delay = 0.1 end
	if (now - lastCast) < delay then
		return
	end
	lastSkillCastTime[tostring(slot) .. "_" .. tostring(isSwordSkill)] = now

	if isSwordSkill then
		local key = nil
		if slot == 1 then
			key = Enum.KeyCode.R
		elseif slot == 2 then
			key = Enum.KeyCode.F
		end
		
		if key and VirtualInputManager then
			logMessage("Sword Skill Cast: Key " .. tostring(key.Name))
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, key, false, game)
				task.wait(0.05)
				VirtualInputManager:SendKeyEvent(false, key, false, game)
			end)
		end
	else
		local key = nil
		if slot == 1 then
			key = Enum.KeyCode.F
		elseif slot == 2 then
			key = Enum.KeyCode.R
		elseif slot == 3 then
			key = Enum.KeyCode.C
		elseif slot == 4 then
			key = Enum.KeyCode.V
		elseif slot == 5 then
			key = Enum.KeyCode.G
		end
		
		if key and VirtualInputManager then
			logMessage("Element Skill Cast: Key " .. tostring(key.Name))
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, key, false, game)
				task.wait(0.05)
				VirtualInputManager:SendKeyEvent(false, key, false, game)
			end)
		end
		
		if UseAbility then
			pcall(function()
				UseAbility:InvokeServer(slot)
			end)
		end
	end
end

-- Map difficulty names for the remote
local DIFFICULTY_MAP = {
	["Easy"] = "Easy",
	["Medium"] = "Normal",
	["Hard"] = "Hard",
	["Hell"] = "Hell",
	["Nightmare"] = "Nightmare",
	["Mythic"] = "Mythic",
	["Hardcore"] = "Hardcore",
	["Timelost"] = "Timelost",
	["Infinite"] = "Infinite"
}

function createDungeon(name, difficulty)
	local remoteDiff = DIFFICULTY_MAP[difficulty] or "Easy"
	logMessage("Dungeon Create: " .. tostring(name) .. " [" .. tostring(remoteDiff) .. "]")
	pcall(function()
		StartDungeon:InvokeServer(name, remoteDiff)
	end)
	task.wait(1)
	logMessage("Dungeon Start: Teleporting Party")
	pcall(function()
		if StartParty then
			StartParty:InvokeServer()
		end
	end)
end

function retry()
	if VoteOn then
		logMessage("Dungeon Vote: Retry")
		pcall(function()
			VoteOn:InvokeServer("Retry")
		end)
	end
end

function collectDrop(drop)
	logMessage("Collect Drop: " .. tostring(drop.Name))
	
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local partsToTouch = {}
		if drop:IsA("BasePart") then
			table.insert(partsToTouch, drop)
		end
		for _, desc in ipairs(drop:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(partsToTouch, desc)
			end
		end
		
		for _, part in ipairs(partsToTouch) do
			if firetouchinterest then
				pcall(function()
					firetouchinterest(hrp, part, 0)
					task.wait(0.005)
					firetouchinterest(hrp, part, 1)
				end)
			end
		end
	end

	if CollectDrop then
		pcall(function()
			CollectDrop:InvokeServer(drop)
		end)
	end
end

local function autoDetectTools()
	local weapon = nil
	local element = nil

	local function scan(container)
		if not container then return end
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") then
				if item.Name == "Tool" then
					element = "Tool"
				else
					weapon = item.Name
				end
			end
		end
	end

	scan(LocalPlayer:FindFirstChild("Backpack"))
	scan(LocalPlayer.Character)

	return weapon, element
end

local lastEquipTime = 0
local lastEquippedTarget = ""

function autoEquipSpecific(toolName, isElement)
	if not CONFIG.AutoEquip then return end
	
	local targetName = toolName
	if toolName == "Auto-Detect" then
		local weapon, element = autoDetectTools()
		targetName = isElement and element or weapon
		if not targetName and not isElement then
			targetName = element
		end
	end

	if not targetName or targetName == "Aucun" or targetName == "" then return end
	
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local equippedTool = character:FindFirstChildOfClass("Tool")
	if equippedTool and equippedTool.Name == targetName then
		lastEquippedTarget = targetName
		return
	end

	if lastEquippedTarget == targetName and (os.clock() - lastEquipTime) < 1.5 then
		return
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		local tool = backpack:FindFirstChild(targetName)
		if tool and tool:IsA("Tool") then
			lastEquipTime = os.clock()
			lastEquippedTarget = targetName
			
			logMessage("Gear: Equipping " .. tostring(targetName))
			pcall(function()
				humanoid:EquipTool(tool)
			end)
			pcall(function()
				tool.Parent = character
			end)
			
			if UseWeapon then
				pcall(function()
					UseWeapon:InvokeServer(tool)
				end)
			end
			task.wait(0.08)
		end
	end
end

function autoCollect()
	if not CONFIG.AutoCollect then return end
	
	local drops = Workspace:FindFirstChild("Drops")
	if not drops and Workspace.CurrentCamera then
		drops = Workspace.CurrentCamera:FindFirstChild("Drops")
	end
	if not drops then return end

	-- Utiliser GetDescendants pour trouver les objets Potion ou Drop
	for _, drop in ipairs(drops:GetDescendants()) do
		if drop:IsA("Model") and (drop.Name == "Potion" or drop.Name == "Drop" or drop.Parent.Name == "Drops" or drop.Parent.Name == "Drop") then
			local name = drop.Name:lower()
			local isPotion = name:find("potion") or name:find("pot")
			local isLoot = not isPotion
			
			local shouldCollect = false
			if isPotion and CONFIG.CollectPotions then
				shouldCollect = true
			elseif isLoot and CONFIG.CollectLoot then
				shouldCollect = true
			end
			
			if shouldCollect then
				collectDrop(drop)
				STATS.LootCollected = STATS.LootCollected + 1
				task.wait(0.02)
			end
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

local function hasDungeonPotions()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end
	
	local function getAmount(gui)
		local pbar = gui and gui:FindFirstChild("PlayerBar")
		local main = pbar and pbar:FindFirstChild("Main")
		local pot = main and main:FindFirstChild("PotionBar")
		local amt = pot and pot:FindFirstChild("Amount")
		return amt and amt.Text
	end
	
	local amtText = getAmount(playerGui:FindFirstChild("Main")) or getAmount(playerGui:FindFirstChild("Mobile") and playerGui.Mobile:FindFirstChild("Main"))
	if amtText then
		if amtText:sub(1, 2) == "0/" or amtText == "0" then
			return false
		end
		return true
	end
	return true -- Par défaut
end

local function runBackgroundLoop()
	task.spawn(function()
		local loopCounter = 0
		local combatCycle = 0
		while getgenv().ElementalFarmRunning do
			loopCounter = loopCounter + 1

			-- Équipement permanent hors combat (si AutoEquip actif)
			if CONFIG.AutoEquip and loopCounter % 10 == 0 then
				pcall(function()
					local mode = CONFIG.EquipMode
					if mode == "Weapon Only" or mode == "Both" then
						autoEquipSpecific(CONFIG.SelectedWeapon, false)
					elseif mode == "Element Only" then
						autoEquipSpecific(CONFIG.SelectedElement, true)
					end
				end)
			end

			-- Auto-heal (soin magique + potion si activé et PV bas)
			if CONFIG.AutoHeal then
				local character = LocalPlayer.Character
				local humanoid = character and character:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health / humanoid.MaxHealth < CONFIG.HealThreshold then
					-- 1. Sort magique de soin
					if UseHeal then
						pcall(function() UseHeal:InvokeServer() end)
					end
					-- 2. Potion de donjon (Simulation touche W sur AZERTY / Z sur QWERTY)
					if hasDungeonPotions() and VirtualInputManager then
						pcall(function()
							VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Z, false, game)
							task.wait(0.05)
							VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Z, false, game)
						end)
					end
					task.wait(0.2)
				end
			end

			-- 1. DEPLACEMENT (AUTOFARM DE MONSTRES EN MONSTRES)
			if CONFIG.AutoFarm then
				local target = getClosestMob()
				if target then
					tweenToMob(target)
				else
					-- Aucun monstre vivant dans la salle : recherche de portail actif
					local mapFolder = Workspace:FindFirstChild("Map")
					if mapFolder then
						local touchDoor = nil
						for _, desc in ipairs(mapFolder:GetDescendants()) do
							if desc:IsA("Model") and desc.Name:lower():find("portal") then
								local door = desc:FindFirstChild("TouchDoor")
								if door and door:IsA("BasePart") then
									touchDoor = door
									break
								end
							end
						end
						
						if touchDoor then
							local character = LocalPlayer.Character
							local hrp = character and character:FindFirstChild("HumanoidRootPart")
							if hrp then
								logMessage("Auto Portal: Transitioning to next room via " .. touchDoor:GetFullName())
								isTweening = true
								task.wait(0.01)
								
								if CONFIG.TravelMode == "Teleport" then
									hrp.Anchored = false
									hrp.CFrame = touchDoor.CFrame
									task.wait(0.1)
								else
									-- Voyage par Tween (légitime et sans kick)
									tweenToPosition(touchDoor.Position)
								end
								
								isTweening = false
							end
						end
					end
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
						local maxDist = CONFIG.MaxAttackDistance
						if CONFIG.AutoFarm then
							maxDist = 40
						elseif CONFIG.HitboxExpander then
							maxDist = (CONFIG.HitboxSize or 30) + 5
						end
						inRange = (hrp.Position - targetPart.Position).Magnitude <= maxDist
					end

					if inRange then
						combatCycle = combatCycle + 1
						local mode = CONFIG.EquipMode
						
						if mode == "Both" then
							-- Alternance des cycles d'équipements pour éviter le blocage Roblox d'un seul tool actif
							if combatCycle % 2 == 1 then
								-- Tour Épée
								autoEquipSpecific(CONFIG.SelectedWeapon, false)
								if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
									swing(target)
								end
								-- Auto cast sorts d'épées pendant le tour de l'épée
								if CONFIG.AutoSkillsSword and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
									for _, slot in ipairs(CONFIG.SelectedSkillsSword) do
										task.spawn(useSkill, slot, true)
									end
								end
							else
								-- Tour Sorts Élémentaires
								autoEquipSpecific(CONFIG.SelectedElement, true)
								if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
									swing(target)
								end
								if CONFIG.AutoSkillsElement and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
									for _, slot in ipairs(CONFIG.SelectedSkillsElement) do
										task.spawn(useSkill, slot, false)
									end
								end
							end
						else
							-- Équipements uniques standards
							if mode == "Weapon Only" then
								autoEquipSpecific(CONFIG.SelectedWeapon, false)
								if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
									swing(target)
								end
								if CONFIG.AutoSkillsSword and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
									for _, slot in ipairs(CONFIG.SelectedSkillsSword) do
										task.spawn(useSkill, slot, true)
									end
								end
							elseif mode == "Element Only" then
								autoEquipSpecific(CONFIG.SelectedElement, true)
								if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
									swing(target)
								end
								if CONFIG.AutoSkillsElement and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
									for _, slot in ipairs(CONFIG.SelectedSkillsElement) do
										task.spawn(useSkill, slot, false)
									end
								end
							else
								-- Mode None : lance les deux selon activation
								if CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Sword Only" then
									swing(target)
								end
								if CONFIG.AutoSkillsSword and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
									for _, slot in ipairs(CONFIG.SelectedSkillsSword) do
										task.spawn(useSkill, slot, true)
									end
								end
								if CONFIG.AutoSkillsElement and (CONFIG.AttackMode == "Sword & Skills" or CONFIG.AttackMode == "Skills Only") then
									for _, slot in ipairs(CONFIG.SelectedSkillsElement) do
										task.spawn(useSkill, slot, false)
									end
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

			-- Relancement de donjon / Vote retry (indépendant de AutoFarm pour autoriser le lancement depuis le Lobby)
			if loopCounter % 12 == 0 then
				local mobs = getAliveMobs()
				if #mobs == 0 then
					activeTarget = nil
					
					-- 1. Vote Retry si configuré
					if CONFIG.AutoRetry then
						retry()
						task.wait(1.5)
					end
					
					-- 2. Création/Rejoindre le donjon si toujours aucun mob
					if CONFIG.AutoJoinDungeon and #getAliveMobs() == 0 then
						task.wait(CONFIG.RetryDelay)
						createDungeon(CONFIG.DungeonName, CONFIG.Difficulty)
						task.wait(2.5)
						STATS.Dungeons = STATS.Dungeons + 1
					end
				end
			end

			local randomSwingDelay = CONFIG.SwingDelay + math.random(-50, 50) / 1000
			if randomSwingDelay < 0.05 then randomSwingDelay = 0.05 end
			task.wait(randomSwingDelay)
		end
	end)
end

-- ============================================================
-- 11. CRÉATION DE L'INTERFACE AU STYLE OFFICIEL DU JEU (V19)
-- ============================================================

local function animateColor(guiObject, property, targetColor, duration)
	pcall(function()
		TweenService:Create(guiObject, TweenInfo.new(duration or 0.2), {[property] = targetColor}):Play()
	end)
end

local function createUltimateGUI()
	-- ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ElementalFarmGUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = CoreGui

	-- Palette de couleurs
	local colorSlateBackground = Color3.fromRGB(36, 50, 67)
	local colorSlateSidebar = Color3.fromRGB(24, 38, 51)
	local colorBorderDark = Color3.fromRGB(15, 22, 30)
	local colorTextWhite = Color3.fromRGB(255, 255, 255)
	local colorTextInactive = Color3.fromRGB(150, 175, 195)
	
	local colorGreenActive = Color3.fromRGB(0, 200, 80)
	local colorRedWarning = Color3.fromRGB(220, 50, 50)
	local colorBlueSelect = Color3.fromRGB(40, 130, 220)

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

	-- Contour 3D
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

	-- Bouton Fermer Windows
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
	closeBtn.Activated:Connect(function()
		CONFIG.AutoFarm = false
		getgenv().ElementalFarmRunning = false
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

	local pageStatus = createTabPage("Status")
	local pageCombat = createTabPage("Combat")
	local pageTP = createTabPage("TP")
	local pageDungeon = createTabPage("Dungeon")
	local pageSystem = createTabPage("System")
	local pageLogs = createTabPage("Logs")

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

		btn.Activated:Connect(function()
			selectTab(name)
		end)

		tabButtons[name] = btn
	end

	createTabButton("Status", "rbxassetid://6031768426", "Status", 1)
	createTabButton("Combat", "rbxassetid://6035043132", "Combat", 2)
	createTabButton("TP", "rbxassetid://6034855071", "Movement", 3)
	createTabButton("Dungeon", "rbxassetid://6034287517", "Dungeon", 4)
	createTabButton("System", "rbxassetid://6031289116", "System", 5)
	createTabButton("Logs", "rbxassetid://6035043132", "Logs", 6)

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

		btn.Activated:Connect(function()
			CONFIG[configKey] = not CONFIG[configKey]
			btn.BackgroundColor3 = CONFIG[configKey] and colorGreenActive or colorSlateSidebar
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

				optBtn.Activated:Connect(function()
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

		btn.Activated:Connect(function()
			if label:find("Weapon") or label:find("Element") then
				local updatedList = getAvailableTools()
				if not table.find(updatedList, "Auto-Detect") then
					table.insert(updatedList, 1, "Auto-Detect")
				end
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

		local controller = {
			Frame = frame
		}

		function controller:SetOptions(newOptions)
			options = newOptions
			rebuildDropdownItems(newOptions)
		end

		function controller:SetValue(value)
			btn.Text = tostring(value) .. "  ▼"
		end

		return controller
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

		track.Parent = frame
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
	-- PAGES CONTENTS
	-- ============================================

	-- 1. STATUS TAB
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

	mainToggleBtn.Activated:Connect(function()
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


	-- 2. COMBAT TAB
	createSectionHeader(pageCombat, "COMBAT AUTOMATIONS", 1)
	createToggleRow(pageCombat, "Auto Attack Monsters", "rbxassetid://6035043132", "AutoAttack", 2)
	createToggleRow(pageCombat, "Auto Equip Gear", "rbxassetid://6035043132", "AutoEquip", 3)
	createToggleRow(pageCombat, "Auto Health Healing", "rbxassetid://6034287517", "AutoHeal", 4)
	createToggleRow(pageCombat, "Hitbox Expander", "rbxassetid://6034855071", "HitboxExpander", 4.5)
	createSliderRow(pageCombat, "Hitbox Size (studs) :", "rbxassetid://6034855071", CONFIG.HitboxSize, 2, 100, 4.6, function(newVal)
		CONFIG.HitboxSize = newVal
		if CONFIG.HitboxExpander then
			for _, mob in ipairs(getAliveMobs()) do
				expandMobHitbox(mob)
			end
		end
	end)

	createSectionHeader(pageCombat, "GEAR SELECTION", 5)
	createDropdownRow(pageCombat, "Equip Mode :", "rbxassetid://6031289116", CONFIG.EquipMode, {"Both", "Weapon Only", "Element Only", "None"}, 6, function(newVal)
		CONFIG.EquipMode = newVal
	end)

	local toolsList = getAvailableTools()
	if not table.find(toolsList, "Auto-Detect") then
		table.insert(toolsList, 1, "Auto-Detect")
	end
	createDropdownRow(pageCombat, "Main Weapon :", "rbxassetid://6035043132", CONFIG.SelectedWeapon, toolsList, 7, function(newVal)
		CONFIG.SelectedWeapon = newVal
	end)

	createDropdownRow(pageCombat, "Magic Element :", "rbxassetid://6034287517", CONFIG.SelectedElement, toolsList, 8, function(newVal)
		CONFIG.SelectedElement = newVal
	end)

	createSectionHeader(pageCombat, "ATTACK PARAMETERS", 9)
	createDropdownRow(pageCombat, "Attack Mode :", "rbxassetid://6035043132", CONFIG.AttackMode, {"Sword & Skills", "Sword Only", "Skills Only"}, 10, function(newVal)
		CONFIG.AttackMode = newVal
	end)

	createSliderRow(pageCombat, "Attack Delay (seconds) :", "rbxassetid://6031768426", CONFIG.SwingDelay, 0.01, 1.0, 11, function(newVal)
		CONFIG.SwingDelay = newVal
	end)

	createInputRow(pageCombat, "Attack Range (studs) :", "rbxassetid://6034855071", CONFIG.MaxAttackDistance, 13, function(box, text)
		local val = tonumber(text)
		if val and val >= 1 and val <= 50 then CONFIG.MaxAttackDistance = val else box.Text = tostring(CONFIG.MaxAttackDistance) end
	end)

	-- MAGIC SPELLS (ELEMENT)
	createSectionHeader(pageCombat, "MAGIC ELEMENT SPELLS", 14)
	createToggleRow(pageCombat, "Auto Cast Element Spells", "rbxassetid://6034287517", "AutoSkillsElement", 15)
	
	local function createSkillsRowElement(parent, layoutOrder)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 36)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.32, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Magic Slots :"
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		local keyNamesElement = {"F", "R", "C", "V", "G"}
		for slot = 1, 5 do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 36, 0, 26)
			btn.Position = UDim2.new(0.38 + (slot - 1) * 0.12, 0, 0.5, -13)
			
			local isActivated = table.find(CONFIG.SelectedSkillsElement, slot) ~= nil
			btn.BackgroundColor3 = isActivated and colorBlueSelect or colorSlateSidebar
			btn.Text = keyNamesElement[slot] or tostring(slot)
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

			btn.Activated:Connect(function()
				local idx = table.find(CONFIG.SelectedSkillsElement, slot)
				if idx then
					table.remove(CONFIG.SelectedSkillsElement, idx)
					animateColor(btn, "BackgroundColor3", colorSlateSidebar)
				else
					table.insert(CONFIG.SelectedSkillsElement, slot)
					table.sort(CONFIG.SelectedSkillsElement)
					animateColor(btn, "BackgroundColor3", colorBlueSelect)
				end
			end)
			btn.Parent = frame
		end

		frame.Parent = parent
	end
	createSkillsRowElement(pageCombat, 16)

	-- SWORD SKILLS
	createSectionHeader(pageCombat, "SWORD ABILITIES", 17)
	createToggleRow(pageCombat, "Auto Cast Sword Abilities", "rbxassetid://6035043132", "AutoSkillsSword", 18)

	local function createSkillsRowSword(parent, layoutOrder)
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, 0, 0, 36)
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = layoutOrder

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(0.32, 0, 1, 0)
		lbl.Position = UDim2.new(0, 24, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Sword Slots :"
		lbl.TextColor3 = colorTextWhite
		lbl.TextSize = 11
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		
		local lblStroke = Instance.new("UIStroke")
		lblStroke.Thickness = 1
		lblStroke.Color = Color3.fromRGB(0, 0, 0)
		lblStroke.Parent = lbl
		lbl.Parent = frame

		local keyNamesSword = {"R", "F", "Slot 3", "Slot 4"}
		for slot = 1, 4 do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 42, 0, 26)
			btn.Position = UDim2.new(0.4 + (slot - 1) * 0.15, 0, 0.5, -13)
			
			local isActivated = table.find(CONFIG.SelectedSkillsSword, slot) ~= nil
			btn.BackgroundColor3 = isActivated and colorBlueSelect or colorSlateSidebar
			btn.Text = keyNamesSword[slot] or ("Slot " .. slot)
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

			btn.Activated:Connect(function()
				local idx = table.find(CONFIG.SelectedSkillsSword, slot)
				if idx then
					table.remove(CONFIG.SelectedSkillsSword, idx)
					animateColor(btn, "BackgroundColor3", colorSlateSidebar)
				else
					table.insert(CONFIG.SelectedSkillsSword, slot)
					table.sort(CONFIG.SelectedSkillsSword)
					animateColor(btn, "BackgroundColor3", colorBlueSelect)
				end
			end)
			btn.Parent = frame
		end

		frame.Parent = parent
	end
	createSkillsRowSword(pageCombat, 19)

	createInputRow(pageCombat, "Ability Cast Delay (s) :", "rbxassetid://6031768426", CONFIG.SkillDelay, 20, function(box, text)
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

	createDropdownRow(pageTP, "Travel Mode :", "rbxassetid://6034855071", CONFIG.TravelMode, {"Tween", "Teleport"}, 5.5, function(newVal)
		CONFIG.TravelMode = newVal
	end)

	createSectionHeader(pageTP, "SAFETY", 6)
	createToggleRow(pageTP, "Randomize Movement", "rbxassetid://6031768426", "RandomizeOffset", 7)
	createInputRow(pageTP, "Random Offset range :", "rbxassetid://6031768426", CONFIG.RandomOffsetRange, 8, function(box, text)
		local val = tonumber(text)
		if val and val >= 0.1 and val <= 10 then CONFIG.RandomOffsetRange = val else box.Text = tostring(CONFIG.RandomOffsetRange) end
	end)

	createToggleRow(pageTP, "Permanent Noclip", "rbxassetid://6034855071", "NoclipPermanent", 9)

	createSectionHeader(pageTP, "PHYSICAL SPEEDS", 10)
	createSliderRow(pageTP, "Walk Speed (WS) :", "rbxassetid://6031768426", CONFIG.WalkSpeed, 16, 150, 11, function(newVal)
		CONFIG.WalkSpeed = newVal
	end)

	createSliderRow(pageTP, "Jump Power (JP) :", "rbxassetid://6031768426", CONFIG.JumpPower, 50, 250, 12, function(newVal)
		CONFIG.JumpPower = newVal
	end)


	-- 4. DUNGEON TAB
	local dungeonSuccess, dungeonErr = pcall(function()
		createSectionHeader(pageDungeon, "LOBBY SETTINGS", 1)
		local diffDropdown
		createDropdownRow(pageDungeon, "Dungeon Name :", "rbxassetid://6034287517", CONFIG.DungeonName, DUNGEONS_LIST, 2, function(newVal)
			CONFIG.DungeonName = newVal
			if diffDropdown then
				local allowed = DUNGEON_DIFFICULTIES[newVal] or { "Easy", "Medium", "Hard", "Hell" }
				diffDropdown:SetOptions(allowed)
				if not table.find(allowed, CONFIG.Difficulty) then
					CONFIG.Difficulty = allowed[1]
					diffDropdown:SetValue(allowed[1])
				end
			end
		end)

		local initialDiffs = DUNGEON_DIFFICULTIES[CONFIG.DungeonName] or DIFFICULTIES_LIST
		diffDropdown = createDropdownRow(pageDungeon, "Difficulty :", "rbxassetid://6034287517", CONFIG.Difficulty, initialDiffs, 3, function(newVal)
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
		createToggleRow(pageDungeon, "Auto Collect Drops", "rbxassetid://6034287523", "AutoCollect", 10)
		createToggleRow(pageDungeon, "Collect Potions", "rbxassetid://6034287523", "CollectPotions", 11)
		createToggleRow(pageDungeon, "Collect Equip & Materials", "rbxassetid://6034287523", "CollectLoot", 12)
	end)
	if not dungeonSuccess then
		print("DUNGEON TAB ERROR: " .. tostring(dungeonErr))
	end


	-- 5. SYSTEM TAB
	local systemSuccess, systemErr = pcall(function()
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

		optiBtn.Activated:Connect(function()
			CONFIG.Disable3DRendering = not CONFIG.Disable3DRendering
			optiBtn.BackgroundColor3 = CONFIG.Disable3DRendering and colorBlueSelect or colorSlateSidebar
			optiBtn.Text = CONFIG.Disable3DRendering and "✓" or ""
			pcall(function()
				RunService:Set3dRenderingEnabled(not CONFIG.Disable3DRendering)
			end)
		end)
		optiFrame.Parent = pageSystem
	end)
	if not systemSuccess then
		print("SYSTEM TAB ERROR: " .. tostring(systemErr))
	end
	
	-- 6. LOGS TAB
	local logsSuccess, logsErr = pcall(function()
		createSectionHeader(pageLogs, "EXECUTION DIAGNOSTICS", 1)
		
		local copyFrame = Instance.new("Frame")
		copyFrame.Size = UDim2.new(1, 0, 0, 36)
		copyFrame.BackgroundTransparency = 1
		copyFrame.LayoutOrder = 2
		
		local copyBtn = Instance.new("TextButton")
		copyBtn.Size = UDim2.new(1, 0, 1, 0)
		copyBtn.BackgroundColor3 = colorBlueSelect
		copyBtn.Text = "COPY ALL LOGS (1-CLICK)"
		copyBtn.TextColor3 = colorTextWhite
		copyBtn.TextSize = 12
		copyBtn.Font = Enum.Font.FredokaOne
		
		local copyCorner = Instance.new("UICorner")
		copyCorner.CornerRadius = UDim.new(0, 8)
		copyCorner.Parent = copyBtn
		
		local copyStroke = Instance.new("UIStroke")
		copyStroke.Thickness = 2
		copyStroke.Color = colorBorderDark
		copyStroke.Parent = copyBtn
		copyBtn.Parent = copyFrame
		copyFrame.Parent = pageLogs

		createSectionHeader(pageLogs, "LIVE EVENTS CONSOLE", 3)
		
		local consoleFrame = Instance.new("Frame")
		consoleFrame.Size = UDim2.new(1, 0, 0, 220)
		consoleFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
		consoleFrame.BorderSizePixel = 0
		consoleFrame.LayoutOrder = 4
		
		local consoleCorner = Instance.new("UICorner")
		consoleCorner.CornerRadius = UDim.new(0, 8)
		consoleCorner.Parent = consoleFrame
		
		local consoleStroke = Instance.new("UIStroke")
		consoleStroke.Thickness = 2
		consoleStroke.Color = colorBorderDark
		consoleStroke.Parent = consoleFrame
		
		local consoleScroll = Instance.new("ScrollingFrame")
		consoleScroll.Size = UDim2.new(1, -12, 1, -12)
		consoleScroll.Position = UDim2.new(0, 6, 0, 6)
		consoleScroll.BackgroundTransparency = 1
		consoleScroll.ScrollBarThickness = 5
		consoleScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		consoleScroll.Parent = consoleFrame
		
		local logText = Instance.new("TextLabel")
		logText.Size = UDim2.new(1, 0, 1, 0)
		logText.BackgroundTransparency = 1
		logText.TextXAlignment = Enum.TextXAlignment.Left
		logText.TextYAlignment = Enum.TextYAlignment.Top
		logText.TextColor3 = Color3.fromRGB(220, 220, 240)
		logText.TextSize = 10
		logText.Font = Enum.Font.Code
		logText.TextWrapped = true
		logText.Text = "Logs console initialized.\n"
		logText.Parent = consoleScroll
		
		consoleFrame.Parent = pageLogs
		
		local function refreshLogUI()
			local content = table.concat(STATS.LogHistory, "\n")
			logText.Text = content
			local lines = #STATS.LogHistory
			consoleScroll.CanvasSize = UDim2.new(0, 0, 0, lines * 13 + 20)
			pcall(function()
				consoleScroll.CanvasPosition = Vector2.new(0, math.max(0, consoleScroll.CanvasSize.Y.Offset - consoleScroll.AbsoluteSize.Y))
			end)
		end
		
		onLogAdded = refreshLogUI
		
		copyBtn.Activated:Connect(function()
			local content = table.concat(STATS.LogHistory, "\n")
			
			-- Annexer un scan Knit en direct pour diagnostic
			local knitReport = "\n\n=== DIRECT KNIT SERVICES SCAN ===\n"
			pcall(function()
				local replicated = game:GetService("ReplicatedStorage")
				local rFolder = replicated:FindFirstChild("ReplicatedStorage")
				local packages = rFolder and rFolder:FindFirstChild("Packages")
				local knitPkg = packages and packages:FindFirstChild("Knit")
				local knit = knitPkg and knitPkg:FindFirstChild("Services")
				if knit then
					for _, s in ipairs(knit:GetChildren()) do
						knitReport = knitReport .. "Service: " .. s.Name .. "\n"
						local rf = s:FindFirstChild("RF")
						if rf then
							for _, r in ipairs(rf:GetChildren()) do
								knitReport = knitReport .. "  -> RF: " .. r.Name .. "\n"
							end
						end
						local re = s:FindFirstChild("RE")
						if re then
							for _, r in ipairs(re:GetChildren()) do
								knitReport = knitReport .. "  -> RE: " .. r.Name .. "\n"
							end
						end
					end
				else
					knitReport = knitReport .. "Knit Services folder not found in ReplicatedStorage.\n"
				end
			end)
			knitReport = knitReport .. "================================="
			content = content .. knitReport
			
			local copyFn = setclipboard or toclipboard or (Clipboard and Clipboard.set)
			if copyFn then
				pcall(function() copyFn(content) end)
				copyBtn.Text = "COPIED TO CLIPBOARD!"
				copyBtn.BackgroundColor3 = colorGreenActive
				task.wait(1.5)
				copyBtn.Text = "COPY ALL LOGS (1-CLICK)"
				copyBtn.BackgroundColor3 = colorBlueSelect
			else
				copyBtn.Text = "COPY ERROR (NOT SUPPORTED)"
				task.wait(1.5)
				copyBtn.Text = "COPY ALL LOGS (1-CLICK)"
			end
		end)
		
		refreshLogUI()
	end)
	if not logsSuccess then
		print("LOGS TAB ERROR: " .. tostring(logsErr))
	end
	
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

	-- Touche F6 pour toggle l'autofarm
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

	scanKnitRemotes()
	runBackgroundLoop()

	print("GUI ULTIME V83 CHARGEE !")
end

-- ============================================================
-- 12. LANCEMENT
-- ============================================================

task.wait(0.5)
createUltimateGUI()

-- Hook d'auto-rechargement sur changement de serveur (queue_on_teleport)
local queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
if queue_on_teleport and LocalPlayer then
	pcall(function()
		LocalPlayer.OnTeleport:Connect(function(State)
			if State == Enum.TeleportState.Started then
				queue_on_teleport([[
					repeat task.wait(1) until game:IsLoaded()
					loadstring(game:HttpGet("https://raw.githubusercontent.com/letruyenduc/elementaldungeon/main/elemental_dungeon.lua?t=" .. os.time()))()
				]])
			end
		end)
	end)
end
