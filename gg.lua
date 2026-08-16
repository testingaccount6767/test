local fx = {version = "V8.7", author = "fx_scripts"}
local TouchLine = {}

local PREMIUM_GOLD = Color3.fromRGB(255, 215, 0)
local PREMIUM_LOADER = 'loadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/344b087c94b3953506a2eb78d852da68a2c5d2c11646d40723ffca8982cefe15/download"))()'

local AIR_SURFACE_COLOR = Color3.fromRGB(180, 80, 255)
local AIR_ZONE_COLOR = Color3.fromRGB(200, 100, 255)
local AIR_SECTION_COLOR = Color3.fromRGB(190, 90, 255)

local UPDATE_LOG = {
  version = "V8.7",
  items = {
   "fixed double touch",
 
  }
}

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function safeParentGui()
	local ok, gui = pcall(function() return gethui and gethui() or CoreGui end)
	if ok and gui then return gui end
	return Players.LocalPlayer:WaitForChild("PlayerGui", 5) or CoreGui
end

local RootGuiParent = safeParentGui()
local lastDiscordShown = 0
local discordNotifActive = false
local errorShown = false

local SCRIPT_KILLED = false
local _cleanupConnections = {}

local function trackConn(conn)
	if conn then table.insert(_cleanupConnections, conn) end
	return conn
end

local function destroyTrackedParts()
	pcall(function()
		local names = {
			Debug = true, GKDebug = true,
			TL_AirPlatform = true, TL_AirHelperZone = true,
			TL_CurveTrail = true, TL_CurveSparks = true, TL_CurveHL = true,
			TouchLinePreview = true
		}
		for _, v in ipairs(Workspace.Terrain:GetChildren()) do
			if names[v.Name] then v:Destroy() end
		end
	end)
end

local function destroyExistingUI()
	local guiNames = {
		"TouchLine_UI", "TouchLine_Notifications", "TouchLine_SideBar",
		"TouchLine_MobileControls", "TouchLine_FeatureButtons", "TouchLine_ErrorDisplay",
	}
	for _, n in ipairs(guiNames) do
		local existing = RootGuiParent:FindFirstChild(n)
		if existing then existing:Destroy() end
	end
end

pcall(function()
	local env = (getgenv and getgenv()) or _G
	if env.TouchLine_Cleanup then
		pcall(env.TouchLine_Cleanup)
		env.TouchLine_Cleanup = nil
	end
end)

destroyExistingUI()
destroyTrackedParts()

local function getRandomColor()
	local colors = {
		Color3.fromRGB(70, 150, 255),
		Color3.fromRGB(100, 200, 100),
		Color3.fromRGB(255, 150, 80),
		Color3.fromRGB(200, 100, 255),
		Color3.fromRGB(100, 200, 200),
		Color3.fromRGB(255, 100, 150),
		Color3.fromRGB(150, 200, 100),
		PREMIUM_GOLD,
	}
	return colors[math.random(1, #colors)]
end

local ACCENT_COLOR = getRandomColor()
local activeNotifications = {}

local THEMES = {
    {name = "Cyan",     accent = Color3.fromRGB(0, 210, 255),   bg = Color3.fromRGB(10, 12, 20)},
    {name = "Violet",   accent = Color3.fromRGB(170, 90, 255),  bg = Color3.fromRGB(14, 10, 22)},
    {name = "Emerald",  accent = Color3.fromRGB(60, 235, 150),  bg = Color3.fromRGB(9, 18, 15)},
    {name = "Crimson",  accent = Color3.fromRGB(255, 75, 95),   bg = Color3.fromRGB(20, 10, 13)},
    {name = "Gold",     accent = Color3.fromRGB(255, 205, 70),  bg = Color3.fromRGB(20, 17, 8)},
    {name = "Ice",      accent = Color3.fromRGB(150, 210, 255), bg = Color3.fromRGB(11, 15, 22)},
    {name = "Sunset",   accent = Color3.fromRGB(255, 130, 60),  bg = Color3.fromRGB(21, 13, 9)},
    {name = "Mono",     accent = Color3.fromRGB(225, 228, 240), bg = Color3.fromRGB(13, 13, 15)},
}

local ThemeState = {name = "Custom", bg = Color3.fromRGB(12, 13, 22), rainbow = false}

local function themeNames()
    local out = {}
    for _, t in ipairs(THEMES) do table.insert(out, t.name) end
    table.insert(out, "Rainbow")
    return out
end

local function nearColor(a, b)
    if typeof(a) ~= "Color3" or typeof(b) ~= "Color3" then return false end
    return math.abs(a.R - b.R) < 0.02 and math.abs(a.G - b.G) < 0.02 and math.abs(a.B - b.B) < 0.02
end

local ThemeRoots = {}

local function registerThemeRoot(gui)
    if gui then table.insert(ThemeRoots, gui) end
    return gui
end

local function retint(oldAccent, newAccent, oldBg, newBg)
    for _, root in ipairs(ThemeRoots) do
        if root and root.Parent then
            local list = root:GetDescendants()
            table.insert(list, root)
            for _, d in ipairs(list) do
                if d:IsA("UIStroke") then
                    if nearColor(d.Color, oldAccent) then d.Color = newAccent end
                elseif d:IsA("Frame") or d:IsA("TextButton") or d:IsA("TextLabel") or d:IsA("ScrollingFrame") then
                    if nearColor(d.BackgroundColor3, oldAccent) then d.BackgroundColor3 = newAccent end
                    if oldBg and newBg and nearColor(d.BackgroundColor3, oldBg) then d.BackgroundColor3 = newBg end
                    if (d:IsA("TextLabel") or d:IsA("TextButton")) and nearColor(d.TextColor3, oldAccent) then
                        d.TextColor3 = newAccent
                    end
                end
            end
        end
    end
end

local function applyTheme(name)
    if name == "Rainbow" then
        ThemeState.rainbow = true
        ThemeState.name = "Rainbow"
        return
    end
    ThemeState.rainbow = false
    for _, t in ipairs(THEMES) do
        if t.name == name then
            local oldAccent, oldBg = ACCENT_COLOR, ThemeState.bg
            ACCENT_COLOR = t.accent
            ThemeState.name = t.name
            ThemeState.bg = t.bg
            retint(oldAccent, t.accent, oldBg, t.bg)
            return
        end
    end
end

task.spawn(function()
    local hue = 0
    while true do
        task.wait(0.06)
        if ThemeState.rainbow then
            hue = (hue + 0.008) % 1
            local newAccent = Color3.fromHSV(hue, 0.75, 1)
            local old = ACCENT_COLOR
            ACCENT_COLOR = newAccent
            pcall(retint, old, newAccent, nil, nil)
        end
    end
end)

local function create(instanceType)
	return function(props)
		local inst = Instance.new(instanceType)
		for p, v in pairs(props or {}) do
			pcall(function() inst[p] = v end)
		end
		return inst
	end
end

local function SafeFindPath(root, path)
	local obj = root
	for _, n in ipairs(path) do
		local s, r = pcall(function() return obj:WaitForChild(n, 1) end)
		if not s or not r then return nil end
		obj = r
	end
	return obj
end

local Remotes = {
	TouchKick = SafeFindPath(ReplicatedStorage, {"Remotes", "Game", "Touch", "Kick"}),
	TouchInvoke = SafeFindPath(ReplicatedStorage, {"Remotes", "Game", "Touch"}),
	Ragdoll = SafeFindPath(ReplicatedStorage, {"Remotes", "Game", "Ragdoll"})
}

local function refreshTouchRemotes()
	pcall(function()
		local r = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 3)
		local g = r and (r:FindFirstChild("Game") or r:WaitForChild("Game", 3))
		local touch = g and (g:FindFirstChild("Touch") or g:WaitForChild("Touch", 3))
		local kick = touch and (touch:FindFirstChild("Kick") or touch:WaitForChild("Kick", 3))
		if touch then Remotes.TouchInvoke = touch end
		if kick then Remotes.TouchKick = kick end
	end)
	return Remotes.TouchKick, Remotes.TouchInvoke
end

local LocalPlayer = Players.LocalPlayer
local Character, HumanoidRootPart, Humanoid
local Camera = Workspace.CurrentCamera

local function UpdateCharacter(c)
	Character = c or LocalPlayer.Character
	if Character then
		HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 5)
		Humanoid = Character:WaitForChild("Humanoid", 5)
	end
end

UpdateCharacter(LocalPlayer.Character)
trackConn(LocalPlayer.CharacterAdded:Connect(UpdateCharacter))

local function getMoveDir()
	if Humanoid and HumanoidRootPart then
		return HumanoidRootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
	end
	return Vector3.zero
end

local function buildPayload(ball, action, power, curves, cframe)
	return {
		ball,
		action or "Shoot",
		power or 1,
		curves or {Ground = false, Right = false, Left = false},
		cframe or (HumanoidRootPart and HumanoidRootPart.CFrame or CFrame.new()),
		getMoveDir()
	}
end

local GK_HITBOXES = {
	GoalProtection = {
		SafeFindPath(Workspace, {"Stadium", "Fields", "1", "Hitboxes", "Protection", "Away"}),
		SafeFindPath(Workspace, {"Stadium", "Fields", "1", "Hitboxes", "Protection", "Home"}),
		SafeFindPath(Workspace, {"Stadium", "Fields", "1", "Hitboxes", "Protection"}),
	},
	KeeperSmall = {
		SafeFindPath(Workspace, {"Stadium", "Fields", "1", "Hitboxes", "Keeper", "Small", "Home"}),
		SafeFindPath(Workspace, {"Stadium", "Fields", "1", "Hitboxes", "Keeper", "Small", "Away"}),
		SafeFindPath(Workspace, {"Stadium", "Fields", "1", "Hitboxes", "Keeper", "Small"}),
	}
}

local function isPointInPart(point, part)
	if not part then return false end
	local bp = part
	if not bp:IsA("BasePart") then bp = part:FindFirstChildWhichIsA("BasePart") or part.PrimaryPart end
	if not bp or not bp:IsA("BasePart") then return false end
	local rel = bp.CFrame:PointToObjectSpace(point)
	local s = bp.Size
	return math.abs(rel.X) <= s.X/2 + 0.5 and math.abs(rel.Y) <= s.Y/2 + 0.5 and math.abs(rel.Z) <= s.Z/2 + 0.5
end

local function isBallInGoalProtection(ballPos)
	for _, p in ipairs(GK_HITBOXES.GoalProtection) do
		if isPointInPart(ballPos, p) then return true end
	end
	return false
end

local function isInKeeperBox(pos)
	if not pos then return false end
	for _, p in ipairs(GK_HITBOXES.KeeperSmall) do
		if isPointInPart(pos, p) then return true end
	end
	return false
end

local function GKDebug(size, offset, color)
	if not HumanoidRootPart then return end
	for _, v in pairs(Workspace.Terrain:GetChildren()) do
		if v.Name == "GKDebug" then v:Destroy() end
	end
	local Part = Instance.new("Part")
	Part.Size = size
	Part.CFrame = HumanoidRootPart.CFrame * offset
	Part.CanCollide = false
	Part.Anchored = false
	Part.Massless = true
	Part.Transparency = 0.7
	Part.Color = color or Color3.fromRGB(0,255,255)
	Part.Material = Enum.Material.Neon
	Part.Name = "GKDebug"
	Part.Parent = Workspace.Terrain
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HumanoidRootPart
	weld.Part1 = Part
	weld.Parent = Part
	task.delay(0.5, function() if Part.Parent then Part:Destroy() end end)
end

local function getGoalieCenter()
	local field = SafeFindPath(Workspace, {"Stadium", "Fields", "1"})
	if field and field.PrimaryPart then
		return field.PrimaryPart.Position + Vector3.new(0, 3, 0)
	end
	return HumanoidRootPart and HumanoidRootPart.Position or Vector3.new(0,4,0)
end

local AutoGK = {
	Enabled = false,
	AutoDive = false,
	SaveRadius = 14,
	Cooldown = false,
	CooldownTime = 1.1,
	_lastAction = 0,
	_homePos = nil,
	_patrolPhase = 0,
	_isDiving = false,
}

local function isGoalie()
	local ok, val = pcall(function()
		local v = SafeFindPath(LocalPlayer:FindFirstChild("PlayerGui"), {"Main", "Values", "Goalie"})
		return v and v.Value == true
	end)
	return ok and val
end

local function fireRagdoll()
	if Remotes.Ragdoll then
		pcall(function() Remotes.Ragdoll:FireServer() end)
	end
end

local function taggedTouchKick(payload)
	local ok1, ok2 = false, false
	local kick, touch = refreshTouchRemotes()
	if kick then
		ok1 = pcall(function() kick:FireServer(unpack({payload})) end)
	end
	if touch and touch:IsA("RemoteFunction") then
		ok2 = pcall(function() touch:InvokeServer(unpack({payload})) end)
	end
	return ok1 or ok2
end

function AutoGK:DoSave(ball, isDive)
	if self.Cooldown or self._isDiving then return end
	self.Cooldown = true
	self._isDiving = true
	self._lastAction = tick()

	local hrp = HumanoidRootPart
	if not hrp then 
		self.Cooldown = false; self._isDiving = false; return 
	end

	GKDebug(Vector3.new(4,5.3,2), CFrame.new(0,-0.5,-0.25))
	pcall(function() game:GetService("SoundService").Client.slide:Play() end)

	local dirCF = hrp.CFrame
	if isDive then
		local dx = (ball.Position.X - hrp.Position.X)
		dirCF = hrp.CFrame * (dx > 0 and CFrame.new(1.8,0,0) or CFrame.new(-1.8,0,0))
	end

	local action = isDive and "Dive" or "Save"
	local payload = buildPayload(ball, action, 1.2, {Ground=false, Right=false, Left=false}, dirCF)
	taggedTouchKick(payload)

	task.delay(0.12, fireRagdoll)

	task.delay(0.18, function()
		if ball and ball.Parent and not ball.Anchored and hrp and hrp.Parent then
			local d2 = (ball.Position - hrp.Position).Magnitude
			if d2 < 9 then
				local kickP = buildPayload(ball, "Save", 1, {Ground=false, Right=false, Left=false}, hrp.CFrame)
				taggedTouchKick(kickP)
			end
		end
	end)

	task.delay(self.CooldownTime + 0.6, function()
		self.Cooldown = false
		self._isDiving = false
	end)
end

function AutoGK:ReturnToPosition()
	local hrp = HumanoidRootPart
	if not hrp or not self._homePos then return end
	local target = self._homePos
	pcall(function()
		if Humanoid then Humanoid:MoveTo(target) end
	end)
	task.delay(0.1, function()
		if hrp and hrp.Parent then
			local cur = hrp.Position
			if (target - cur).Magnitude > 3 then
				hrp.CFrame = CFrame.new(target.X, cur.Y, target.Z) * CFrame.Angles(0, hrp.Orientation.Y * math.pi/180, 0)
			end
		end
	end)
end

local function updateGKPatrol(dt)
	local hrp = HumanoidRootPart
	if not hrp then return end
	AutoGK._patrolPhase = (AutoGK._patrolPhase or 0) + (dt or 0.016) * 1.8
	local amp = 4.2
	local base = AutoGK._homePos or hrp.Position
	local side = math.sin(AutoGK._patrolPhase) * amp
	local targetPos = Vector3.new(base.X + side, base.Y, base.Z)
	local cur = hrp.Position
	local moveVec = (targetPos - cur) * 0.6
	if moveVec.Magnitude > 0.1 then
		hrp.CFrame = CFrame.new(cur + moveVec * 0.35) * CFrame.Angles(0, hrp.Orientation.Y * math.pi/180, 0)
	end
end

trackConn(RunService.Heartbeat:Connect(function(dt)
	if SCRIPT_KILLED then return end
	if not (Character and Character.Parent and HumanoidRootPart and HumanoidRootPart.Parent) then return end
	if not AutoGK.Enabled then return end
	if not isGoalie() then return end
	local hrp = HumanoidRootPart
	local myPos = hrp.Position

	if not isInKeeperBox(myPos) then
		local keeper = GK_HITBOXES.KeeperSmall[1] or GK_HITBOXES.KeeperSmall[2]
		if keeper and keeper:IsA("BasePart") then
			local c = keeper.CFrame.Position
			hrp.CFrame = CFrame.new(c.X, myPos.Y + 0.2, c.Z)
		end
		return
	end

	if not AutoGK._homePos or (AutoGK._homePos - myPos).Magnitude > 18 then
		AutoGK._homePos = Vector3.new(myPos.X, myPos.Y, myPos.Z)
	end

	local footballs = Workspace:FindFirstChild("Footballs")
	if not footballs then return end

	local closestBall, closestDist, ballVel = nil, math.huge, Vector3.zero
	for _, ball in ipairs(footballs:GetChildren()) do
		if ball:IsA("BasePart") and ball.Name == "Ball" and not ball.Anchored then
			local d = (ball.Position - myPos).Magnitude
			if d < closestDist then
				closestDist = d
				closestBall = ball
				ballVel = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.zero
			end
		end
	end
	if not closestBall then 
		updateGKPatrol(dt)
		return 
	end

	if isBallInGoalProtection(closestBall.Position) then
		AutoGK:ReturnToPosition()
		return
	end

	local dist = closestDist
	local incoming = (ballVel:Dot( (closestBall.Position - myPos).Unit ) < -3) or dist < (AutoGK.SaveRadius * 1.6)

	if not AutoGK.Cooldown and not AutoGK._isDiving and dist > 4 and dist < 26 then
		local goalCenter = AutoGK._homePos or myPos
		local ballX = closestBall.Position.X
		local targetX = goalCenter.X * 0.3 + ballX * 0.7
		local target = Vector3.new(targetX, myPos.Y, goalCenter.Z)
		local delta = target - myPos
		if delta.Magnitude > 1.2 then
			hrp.CFrame = CFrame.new(myPos + delta.Unit * math.min(0.65, delta.Magnitude * 0.12)) * CFrame.Angles(0, hrp.Orientation.Y * math.pi/180 ,0)
		end
	else
		updateGKPatrol(dt)
	end

	if not AutoGK.Cooldown and dist <= AutoGK.SaveRadius and incoming then
		local doDive = (math.abs(closestBall.Position.X - myPos.X) > 2.8) or ballVel.Magnitude > 18
		AutoGK:DoSave(closestBall, doDive)
		task.delay(1.8, function() AutoGK:ReturnToPosition() end)
	end

	if not AutoGK.Cooldown and not AutoGK._isDiving and dist <= 5.5 then
		AutoGK.Cooldown = true
		local action = "Save"
		local pwr = 0.95
		local pay = buildPayload(closestBall, action, pwr, {Ground = false, Right=false, Left=false}, hrp.CFrame)
		taggedTouchKick(pay)
		task.delay(0.9, function() AutoGK.Cooldown = false end)
		task.delay(1.2, function() if AutoGK.Enabled then AutoGK:ReturnToPosition() end end)
	end
end))

local Settings = {
	HitboxEnabled = true,
	HitboxSize = 30,
	HitboxUseTheme = true,
	ShowOutline = true,
	OutlineColor = Color3.fromRGB(0, 255, 150),
	OutlineTransparency = 0.5
}

local CurveSettings = {AlwaysCurveRight=false, AlwaysCurveLeft=false, AlwaysGroundShot=false}
local MetaExploits = {
	AlwaysMaxPower=false,
	AutoKick=false,
	AutoKickDelay=0.2,
	AutoKickKeybind="F",
	AutoKickPower=0.9,
	AutoKickHeight=10,
	AutoKickTargetGoal=false,
	TPToBall=false,
	AntiVoteKick=false,
	AutoTPKickerLoop=false,
	AutoAimGoal=false,
	CamLockBall=false,
	AirDribble=false,
	AirDribbleKeybind="None",
	AirDribbleHeight=6,
	AirDribbleForward=2,
	AirDribblePower=0.28,
	AirDribblePlatform=false,
	AirPlatformSize=26,
	AirBallESP=false,
	NewHitboxCurveBoost=false,
	CurveBoostEffect=false,
	lastAirDribbleTouch=0,
	PowerMode="Normal",
	HitboxKeybind = "None",
}

local autoTPKickerActive = false
local VisualSettings = {BallESP=false, PlayerESP=false, FPSBoost=false}
local CurveKeyHoldActive = {E=false, Q=false, C=false}
local airDribbleKeyHeld = false
local airDribbleMouseHeld = false
local mobileAirDribbleActive = false
local hitboxPreviewPart = nil
local isTackling = false

local function findBall()
	local footballsFolder = Workspace:FindFirstChild("Footballs")
	if footballsFolder then
		for _, child in ipairs(footballsFolder:GetChildren()) do
			if child:IsA("BasePart") and child.Name:lower():find("ball") then
				return child
			end
		end
	end
	for _, v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("BasePart") and v.Name:lower():find("ball") and not v.Anchored then
			return v
		end
	end
	return nil
end

local function getOpponentGoalPosition()
	if not LocalPlayer or not LocalPlayer.Team then return nil end
	local myTeamName = LocalPlayer.Team.Name
	local opponentGoalNet
	if myTeamName == "Home" then
		opponentGoalNet = SafeFindPath(Workspace, {"Stadium", "Model", "Nets", "Away", "Nets", "Normal"})
	elseif myTeamName == "Away" then
		opponentGoalNet = SafeFindPath(Workspace, {"Stadium", "Model", "Nets", "Home", "Nets", "Normal"})
	end
	if opponentGoalNet then
		local netPart = opponentGoalNet:FindFirstChild("Net")
		if netPart and netPart:IsA("BasePart") then
			return netPart.Position
		end
		for _, child in ipairs(opponentGoalNet:GetChildren()) do
			if child:IsA("BasePart") then
				return child.Position
			end
		end
	end
	return nil
end

local function getOpponentGoalName()
	if not LocalPlayer or not LocalPlayer.Team then return nil end
	local myTeamName = LocalPlayer.Team.Name
	if myTeamName == "Home" then return "Away" elseif myTeamName == "Away" then return "Home" end
	return nil
end

local function isBallInGoal(ball, goalName)
	if not ball or not goalName then return false end
	local goalPath = {"Stadium", "Model", "Nets", goalName, "Nets", "Normal"}
	local goalObj = SafeFindPath(Workspace, goalPath)
	if goalObj then
		local goalPart = goalObj:FindFirstChild("Net")
		if not goalPart or not goalPart:IsA("BasePart") then
			for _, child in ipairs(goalObj:GetChildren()) do
				if child:IsA("BasePart") then
					goalPart = child
					break
				end
			end
		end
		if goalPart and goalPart:IsA("BasePart") then
			local region = Region3.new(goalPart.Position - Vector3.new(20, 10, 10), goalPart.Position + Vector3.new(20, 10, 10))
			local partsInRegion = Workspace:FindPartsInRegion3(region, nil, 100)
			for _, part in ipairs(partsInRegion) do
				if part == ball then return true end
			end
		end
	end
	return false
end

local function runAutoTPKicker()
	if not MetaExploits.AutoTPKickerLoop then
		autoTPKickerActive = false
		return
	end
	autoTPKickerActive = true
	task.spawn(function()
		while autoTPKickerActive and MetaExploits.AutoTPKickerLoop and task.wait(0.15) do
			if not (HumanoidRootPart and HumanoidRootPart.Parent) then continue end
			local ball = findBall()
			local goalPos = getOpponentGoalPosition()
			local goalName = getOpponentGoalName()
			if ball and goalPos and goalName then
				if isBallInGoal(ball, goalName) then
					continue
				end
				local distToGoal = (ball.Position - goalPos).Magnitude
				if distToGoal < 18 then
					continue
				end
				local targetPos = ball.Position
				local aimPos = goalPos
				local targetCFrame = CFrame.new(targetPos - (aimPos - targetPos).Unit * 4, aimPos)
				HumanoidRootPart.CFrame = targetCFrame
				task.wait(0.08)
				if Remotes.TouchKick then
					local kickPayload = buildPayload(ball, "Shoot", 1, {Ground = false, Right = false, Left = false}, HumanoidRootPart.CFrame)
					taggedTouchKick(kickPayload)
				end
				task.wait(0.01)
			end
		end
	end)
end

local function GetRemotes()
	local touchRemote, kickRemote
	pcall(function()
		local r = ReplicatedStorage:FindFirstChild("Remotes")
		local g = r and r:FindFirstChild("Game")
		local t = g and g:FindFirstChild("Touch")
		if t then
			touchRemote = t
			kickRemote = t:FindFirstChild("Kick")
		end
	end)
	if not touchRemote then
		for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
			if v:IsA("RemoteFunction") and v.Name == "Touch" then
				touchRemote = v
				break
			end
		end
	end
	if not kickRemote then
		for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
			if v:IsA("RemoteEvent") and v.Name == "Kick" then
				kickRemote = v
				break
			end
		end
	end
	return touchRemote, kickRemote
end

local function LocateChargeGui()
	local pGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not pGui then return nil end
	local main = pGui:FindFirstChild("Main")
	if not main then return nil end
	local gameGui = main:FindFirstChild("Game")
	if not gameGui then return nil end
	return gameGui:FindFirstChild("Charge")
end

local Charge = {}

function Charge.Get()
	local gui = LocateChargeGui()
	if gui then
		local bar = gui:FindFirstChild("Bar")
		if bar and bar:IsA("Frame") then
			return math.floor(math.clamp(bar.Size.X.Scale, 0, 1) * 100) / 100
		end
	end
	return 0
end

local Debug = {}

function Debug.Start(size, offset)
	if not HumanoidRootPart then return end
	for _, v in ipairs(Workspace.Terrain:GetChildren()) do
		if v.Name == "Debug" then v:Destroy() end
	end
	local p = Instance.new("Part")
	p.Name = "Debug"
	p.Size = size
	p.CFrame = HumanoidRootPart.CFrame * (offset or CFrame.new())
	p.CanCollide = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	p.Transparency = 0.8
	p.Color = Color3.fromRGB(255, 0, 0)
	p.Material = Enum.Material.Neon
	p.Parent = Workspace.Terrain
	local w = Instance.new("WeldConstraint")
	w.Part0 = HumanoidRootPart
	w.Part1 = p
	w.Parent = p
end

function Debug.Registered()
	for _, v in ipairs(Workspace.Terrain:GetChildren()) do
		if v.Name == "Debug" then
			v.Color = Color3.fromRGB(0, 255, 127)
			task.delay(0.5, function() if v and v.Parent then v:Destroy() end end)
		end
	end
end

function Debug.Cancelled()
	for _, v in ipairs(Workspace.Terrain:GetChildren()) do
		if v.Name == "Debug" then
			task.delay(0.5, function() if v and v.Parent then v:Destroy() end end)
		end
	end
end

function Debug.End()
	for _, v in ipairs(Workspace.Terrain:GetChildren()) do
		if v.Name == "Debug" and v.BrickColor ~= BrickColor.new("Teal") then
			v:Destroy()
		end
	end
end

local function ReadCurves()
	local ground, right, left = false, false, false

	pcall(function()
		local toggles = LocalPlayer.PlayerGui.Main.Game.Toggles
		if toggles then
			if toggles:FindFirstChild("Right") and toggles.Right.Visible then right = true end
			if toggles:FindFirstChild("Left") and toggles.Left.Visible then left = true end
			if toggles:FindFirstChild("Ground") and toggles.Ground.Visible then ground = true end
		end
	end)

	if UserInputService:IsKeyDown(Enum.KeyCode.E) or CurveKeyHoldActive.E then right = true end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) or CurveKeyHoldActive.Q then left = true end
	if UserInputService:IsKeyDown(Enum.KeyCode.C) or UserInputService:IsKeyDown(Enum.KeyCode.F) or CurveKeyHoldActive.C then ground = true end

	if CurveSettings.AlwaysCurveRight then right = true end
	if CurveSettings.AlwaysCurveLeft then left = true end
	if CurveSettings.AlwaysGroundShot then ground = true end

	-- TURF CURVE MATRIX PACKING (CRITICAL FIX FOR HIGH BALL BALLOONS)
	if right and left then left = false end
	if (right or left) and ground then
		-- Keeps compound vector forces flat along the pitch parameters natively
		ground = true
	end

	return ground, right, left
end

local v2 = ""
local v3 = false
local v4 = false
local v5 = false
local v11 = 0
local v12 = 1
local v13 = Vector3.new(0, 0, 0)
local v14 = CFrame.new(0, 0, 0)

local TouchModule = {}

local TouchGuard = {
    seq = 0,
    fired = false,
    lastBall = nil,
    lastAt = 0,
    minGap = 0.09,
    bursts = 4,
}

local function resolveBallRoot(part)
    local node = part
    for _ = 1, 4 do
        if not node or node == Workspace then break end
        local parent = node.Parent
        if parent and parent.Parent == Workspace:FindFirstChild("Footballs") then
            return parent:IsA("BasePart") and parent or node
        end
        if parent and parent.Name == "Footballs" then
            return node
        end
        node = parent
    end
    return part
end

local function looksLikeBall(part)
    if not part or not part:IsA("BasePart") or part.Anchored then return false end
    local pName = string.lower(part.Name)
    local parentName = part.Parent and string.lower(part.Parent.Name) or ""
    if pName == "ball" or string.find(pName, "ball", 1, true) then return true end
    if parentName == "ball" or string.find(parentName, "ball", 1, true) then return true end
    if string.find(parentName, "football", 1, true) then return true end
    local gp = part.Parent and part.Parent.Parent
    if gp and string.find(string.lower(gp.Name), "football", 1, true) then return true end
    return false
end

function TouchModule.Confirm(res)
	if v5 == true then return end
	if res == true then
		v5 = true
		Debug.Registered()
		return
	end
	if res == false then
		Debug.Cancelled()
	end
end

function TouchModule.FireBurst(ball, actionName, chargeVal, curves)
    local touchRemote, kickRemote = GetRemotes()
    local payload = {
        ball,
        actionName,
        math.floor(chargeVal) / 100,
        curves,
        HumanoidRootPart.CFrame,
        getMoveDir(),
    }
    local delivered = false
    for _ = 1, math.max(1, TouchGuard.bursts) do
        if kickRemote and kickRemote:IsA("RemoteEvent") then
            if pcall(function() kickRemote:FireServer(payload) end) then delivered = true end
        end
        if touchRemote and touchRemote:IsA("RemoteFunction") then
            local ok, res = pcall(function() return touchRemote:InvokeServer(payload) end)
            if ok then
                delivered = true
                if res == true then break end
            end
        end
    end
    return delivered
end

local IsTouchLockedOnFrame = false

function TouchModule.Detect(duration, actionName)
	local startTick = tick()
	v12 = v12 + 1
	local currentToken = v12

    TouchGuard.seq = TouchGuard.seq + 1
    TouchGuard.fired = false

	task.spawn(function()
		while tick() - startTick < duration do
			RunService.Heartbeat:Wait()
			if not (Character and HumanoidRootPart and HumanoidRootPart.Parent) then break end
			if currentToken ~= v12 then break end
			if isTackling then break end
            if TouchGuard.fired or v5 or IsTouchLockedOnFrame then break end

			local activeSize = Settings.HitboxEnabled and Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize) or v13
			local activeOffset = Settings.HitboxEnabled and CFrame.new(0, 0, 0) or v14
			local boxCenter = HumanoidRootPart.CFrame * activeOffset

            local ball, bestDist = nil, math.huge
			for _, part in ipairs(Workspace:GetPartBoundsInBox(boxCenter, activeSize)) do
                if looksLikeBall(part) then
                    local d = (part.Position - HumanoidRootPart.Position).Magnitude
                    if d < bestDist then
                        ball = resolveBallRoot(part)
                        bestDist = d
                    end
                end
            end

            if ball and v4 == true and v5 == false and not IsTouchLockedOnFrame then
                local now = tick()
                if ball == TouchGuard.lastBall and (now - TouchGuard.lastAt) < TouchGuard.minGap then
                    break
                end

                IsTouchLockedOnFrame = true
                TouchGuard.fired = true
                v5 = true
                TouchGuard.lastBall = ball
                TouchGuard.lastAt = now

                local isGround, isRight, isLeft = ReadCurves()

                if isGround and (isRight or isLeft) then
                    local netPos = getOpponentGoalPosition()
                    if netPos then
                        boxCenter = CFrame.lookAt(HumanoidRootPart.Position, Vector3.new(netPos.X, ball.Position.Y, netPos.Z))
                    end
                end

                local ok = TouchModule.FireBurst(ball, actionName, Charge.Get() * 100, {
                    Ground = isGround, Right = isRight, Left = isLeft,
                })

                if ok then
                    Debug.Registered()
                end

                task.delay(math.max(0.12, TouchGuard.minGap), function()
                    IsTouchLockedOnFrame = false
                end)
                break
            end
		end
	end)
end

function TouchModule.ChargeAction()
	if not Character or not Character.Parent or v3 ~= false then return end
	if isTackling then return end
	v3 = true
end

function TouchModule.ReleaseAction()
	if not Character or not Character.Parent or v3 ~= true then return end
	if isTackling then
		v3 = false
		return
	end

	v3 = false
	v5 = false
	v4 = true
	v2 = ""

	local isGoalie = isGoalie()
	local currentCharge = Charge.Get()

	if currentCharge <= 0.3 then
		if not isGoalie then
			v13 = Vector3.new(2.25, 5.25, 1.5)
			v14 = CFrame.new(0, -0.5, -0.25)
			v2 = "Dribble"
			v11 = 0.75
		else
			v13 = Vector3.new(4, 5.3, 2)
			v14 = CFrame.new(0, -0.5, -0.25)
			v2 = "Save"
			v11 = 1
		end
	else
		v13 = Vector3.new(2.25, 5.25, 2.5)
		v14 = CFrame.new(0, -0.5, 0)
		v2 = "Shoot"
		v11 = 0.5
	end

	TouchModule.Detect(v11, v2)
	Debug.Start(v13, v14)

	pcall(function()
		local mod = ReplicatedStorage:FindFirstChild("Modules")
		if mod and mod:FindFirstChild("Animation") then
			local anim = require(mod.Animation)
			if anim and anim.Action then anim.Action(v2) end
		end
	end)

	local seqToken = v12
	task.delay(v11, function()
		if v12 == seqToken then
			v13 = Vector3.new(0, 0, 0)
			v14 = CFrame.new(0, 0, 0)
			v5 = false
			v4 = false
			v2 = ""
			Debug.End()
		end
	end)
end

local function _fireAirLiftKick(ball)
	if not ball or not HumanoidRootPart then return false end
	if isTackling then return end
	local h = math.clamp(MetaExploits.AirDribbleHeight or 6, 1, 12)
	local fwd = math.clamp(MetaExploits.AirDribbleForward or 2, 0, 8)
	local power = math.clamp(MetaExploits.AirDribblePower or 0.28, 0.15, 0.4)
	local liftDir = HumanoidRootPart.CFrame.LookVector * fwd + Vector3.new(0, math.max(h, 4), 0)
	local aim = CFrame.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + liftDir.Unit * 20)
	local args = {
		{
			ball,
			"Dribble",
			power,
			{ Ground = false, Right = false, Left = false },
			aim,
			getMoveDir(),
		},
	}
	local touchRemote, kickRemote = GetRemotes()
	local payload = args[1]
	for _ = 1, 4 do
		if kickRemote and kickRemote:IsA("RemoteEvent") then
			pcall(function() kickRemote:FireServer(payload) end)
		end
		if touchRemote and touchRemote:IsA("RemoteFunction") then
			local ok, res = pcall(function() return touchRemote:InvokeServer(payload) end)
			if ok and res == true then break end
		end
	end
	return true
end

local function _runAirDribble()
	if not HumanoidRootPart then return end
	if (tick() - (MetaExploits.lastAirDribbleTouch or 0)) < 0.1 then return end

	local zone = math.clamp(MetaExploits.AirPlatformSize or 26, 4, 100)
	local boxSize = Vector3.new(zone, math.clamp(zone * 0.55, 6, 40), zone)
	local boxCF = HumanoidRootPart.CFrame * CFrame.new(0, 1.5, -1)

	local ball = nil
	for _, obj in ipairs(Workspace:GetPartBoundsInBox(boxCF, boxSize)) do
		if obj and obj:IsA("BasePart") and obj.Name:lower():find("ball") and not obj.Anchored then
			ball = obj
			break
		end
	end
	if not ball then
		ball = findBall()
		if ball then
			local d = (ball.Position - HumanoidRootPart.Position).Magnitude
			if d > zone then ball = nil end
		end
	end
	if not ball then return end

	MetaExploits.lastAirDribbleTouch = tick()
	_fireAirLiftKick(ball)
end

local function _keyMatches(bindName, input)
	if not bindName or bindName == "None" or bindName == "" then return false end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode then
		return input.KeyCode.Name == bindName
	end
	if bindName == "MouseButton1" and input.UserInputType == Enum.UserInputType.MouseButton1 then return true end
	if bindName == "MouseButton2" and input.UserInputType == Enum.UserInputType.MouseButton2 then return true end
	if bindName == "MouseButton3" and input.UserInputType == Enum.UserInputType.MouseButton3 then return true end
	return false
end

local function cancelActiveDetection()
	v12 = v12 + 1
	v3 = false
	v4 = false
	v5 = false
end

local inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then return end
	if processed then return end
	local kN = input.KeyCode and input.KeyCode.Name or nil

	-- Tackle key (X) sets tackling flag and cancels any ongoing kick detection
	if input.KeyCode == Enum.KeyCode.X then
		isTackling = true
		cancelActiveDetection()
		return
	end

	if _keyMatches(MetaExploits.HitboxKeybind, input) then
		Settings.HitboxEnabled = not Settings.HitboxEnabled
		TouchLine:CreateNotification("Hitbox", Settings.HitboxEnabled and "ON" or "OFF", 1.5)
		return
	end

	if _keyMatches(MetaExploits.AutoKickKeybind, input) then
		MetaExploits.AutoKick = not MetaExploits.AutoKick
		TouchLine:CreateNotification("Auto Kick", MetaExploits.AutoKick and "ON" or "OFF", 1.5)
		return
	end

	if MetaExploits.AirDribble and (input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1) then
		if _keyMatches(MetaExploits.AirDribbleKeybind, input) then
			airDribbleKeyHeld = true
			airDribbleMouseHeld = true
			_runAirDribble()
			return
		end
	end

	if input.UserInputType == Enum.UserInputType.Keyboard and kN and CurveKeyHoldActive[kN] ~= nil then
		CurveKeyHoldActive[kN] = true
		return
	end

	-- PC only: charge on left click
	if not IS_MOBILE and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		if MetaExploits.AirDribble and (airDribbleKeyHeld or airDribbleMouseHeld or mobileAirDribbleActive) then
			return
		end
		TouchModule.ChargeAction()
		return
	end
end)

local inputEndedConn = UserInputService.InputEnded:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then return end
	if processed then return end
	local kN = input.KeyCode and input.KeyCode.Name or nil

	if input.KeyCode == Enum.KeyCode.X then
		isTackling = false
		return
	end

	if kN and CurveKeyHoldActive[kN] ~= nil then
		CurveKeyHoldActive[kN] = false
		return
	end

	if MetaExploits.AirDribble and (input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1) then
		if _keyMatches(MetaExploits.AirDribbleKeybind, input) then
			airDribbleKeyHeld = false
			airDribbleMouseHeld = false
			return
		end
	end

	if not IS_MOBILE and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		if MetaExploits.AirDribble and (airDribbleKeyHeld or airDribbleMouseHeld or mobileAirDribbleActive) then
			return
		end
		TouchModule.ReleaseAction()
		return
	end
end)

local _ballESP = nil

function destroyBallESP()
	if _ballESP then
		pcall(function() _ballESP:Destroy() end)
		_ballESP = nil
	end
end

local function updateBallESP()
	if not VisualSettings.BallESP then
		destroyBallESP()
		return
	end
	local ball = findBall()
	if not ball or not ball.Parent then
		destroyBallESP()
		return
	end
	if _ballESP and _ballESP.Adornee ~= ball then destroyBallESP() end
	if not _ballESP then
		_ballESP = create("BillboardGui"){
			Name = "TL_BallESP", Adornee = ball, Parent = RootGuiParent,
			Size = UDim2.fromOffset(90, 30), AlwaysOnTop = true,
			StudsOffset = Vector3.new(0, 2.2, 0), MaxDistance = 600,
		}
		local box = create("Frame"){
			Parent = _ballESP, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		}
		create("TextLabel"){
			Parent = box, Name = "Info", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = ACCENT_COLOR,
			TextStrokeTransparency = 0.4, Text = "BALL",
		}
	end
	local info = _ballESP:FindFirstChild("Frame") and _ballESP.Frame:FindFirstChild("Info")
	if info and HumanoidRootPart then
		local d = math.floor((ball.Position - HumanoidRootPart.Position).Magnitude)
		info.Text = "BALL  " .. d .. "m"
		info.TextColor3 = ACCENT_COLOR
	end
end

local _playerESP = {}

function destroyPlayerESP()
	for plr, hl in pairs(_playerESP) do
		pcall(function() hl:Destroy() end)
		_playerESP[plr] = nil
	end
end

local function updatePlayerESP()
	if not VisualSettings.PlayerESP then
		if next(_playerESP) then destroyPlayerESP() end
		return
	end
	local myTeam = LocalPlayer and LocalPlayer.Team
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local ch = plr.Character
			if ch and ch.Parent then
				local hl = _playerESP[plr]
				if not hl or not hl.Parent then
					hl = create("Highlight"){Name = "TL_ESP", Parent = RootGuiParent, FillTransparency = 0.75, OutlineTransparency = 0}
					_playerESP[plr] = hl
				end
				hl.Adornee = ch
				local friendly = myTeam and plr.Team == myTeam
				hl.FillColor = friendly and Color3.fromRGB(70, 220, 130) or Color3.fromRGB(255, 80, 80)
				hl.OutlineColor = hl.FillColor
			elseif _playerESP[plr] then
				pcall(function() _playerESP[plr]:Destroy() end)
				_playerESP[plr] = nil
			end
		end
	end
	for plr, hl in pairs(_playerESP) do
		if not plr.Parent then
			pcall(function() hl:Destroy() end)
			_playerESP[plr] = nil
		end
	end
end

local _voteGuardConn = nil

local function setAntiVoteKick(on)
	if _voteGuardConn then
		pcall(function() _voteGuardConn:Disconnect() end)
		_voteGuardConn = nil
	end
	if not on then return end
	local respond = SafeFindPath(ReplicatedStorage, {"Remotes", "Menu", "Votekick", "Respond"})
	local vote = SafeFindPath(ReplicatedStorage, {"Remotes", "Menu", "Votekick", "Vote"})
	if not respond then
		TouchLine:CreateNotification("Anti Vote Kick", "Votekick remote not found in this server", 3)
		return
	end
	_voteGuardConn = trackConn(respond.OnClientEvent:Connect(function(target, reason)
		local name = typeof(target) == "Instance" and target.Name or tostring(target)
		local isMe = LocalPlayer and (name == LocalPlayer.Name or target == LocalPlayer)
		TouchLine:CreateNotification("Votekick", (isMe and "YOU are being votekicked" or ("Vote against " .. name)) .. (reason and ("  " .. tostring(reason)) or ""), 5)
		if vote then
			task.delay(0.2, function()
				pcall(function() vote:FireServer(false) end)
			end)
		end
	end))
end

local heartbeatConn = RunService.Heartbeat:Connect(function()
	if SCRIPT_KILLED then return end
	if not (Character and Character.Parent and HumanoidRootPart and HumanoidRootPart.Parent) then return end

	if MetaExploits.AutoKick and HumanoidRootPart and not isTackling
		and tick() - (MetaExploits._lastAutoKick or 0) >= math.max(0.1, MetaExploits.AutoKickDelay or 0.2) then
		local target, bestD = nil, math.huge
		for _, obj in ipairs(Workspace:GetPartBoundsInBox(HumanoidRootPart.CFrame, Vector3.new(6, 10, 6))) do
			if looksLikeBall(obj) then
				local d = (obj.Position - HumanoidRootPart.Position).Magnitude
				if d < bestD then target, bestD = resolveBallRoot(obj), d end
			end
		end
		if target then
			MetaExploits._lastAutoKick = tick()
			local power = MetaExploits.AlwaysMaxPower and 1 or MetaExploits.AutoKickPower
			power = math.clamp(power, 0.15, 1)
			local aim = HumanoidRootPart.CFrame * CFrame.Angles(math.rad(math.clamp(MetaExploits.AutoKickHeight * 2.2, 4, 45)), 0, 0)
			local ground, right, left = ReadCurves()
			if MetaExploits.AutoKickTargetGoal then
				local gp = getOpponentGoalPosition()
				if gp then
					local dist = (gp - HumanoidRootPart.Position).Magnitude
					local lift = dist < 22 and 1.2 or math.clamp(MetaExploits.AutoKickHeight, 0, 25)
					aim = CFrame.lookAt(HumanoidRootPart.Position, gp + Vector3.new(0, lift, 0))
					if dist < 22 then
						ground = true
						right, left = false, false
					end
					power = math.clamp(0.35 + dist / 90, 0.35, 1)
					if MetaExploits.AlwaysMaxPower then power = 1 end
				end
			end
			TouchModule.FireBurst(target, "Shoot", power * 100, {Ground = ground, Right = right, Left = left})
		end
	end

	if MetaExploits.AutoAimGoal and HumanoidRootPart then
		local gp = getOpponentGoalPosition()
		local ball = findBall()
		if gp and ball and (ball.Position - HumanoidRootPart.Position).Magnitude <= 14 then
			local flat = Vector3.new(gp.X, HumanoidRootPart.Position.Y, gp.Z)
			local goal = CFrame.lookAt(HumanoidRootPart.Position, flat)
			HumanoidRootPart.CFrame = HumanoidRootPart.CFrame:Lerp(goal, 0.25)
		end
	end

	if MetaExploits.TPToBall then
		local ball = findBall()
		if ball then
			HumanoidRootPart.CFrame = CFrame.new(ball.Position + Vector3.new(0, 3, -2))
		end
	end

	if MetaExploits.CamLockBall then
		local ball = findBall()
		if ball and Camera and ball.Parent then
			pcall(function()
				if Camera.CameraType == Enum.CameraType.Scriptable then
					Camera.CameraType = Enum.CameraType.Custom
				end
				if Humanoid then Camera.CameraSubject = Humanoid end
				local pos = Camera.CFrame.Position
				Camera.CFrame = CFrame.new(pos, ball.Position)
			end)
		else
			pcall(function()
				if Camera and Camera.CameraType == Enum.CameraType.Scriptable then
					Camera.CameraType = Enum.CameraType.Custom
				end
				if Humanoid then Camera.CameraSubject = Humanoid end
			end)
		end
	else
		pcall(function()
			if Camera and Camera.CameraType == Enum.CameraType.Scriptable then
				Camera.CameraType = Enum.CameraType.Custom
			end
		end)
	end

	updateBallESP()
	updatePlayerESP()

	if Settings.HitboxEnabled and Settings.ShowOutline then
		if not hitboxPreviewPart or not hitboxPreviewPart.Parent then
			hitboxPreviewPart = Instance.new("Part")
			hitboxPreviewPart.Name = "TouchLinePreview"
			hitboxPreviewPart.Anchored = true
			hitboxPreviewPart.CanCollide = false
			hitboxPreviewPart.CanQuery = false
			hitboxPreviewPart.CanTouch = false
			hitboxPreviewPart.CastShadow = false
			hitboxPreviewPart.Massless = true
			hitboxPreviewPart.Material = Enum.Material.SmoothPlastic
			hitboxPreviewPart.Parent = Workspace.Terrain
			local sel = Instance.new("SelectionBox")
			sel.Name = "Edge"
			sel.Adornee = hitboxPreviewPart
			sel.LineThickness = 0.03
			sel.SurfaceTransparency = 1
			sel.Parent = hitboxPreviewPart
		end
		local col = Settings.HitboxUseTheme and ACCENT_COLOR or Settings.OutlineColor
		hitboxPreviewPart.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
		hitboxPreviewPart.CFrame = HumanoidRootPart.CFrame
		hitboxPreviewPart.Color = col
		hitboxPreviewPart.Transparency = Settings.OutlineTransparency
		local edge = hitboxPreviewPart:FindFirstChild("Edge")
		if edge then edge.Color3 = col end
	else
		if hitboxPreviewPart and hitboxPreviewPart.Parent then
			hitboxPreviewPart:Destroy()
			hitboxPreviewPart = nil
		end
	end
end)

local function _spawnCurveBoostEffect(ball, isRight, isLeft)
	if not MetaExploits.CurveBoostEffect then return end
	if not ball or not ball.Parent then return end
	if not (isRight or isLeft) then return end
	task.spawn(function()
		pcall(function()
			local att0 = Instance.new("Attachment")
			att0.Name = "TL_CurveA0"
			att0.Position = Vector3.zero
			att0.Parent = ball
			local att1 = Instance.new("Attachment")
			att1.Name = "TL_CurveA1"
			att1.Position = Vector3.new(isRight and 0.9 or -0.9, 0.15, -0.35)
			att1.Parent = ball

			local trail = Instance.new("Trail")
			trail.Name = "TL_CurveTrail"
			trail.Attachment0 = att0
			trail.Attachment1 = att1
			trail.Lifetime = 0.55
			trail.MinLength = 0.08
			trail.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.15),
				NumberSequenceKeypoint.new(0.45, 0.55),
				NumberSequenceKeypoint.new(1, 0),
			})
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			})
			local c1 = isRight and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 60, 200)
			local c2 = isRight and Color3.fromRGB(120, 80, 255) or Color3.fromRGB(255, 180, 40)
			trail.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, c1),
				ColorSequenceKeypoint.new(0.5, c2),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
			})
			trail.LightEmission = 1
			trail.FaceCamera = true
			trail.Parent = ball

			local pe = Instance.new("ParticleEmitter")
			pe.Name = "TL_CurveSparks"
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Rate = 28
			pe.Lifetime = NumberRange.new(0.25, 0.55)
			pe.Speed = NumberRange.new(1.5, 4)
			pe.SpreadAngle = Vector2.new(30, 30)
			pe.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			})
			pe.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			pe.Color = ColorSequence.new(c1, c2)
			pe.LightEmission = 1
			pe.Parent = ball

			local hl = Instance.new("Highlight")
			hl.Name = "TL_CurveHL"
			hl.Adornee = ball
			hl.FillColor = c1
			hl.OutlineColor = c2
			hl.FillTransparency = 0.65
			hl.OutlineTransparency = 0.15
			hl.Parent = ball

			local t0 = tick()
			while ball.Parent and (tick() - t0) < 2.8 do
				local side = isRight and 1 or -1
				local wobble = math.sin((tick() - t0) * 14) * 0.12
				att1.Position = Vector3.new(side * (0.85 + wobble), 0.12 + math.abs(wobble) * 0.5, -0.4)
				task.wait()
			end

			pcall(function() trail:Destroy() end)
			pcall(function() pe:Destroy() end)
			pcall(function() hl:Destroy() end)
			pcall(function() att0:Destroy() end)
			pcall(function() att1:Destroy() end)
		end)
	end)
end

local Window, Tab = {}, {}
Window.__index, Tab.__index = Window, Tab

local function getDiscordLink(callback)
	local url = "https://pastefy.app/Ca4ijKNE/raw"
	local response_func = syn and syn.request or http_request or request
	if not response_func then callback(nil) return end
	task.spawn(function()
		local success, result = pcall(response_func, {Url = url, Method = "GET"})
		if success and result and result.Body then
			local link = result.Body:gsub("\n", ""):gsub("\r", ""):gsub(" ", "")
			if link and link:find("discord") then
				callback(link)
			else
				callback(nil)
			end
		else
			callback(nil)
		end
	end)
end

function TouchLine:CreateNotification(title, text, duration, options)
	options = options or {}
	local dur = (type(duration) == "number" and duration) or 3

	local container = RootGuiParent:FindFirstChild("TouchLine_Notifications")
	if not container then
		container = registerThemeRoot(create("ScreenGui"){Name = "TouchLine_Notifications", Parent = RootGuiParent, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global, IgnoreGuiInset = true})
	end

	local notifHeight = (options.buttons and #options.buttons > 0) and 125 or 90

	local notif = create("Frame"){
		Parent = container,
		Size = UDim2.fromOffset(300, notifHeight),
		Position = UDim2.new(1.2, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		BorderSizePixel = 0,
		ClipsDescendants = true
	}

	create("UICorner"){Parent = notif, CornerRadius = UDim.new(0, 8)}
	create("UIStroke"){Parent = notif, Thickness = 0.5, Color = ACCENT_COLOR}

	create("TextLabel"){Parent = notif, Size = UDim2.new(1, -50, 0, 20), Position = UDim2.fromOffset(10, 5), Text = tostring(title), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}
	create("TextLabel"){Parent = notif, Size = UDim2.new(1, -50, 0, 30), Position = UDim2.fromOffset(10, 25), Text = tostring(text), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(180, 180, 200), BackgroundTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left}

	local isClosed = false
	local function closeNotification()
		if isClosed then return end
		isClosed = true

		if options.isDiscord then
			lastDiscordShown = tick()
			discordNotifActive = false
		end

		if notif and notif.Parent then
			TweenService:Create(notif, TweenInfo.new(0.3), {Position = UDim2.new(1.2, 0, notif.Position.Y.Scale, notif.Position.Y.Offset)}):Play()
			task.delay(0.35, function()
				if notif and notif.Parent then notif:Destroy() end
				for i = #activeNotifications, 1, -1 do
					if activeNotifications[i] == notif then table.remove(activeNotifications, i) break end
				end
				local currentY = -8
				for i = 1, #activeNotifications do
					local frame = activeNotifications[i]
					if frame and frame.Parent then
						local h = frame.Size.Y.Offset
						local targetPos = UDim2.new(1, -8, 1, currentY)
						TweenService:Create(frame, TweenInfo.new(0.25), {Position = targetPos}):Play()
						currentY = currentY - h - 10
					end
				end
			end)
		end
	end

	if options.buttons and #options.buttons > 0 then
		local btnContainer = create("Frame"){
			Parent = notif,
			Size = UDim2.new(1, -20, 0, 28),
			Position = UDim2.new(0, 10, 1, -38),
			BackgroundTransparency = 1
		}

		create("UIListLayout"){
			Parent = btnContainer,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center
		}

		for _, btnInfo in ipairs(options.buttons) do
			local btn = create("TextButton"){
				Parent = btnContainer,
				Size = UDim2.new(0, 70, 1, 0),
				BackgroundColor3 = btnInfo.Color or Color3.fromRGB(40, 40, 50),
				Text = btnInfo.Text or "Button",
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = Color3.new(1,1,1),
				AutoButtonColor = false,
				BorderSizePixel = 0
			}
			create("UICorner"){Parent = btn, CornerRadius = UDim.new(0, 4)}
			create("UIStroke"){Parent = btn, Color = ACCENT_COLOR, Thickness = 0.5, Transparency = 0.5}

			btn.MouseButton1Click:Connect(function()
				if btnInfo.Callback then btnInfo.Callback() end
				if not btnInfo.DontClose then closeNotification() end
			end)
		end
	elseif options.showCopy then
		local copyBtn = create("TextButton"){Parent = notif, Size = UDim2.fromOffset(60, 22), Position = UDim2.fromOffset(10, 60), BackgroundColor3 = ACCENT_COLOR, BorderSizePixel = 0, Text = "Copy", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false}
		create("UICorner"){Parent = copyBtn, CornerRadius = UDim.new(0, 4)}
		copyBtn.MouseButton1Click:Connect(function()
			if setclipboard and options.copyText then
				setclipboard(options.copyText)
				copyBtn.Text = "Copied!"
				task.wait(2)
				copyBtn.Text = "Copy"
			end
		end)
	end

	local closeBtn = create("TextButton"){Parent = notif, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -25, 0, 5), BackgroundColor3 = Color3.fromRGB(255, 50, 50), BorderSizePixel = 0, Text = "X", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false}
	create("UICorner"){Parent = closeBtn, CornerRadius = UDim.new(0, 4)}
	closeBtn.MouseButton1Click:Connect(closeNotification)

	local progressBg = create("Frame"){Parent = notif, Size = UDim2.new(1, -10, 0, 2), Position = UDim2.new(0, 5, 1, -5), BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0}
	create("UICorner"){Parent = progressBg, CornerRadius = UDim.new(1, 0)}
	local progress = create("Frame"){Parent = progressBg, Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = ACCENT_COLOR}
	create("UICorner"){Parent = progress, CornerRadius = UDim.new(1, 0)}

	table.insert(activeNotifications, 1, notif)

	local currentY = -8
	for i = 1, #activeNotifications do
		local frame = activeNotifications[i]
		if frame and frame.Parent then
			local h = frame.Size.Y.Offset
			local targetPos = UDim2.new(1, -8, 1, currentY)
			TweenService:Create(frame, TweenInfo.new(0.25), {Position = targetPos}):Play()
			currentY = currentY - h - 10
		end
	end

	task.spawn(function()
		local elapsed = 0
		while notif and notif.Parent and not isClosed do
			task.wait(0.05)
			elapsed = elapsed + 0.05
			progress.Size = UDim2.new(math.clamp(1 - (elapsed / dur), 0, 1), 0, 1, 0)
			if elapsed >= dur then break end
		end
		closeNotification()
	end)
end

local CONFIG_FOLDER = "TouchLine_Configs"
local CONFIG_FILE_EXT = ".json"

local function ensureConfigFolder()
	if isfolder and not isfolder(CONFIG_FOLDER) then
		pcall(function() makefolder(CONFIG_FOLDER) end)
	end
end

local function getConfigPath(configName)
	return CONFIG_FOLDER .. "/" .. configName .. CONFIG_FILE_EXT
end

function TouchLine:CreateWindow(title, size, position, options)
	local self = setmetatable({}, Window)
	options = options or {}
	self.IsPC = options.isPC or false
	self.IsMobile = not self.IsPC
	local windowSize = size or (self.IsPC and UDim2.fromOffset(480, 560) or UDim2.fromOffset(268, 420))
	local windowPos = position or UDim2.fromScale(0.5, 0.5)

	self.ScreenGui = registerThemeRoot(create("ScreenGui"){Name = "TouchLine_UI", Parent = RootGuiParent, ZIndexBehavior = Enum.ZIndexBehavior.Global, ResetOnSpawn = false, Enabled = false, IgnoreGuiInset = true})
	self.MainFrame = create("Frame"){Parent = self.ScreenGui, Size = windowSize, Position = windowPos, AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(12, 13, 22), BorderSizePixel = 0}
	create("UICorner"){Parent = self.MainFrame, CornerRadius = UDim.new(0, self.IsMobile and 12 or 14)}
	create("UIStroke"){Parent = self.MainFrame, Thickness = 1.2, Color = ACCENT_COLOR, Transparency = 0.15}

	local warningLabel = create("TextLabel"){Parent = self.MainFrame, Size = UDim2.new(1, 0, 0, self.IsMobile and 20 or 22), BackgroundColor3 = Color3.fromRGB(28, 18, 22), Text = "Profile icon → Config · Save · Reset", TextColor3 = Color3.fromRGB(255, 140, 150), Font = Enum.Font.GothamMedium, TextSize = self.IsMobile and 9 or 10, BorderSizePixel = 0, ZIndex = 10}
	create("UIStroke"){Parent = warningLabel, Thickness = 0.5, Color = Color3.fromRGB(200, 70, 80), Transparency = 0.4}

	local headerHeight = self.IsMobile and 52 or 58
	local Header = create("Frame"){Parent = self.MainFrame, Size = UDim2.new(1, 0, 0, headerHeight), Position = UDim2.new(0, 0, 0, warningLabel.Size.Y.Offset), BackgroundColor3 = Color3.fromRGB(16, 17, 28), BorderSizePixel = 0}
	create("UIStroke"){Parent = Header, Thickness = 0.5, Color = ACCENT_COLOR, Transparency = 0.35}

	local profileSize = 40
	local ProfileButton = create("TextButton"){Parent = Header, Size = UDim2.fromOffset(profileSize + 8, profileSize + 8), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0, Text = "", AutoButtonColor = false}
	create("UICorner"){Parent = ProfileButton, CornerRadius = UDim.new(1, 0)}
	create("UIStroke"){Parent = ProfileButton, Thickness = 0.5, Color = Color3.fromRGB(255, 50, 50)}
	create("ImageLabel"){Parent = ProfileButton, Size = UDim2.fromOffset(profileSize, profileSize), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1, Image = (Players.LocalPlayer and ("https://www.roblox.com/headshot-thumbnail/image?userId=" .. Players.LocalPlayer.UserId .. "&width=420&height=420&format=png") or "")}

	local Title = create("TextLabel"){
		Parent = Header,
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(60, 0),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.8
	}

	local TitleGradient = create("UIGradient"){
		Parent = Title,
		Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 0, 0))
		},
		Rotation = 45
	}

	Title.Text = self.IsMobile and "TOUCHLINE  FREE" or ("TOUCHLINE FREE  " .. fx.version)
	Title.TextTransparency = 0
	task.spawn(function()
		while Title.Parent do
			TitleGradient.Rotation = (TitleGradient.Rotation + 0.6) % 360
			task.wait(0.03)
		end
	end)

	local Sub = create("TextLabel"){
		Parent = Header,
		Size = UDim2.new(1, -80, 0, 14),
		Position = UDim2.fromOffset(60, headerHeight - 20),
		Text = "fx_scripts",
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(140, 148, 172),
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	Title.Size = UDim2.new(1, -80, 0, headerHeight - 18)
	Title.TextYAlignment = Enum.TextYAlignment.Bottom
	Title.Position = UDim2.fromOffset(60, 4)

	local dragging, dragStart, dragFrameStart = false, Vector2.zero, UDim2.zero
	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			dragFrameStart = self.MainFrame.Position
		end
	end)
	Header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			self.MainFrame.Position = UDim2.new(dragFrameStart.X.Scale, dragFrameStart.X.Offset + delta.X, dragFrameStart.Y.Scale, dragFrameStart.Y.Offset + delta.Y)
		end
	end)

	if self.IsPC then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == Enum.KeyCode.K then
				self.ScreenGui.Enabled = not self.ScreenGui.Enabled
				local sideBar = RootGuiParent:FindFirstChild("TouchLine_SideBar")
				if sideBar then sideBar.Visible = not self.ScreenGui.Enabled end
				TouchLine:CreateNotification("UI", self.ScreenGui.Enabled and "Shown" or "Hidden", 1.5)
			end
		end)
	end

	local toggleDot = create("Frame"){Parent = self.MainFrame, Name = "ToggleDot", Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -18, 0, 28), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 20}
	create("UICorner"){Parent = toggleDot, CornerRadius = UDim.new(1, 0)}
	create("UIStroke"){Parent = toggleDot, Thickness = 1, Color = ACCENT_COLOR}

	toggleDot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.ScreenGui.Enabled = not self.ScreenGui.Enabled
			local sideBar = RootGuiParent:FindFirstChild("TouchLine_SideBar")
			if sideBar then sideBar.Visible = not self.ScreenGui.Enabled end
			TouchLine:CreateNotification("UI", self.ScreenGui.Enabled and "Shown" or "Hidden", 1)
		end
	end)

	local tabContainerHeight = 40
	self.ContentFrame = create("Frame"){Name = "ContentFrame", Parent = self.MainFrame, Position = UDim2.new(0, 0, 0, headerHeight + 24), Size = UDim2.new(1, 0, 1, -headerHeight - 24), BackgroundTransparency = 1}

	self.TabContainer = create("ScrollingFrame"){Name = "TabContainer", Parent = self.ContentFrame, Size = UDim2.new(1, 0, 0, tabContainerHeight), BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0)}
	create("UIListLayout"){Parent = self.TabContainer, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center}
	create("UIPadding"){Parent = self.TabContainer, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}

	local tabLayout = self.TabContainer:FindFirstChildOfClass("UIListLayout")
	tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.TabContainer.CanvasSize = UDim2.new(0, tabLayout.AbsoluteContentSize.X + 16, 0, 0)
	end)

	self.PageContainer = create("Frame"){Name = "PageContainer", Parent = self.ContentFrame, Position = UDim2.new(0, 0, 0, tabContainerHeight), Size = UDim2.new(1, 0, 1, -tabContainerHeight), BackgroundTransparency = 1}
	self.Tabs, self.ActiveTab = {}, nil
	self._configToggleRefs, self._configSliderRefs, self._configKeybindRefs = {}, {}, {}
	self._sessionReady = false
	self._sessionSavePending = false

	self.ConfigPage = create("ScrollingFrame"){Name = "Config_Page", Parent = self.PageContainer, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ScrollBarThickness = 3}
	local cfgLayout = create("UIListLayout"){Parent = self.ConfigPage, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}
	create("UIPadding"){Parent = self.ConfigPage, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6)}
	cfgLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self.ConfigPage.CanvasSize = UDim2.new(0, 0, 0, cfgLayout.AbsoluteContentSize.Y + 12) end)

	create("TextLabel"){Parent = self.ConfigPage, Size = UDim2.new(1, 0, 0, 18), Text = "Config", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}

	local configRow = create("Frame"){Parent = self.ConfigPage, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1}
	create("UIListLayout"){Parent = configRow, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}

	local nameBox = create("TextBox"){Parent = configRow, Size = UDim2.new(1, -90, 1, 0), PlaceholderText = "Config name...", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(30, 30, 40), ClearTextOnFocus = true, LayoutOrder = 1, BorderSizePixel = 0}
	create("UICorner"){Parent = nameBox, CornerRadius = UDim.new(0, 5)}

	local saveButton = create("TextButton"){Parent = configRow, Size = UDim2.fromOffset(42, 26), Text = "Save", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(100, 150, 200), LayoutOrder = 2, BorderSizePixel = 0, AutoButtonColor = false}
	create("UICorner"){Parent = saveButton, CornerRadius = UDim.new(0, 5)}

	local loadButton = create("TextButton"){Parent = configRow, Size = UDim2.fromOffset(42, 26), Text = "Load", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(100, 180, 120), LayoutOrder = 3, BorderSizePixel = 0, AutoButtonColor = false}
	create("UICorner"){Parent = loadButton, CornerRadius = UDim.new(0, 5)}

	local deleteButton = create("TextButton"){Parent = self.ConfigPage, Size = UDim2.new(1, 0, 0, 26), Text = "Delete Config", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(200, 80, 80), BorderSizePixel = 0, AutoButtonColor = false}
	create("UICorner"){Parent = deleteButton, CornerRadius = UDim.new(0, 5)}

	local clearAllButton = create("TextButton"){Parent = self.ConfigPage, Size = UDim2.new(1, 0, 0, 26), Text = "Clear All Configs", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(160, 50, 50), BorderSizePixel = 0, AutoButtonColor = false}
	create("UICorner"){Parent = clearAllButton, CornerRadius = UDim.new(0, 5)}
	local resetDefaultsBtn = create("TextButton"){Parent = self.ConfigPage, Size = UDim2.new(1, 0, 0, 26), Text = "Reset All Settings To Defaults (OFF)", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(120, 60, 60), BorderSizePixel = 0, AutoButtonColor = false}
	create("UICorner"){Parent = resetDefaultsBtn, CornerRadius = UDim.new(0, 5)}
	resetDefaultsBtn.MouseButton1Click:Connect(function()
		pcall(function()
			if writefile then writefile("FakeTesting_AutoSave.json", "{}") end
			_G.__FakeTesting_autosave = nil
		end)
		MetaExploits.AirDribble = false
		MetaExploits.AutoKick = false
		MetaExploits.TPToBall = false
		MetaExploits.AutoAimGoal = false
		MetaExploits.CamLockBall = false
		MetaExploits.AlwaysMaxPower = false
		MetaExploits.AirDribblePlatform = false
		MetaExploits.AirBallESP = false
		VisualSettings.BallESP = false
		VisualSettings.PlayerESP = false
		pcall(destroyBallESP)
		pcall(destroyPlayerESP)
		MetaExploits.NewHitboxCurveBoost = false
		MetaExploits.CurveBoostEffect = false
		CurveSettings.AlwaysCurveRight = false
		CurveSettings.AlwaysCurveLeft = false
		CurveSettings.AlwaysGroundShot = false
		Settings.HitboxEnabled = true
		Settings.HitboxSize = 30
		Settings.ShowOutline = true
		mobileAirDribbleActive = false
		for id, ref in pairs(self._configToggleRefs or {}) do
			if ref and type(ref.Set) == "function" then pcall(function() ref:Set(false) end) end
		end
		TouchLine:CreateNotification("Config", "All settings reset OFF — re-open toggles you want", 2.5)
	end)

	local savedConfigsLabel = create("TextLabel"){Parent = self.ConfigPage, Size = UDim2.new(1, 0, 0, 18), Text = "Saved Configs:", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(180, 180, 200), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}

	local savedConfigsList = create("TextLabel"){Parent = self.ConfigPage, Size = UDim2.new(1, 0, 0, 60), Text = "None", Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Color3.fromRGB(150, 150, 170), BackgroundColor3 = Color3.fromRGB(25, 25, 35), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, BorderSizePixel = 0}
	create("UICorner"){Parent = savedConfigsList, CornerRadius = UDim.new(0, 5)}
	create("UIPadding"){Parent = savedConfigsList, PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4)}

	local function refreshConfigsList()
		if not listfiles then
			savedConfigsList.Text = "File system not available"
			return
		end
		ensureConfigFolder()
		local success, files = pcall(function() return listfiles(CONFIG_FOLDER) end)
		if success and files then
			local configNames = {}
			for _, filePath in ipairs(files) do
				local fileName = filePath:match("([^/\\]+)$") or filePath
				if fileName:sub(-#CONFIG_FILE_EXT) == CONFIG_FILE_EXT then
					table.insert(configNames, fileName:sub(1, -#CONFIG_FILE_EXT - 1))
				end
			end
			if #configNames > 0 then
				savedConfigsList.Text = table.concat(configNames, ", ")
			else
				savedConfigsList.Text = "No saved configs"
			end
		else
			savedConfigsList.Text = "Could not read configs"
		end
	end

	saveButton.MouseButton1Click:Connect(function()
		local configName = nameBox.Text
		if configName == "" or configName:match("^%s*$") then
			TouchLine:CreateNotification("Config", "Enter a config name!", 2)
			return
		end
		configName = configName:gsub("[^%w_-]", "_")
		if not writefile then
			TouchLine:CreateNotification("Config", "File system not available!", 2)
			return
		end
		ensureConfigFolder()
		local configData = self:CollectConfigData()
		local success, err = pcall(function()
			local jsonData = HttpService:JSONEncode(configData)
			writefile(getConfigPath(configName), jsonData)
			pcall(function() writefile(CONFIG_FOLDER .. "/__LAST_SESSION__.json", jsonData) end)
		end)
		if success then
			TouchLine:CreateNotification("Config", "Saved: " .. configName, 2)
			refreshConfigsList()
		else
			TouchLine:CreateNotification("Config", "Save failed: " .. tostring(err), 3)
		end
	end)

	loadButton.MouseButton1Click:Connect(function()
		local configName = nameBox.Text
		if configName == "" or configName:match("^%s*$") then
			TouchLine:CreateNotification("Config", "Enter a config name!", 2)
			return
		end
		configName = configName:gsub("[^%w_-]", "_")
		if not readfile or not isfile then
			TouchLine:CreateNotification("Config", "File system not available!", 2)
			return
		end
		local filePath = getConfigPath(configName)
		if not isfile(filePath) then
			TouchLine:CreateNotification("Config", "Config not found: " .. configName, 2)
			return
		end
		local success, configData = pcall(function()
			local jsonData = readfile(filePath)
			return HttpService:JSONDecode(jsonData)
		end)
		if not success or not configData then
			TouchLine:CreateNotification("Config", "Failed to load config!", 2)
			return
		end
		self:ApplyConfigData(configData)
		self:ScheduleSessionSave()
		TouchLine:CreateNotification("Config", "Loaded: " .. configName, 2)
	end)

	deleteButton.MouseButton1Click:Connect(function()
		local configName = nameBox.Text
		if configName == "" or configName:match("^%s*$") then
			TouchLine:CreateNotification("Config", "Enter a config name!", 2)
			return
		end
		configName = configName:gsub("[^%w_-]", "_")
		if not delfile or not isfile then
			TouchLine:CreateNotification("Config", "File system not available!", 2)
			return
		end
		local filePath = getConfigPath(configName)
		if not isfile(filePath) then
			TouchLine:CreateNotification("Config", "Config not found: " .. configName, 2)
			return
		end
		local success = pcall(function() delfile(filePath) end)
		if success then
			TouchLine:CreateNotification("Config", "Deleted: " .. configName, 2)
			refreshConfigsList()
		else
			TouchLine:CreateNotification("Config", "Delete failed!", 2)
		end
	end)

	clearAllButton.MouseButton1Click:Connect(function()
		if not listfiles or not delfile then
			TouchLine:CreateNotification("Config", "File system not available!", 2)
			return
		end
		ensureConfigFolder()
		local ok, files = pcall(function() return listfiles(CONFIG_FOLDER) end)
		local n = 0
		if ok and files then
			for _, filePath in ipairs(files) do
				local fileName = filePath:match("([^/\\]+)$") or filePath
				if fileName:sub(-#CONFIG_FILE_EXT) == CONFIG_FILE_EXT then
					if pcall(function() delfile(filePath) end) then n = n + 1 end
				end
			end
		end
		pcall(function()
			if isfile and isfile(CONFIG_FOLDER .. "/__LAST_SESSION__.json") then
				delfile(CONFIG_FOLDER .. "/__LAST_SESSION__.json")
			end
		end)
		refreshConfigsList()
		TouchLine:CreateNotification("Config", "Cleared " .. tostring(n) .. " config(s)", 2.5)
	end)

	ProfileButton.MouseButton1Click:Connect(function()
		self.ConfigPage.Visible = not self.ConfigPage.Visible
		if self.ActiveTab and self.ActiveTab.Page then
			self.ActiveTab.Page.Visible = not self.ConfigPage.Visible
		end
		if self.ConfigPage.Visible then
			refreshConfigsList()
		end
	end)

	task.spawn(function()
		task.wait(0.5)
		refreshConfigsList()
	end)

	return self
end

function Window:CollectConfigData()
	local configData = {
		toggles = {},
		sliders = {},
		keybinds = {},
		meta = {
			version = fx.version,
			savedAt = os.time(),
			playerName = LocalPlayer and LocalPlayer.Name or "Unknown"
		},
		visual = VisualSettings,
		curve = CurveSettings,
		metaExploits = MetaExploits,
		autoGK = {
			Enabled = AutoGK.Enabled,
			AutoDive = AutoGK.AutoDive,
			SaveRadius = AutoGK.SaveRadius,
			CooldownTime = AutoGK.CooldownTime
		},
		hitboxSettings = {
			HitboxEnabled = Settings.HitboxEnabled,
			HitboxSize = Settings.HitboxSize,
			ShowOutline = Settings.ShowOutline
		}
	}
	for id, toggle in pairs(self._configToggleRefs) do
		if toggle and toggle.Value ~= nil then
			configData.toggles[id] = toggle.Value
		end
	end
	for id, slider in pairs(self._configSliderRefs) do
		if slider and slider.Value ~= nil then
			configData.sliders[id] = slider.Value
		end
	end
	for id, keybind in pairs(self._configKeybindRefs) do
		if keybind and keybind.Value ~= nil then
			configData.keybinds[id] = keybind.Value
		end
	end
	return configData
end

function Window:ApplyConfigData(configData)
	if not configData then return end
	if configData.metaExploits then
		for k, v in pairs(configData.metaExploits) do
			if MetaExploits[k] ~= nil then
				MetaExploits[k] = v
			end
		end
	end
	if configData.visual then
		for k, v in pairs(configData.visual) do VisualSettings[k] = v end
	end
	if configData.curve then
		CurveSettings.AlwaysCurveRight = configData.curve.AlwaysCurveRight or false
		CurveSettings.AlwaysCurveLeft = configData.curve.AlwaysCurveLeft or false
		CurveSettings.AlwaysGroundShot = configData.curve.AlwaysGroundShot or false
	end
	if configData.autoGK then
		local a = configData.autoGK
		if a.SaveRadius then AutoGK.SaveRadius = a.SaveRadius end
		if a.CooldownTime then AutoGK.CooldownTime = a.CooldownTime end
		if a.Enabled ~= nil then AutoGK.Enabled = a.Enabled end
		if a.AutoDive ~= nil then AutoGK.AutoDive = a.AutoDive end
	end
	if configData.hitboxSettings then
		local h = configData.hitboxSettings
		Settings.HitboxEnabled = h.HitboxEnabled or true
		Settings.HitboxSize = h.HitboxSize or 30
		Settings.ShowOutline = h.ShowOutline or true
	end
	if configData.keybinds then
		for id, value in pairs(configData.keybinds) do
			if self._configKeybindRefs[id] and self._configKeybindRefs[id].Set then
				pcall(function() self._configKeybindRefs[id]:Set(value) end)
			end
		end
	end
	if configData.sliders then
		for id, value in pairs(configData.sliders) do
			if self._configSliderRefs[id] and self._configSliderRefs[id].Set then
				pcall(function() self._configSliderRefs[id]:Set(value) end)
			end
		end
	end
	if configData.toggles then
		for id, value in pairs(configData.toggles) do
			if self._configToggleRefs[id] and self._configToggleRefs[id].Set then
				pcall(function() self._configToggleRefs[id]:Set(value) end)
			end
		end
	end
end

function Window:ScheduleSessionSave()
	if not writefile or not self._sessionReady or self._sessionSavePending then return end
	self._sessionSavePending = true
	task.delay(1.5, function()
		self._sessionSavePending = false
		pcall(function()
			ensureConfigFolder()
			writefile(CONFIG_FOLDER .. "/__LAST_SESSION__.json", HttpService:JSONEncode(self:CollectConfigData()))
		end)
	end)
end

function Window:AddTab(name)
	local tab = setmetatable({}, Tab)
	tab.ParentWindow = self
	local isPremium = tostring(name):lower():find("premium") or tostring(name):find("★")
	local btnBg = isPremium and Color3.fromRGB(45, 38, 10) or Color3.fromRGB(30, 30, 40)
	local btnText = isPremium and PREMIUM_GOLD or Color3.fromRGB(150, 150, 170)
	tab.Button = create("TextButton"){Name = tostring(name), Parent = self.TabContainer, Size = UDim2.fromOffset(110, 32), BackgroundColor3 = btnBg, AutoButtonColor = false, Font = Enum.Font.GothamSemibold, Text = tostring(name), TextSize = 13, TextColor3 = btnText, BorderSizePixel = 0}
	create("UICorner"){Parent = tab.Button, CornerRadius = UDim.new(0, 6)}
	if isPremium then
		create("UIStroke"){Parent = tab.Button, Thickness = 0.5, Color = PREMIUM_GOLD}
	end

	tab.Page = create("ScrollingFrame"){Name = tostring(name) .. "_Page", Parent = self.PageContainer, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0)}
	local layout = create("UIListLayout"){Parent = tab.Page, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}
	create("UIPadding"){Parent = tab.Page, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8)}
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() tab.Page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16) end)

	tab.Button.MouseButton1Click:Connect(function()
		if self.ActiveTab then
			self.ActiveTab.Button.BackgroundColor3 = (self.ActiveTab.Button.Name:lower():find("premium") and Color3.fromRGB(45,38,10) or Color3.fromRGB(30, 30, 40))
			self.ActiveTab.Button.TextColor3 = (self.ActiveTab.Button.Name:lower():find("premium") and PREMIUM_GOLD or Color3.fromRGB(150, 150, 170))
			self.ActiveTab.Page.Visible = false
		end
		self.ConfigPage.Visible = false
		tab.Button.BackgroundColor3 = isPremium and Color3.fromRGB(70, 58, 15) or ACCENT_COLOR
		tab.Button.TextColor3 = isPremium and PREMIUM_GOLD or Color3.new(1, 1, 1)
		tab.Page.Visible = true
		self.ActiveTab = tab
	end)

	table.insert(self.Tabs, tab)
	if not self.ActiveTab then
		tab.Button.BackgroundColor3 = isPremium and Color3.fromRGB(70, 58, 15) or ACCENT_COLOR
		tab.Button.TextColor3 = isPremium and PREMIUM_GOLD or Color3.new(1, 1, 1)
		tab.Page.Visible = true
		self.ActiveTab = tab
	end

	return tab
end

function Tab:AddLabel(text, textColor)
	create("TextLabel"){Parent = self.Page, Size = UDim2.new(1, 0, 0, 20), Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = textColor or Color3.new(1, 1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}
end

function Tab:AddToggle(name, defaultValue, callback, id)
	local toggle = {Value = defaultValue or false}
	local container = create("Frame"){Parent = self.Page, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Color3.fromRGB(20, 20, 30), BorderSizePixel = 0}
	create("UICorner"){Parent = container, CornerRadius = UDim.new(0, 6)}
	create("UIStroke"){Parent = container, Thickness = 0.5, Color = Color3.fromRGB(60, 60, 80)}
	create("TextLabel"){Parent = container, Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(10, 0), Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}
	local switch = create("Frame"){Parent = container, Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -45, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0}
	create("UICorner"){Parent = switch, CornerRadius = UDim.new(1, 0)}
	local star_mask = create("Frame"){Parent = switch, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.fromRGB(200, 200, 200), BorderSizePixel = 0}
	create("UICorner"){Parent = star_mask, CornerRadius = UDim.new(1, 0)}

	local win = self.ParentWindow
	function toggle:Set(val)
		toggle.Value = val
		if val then
			switch.BackgroundColor3 = ACCENT_COLOR
			TweenService:Create(star_mask, TweenInfo.new(0.2), {Position = UDim2.fromOffset(20, 2)}):Play()
		else
			switch.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			TweenService:Create(star_mask, TweenInfo.new(0.2), {Position = UDim2.fromOffset(2, 2)}):Play()
		end
		if callback then callback(val) end
		if win then win:ScheduleSessionSave() end
	end

	switch.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			toggle:Set(not toggle.Value)
		end
	end)

	toggle:Set(defaultValue or false)
	if id then self.ParentWindow._configToggleRefs[id] = toggle end
	return toggle
end

function Tab:AddSlider(name, min, max, defaultValue, callback, id)
	local slider = {Value = defaultValue or min}
	local container = create("Frame"){Parent = self.Page, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = Color3.fromRGB(20, 20, 30), BorderSizePixel = 0}
	create("UICorner"){Parent = container, CornerRadius = UDim.new(0, 6)}
	create("UIStroke"){Parent = container, Thickness = 0.5, Color = Color3.fromRGB(60, 60, 80)}
	create("TextLabel"){Parent = container, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(10, 4), Text = name, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}
	local valueLabel = create("TextLabel"){Parent = container, Size = UDim2.fromOffset(50, 18), Position = UDim2.new(1, -55, 0, 4), Text = tostring(defaultValue or min), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = ACCENT_COLOR, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Right}
	local track = create("Frame"){Parent = container, Size = UDim2.new(1, -20, 0, 4), Position = UDim2.new(0, 10, 1, -14), BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0}
	create("UICorner"){Parent = track, CornerRadius = UDim.new(1, 0)}
	local fill = create("Frame"){Parent = track, Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT_COLOR, BorderSizePixel = 0}
	create("UICorner"){Parent = fill, CornerRadius = UDim.new(1, 0)}
	local thumb = create("Frame"){Parent = track, Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, -6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}
	create("UICorner"){Parent = thumb, CornerRadius = UDim.new(1, 0)}

	local win = self.ParentWindow
	function slider:Set(val)
		val = math.clamp(val, min, max)
		slider.Value = val
		valueLabel.Text = tostring(math.floor(val))
		local percent = (val - min) / (max - min)
		fill.Size = UDim2.new(percent, 0, 1, 0)
		thumb.Position = UDim2.new(percent, -6, 0.5, 0)
		if callback then callback(val) end
		if win then win:ScheduleSessionSave() end
	end

	local dragging = false
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local function update(input)
				local pos = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
				slider:Set(min + (max - min) * pos)
			end
			update(i)
		end
	end)
	track.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local pos = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			slider:Set(min + (max - min) * pos)
		end
	end)

	slider:Set(defaultValue or min)
	if id then self.ParentWindow._configSliderRefs[id] = slider end
	return slider
end

function Tab:AddButton(name, callback)
	local button = create("TextButton"){Parent = self.Page, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0, Text = name, Font = Enum.Font.GothamSemibold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false}
	create("UICorner"){Parent = button, CornerRadius = UDim.new(0, 6)}
	create("UIStroke"){Parent = button, Thickness = 0.5, Color = ACCENT_COLOR}
	button.MouseButton1Click:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = ACCENT_COLOR}):Play()
		task.wait(0.15)
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
		if callback then callback() end
	end)
	return button
end

function Tab:AddKeybind(name, defaultKey, callback, id)
	local keybind = {Value = defaultKey or "None"}
	local listening = false
	local container = create("Frame"){Parent = self.Page, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Color3.fromRGB(20, 20, 30), BorderSizePixel = 0}
	create("UICorner"){Parent = container, CornerRadius = UDim.new(0, 6)}
	create("UIStroke"){Parent = container, Thickness = 0.5, Color = Color3.fromRGB(60, 60, 80)}
	create("TextLabel"){Parent = container, Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(10, 0), Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}
	local keyButton = create("TextButton"){Parent = container, Size = UDim2.fromOffset(80, 24), Position = UDim2.new(1, -85, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0, Text = defaultKey or "None", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false}
	create("UICorner"){Parent = keyButton, CornerRadius = UDim.new(0, 5)}

	local win = self.ParentWindow
	function keybind:Set(val)
		keybind.Value = val
		keyButton.Text = val
		if callback then callback(val) end
		if win then win:ScheduleSessionSave() end
	end

	keyButton.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		keyButton.Text = "..."
		keyButton.BackgroundColor3 = ACCENT_COLOR
		local conn
		conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			local key
			if input.UserInputType == Enum.UserInputType.Keyboard then
				key = input.KeyCode.Name
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				key = "MouseButton1"
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				key = "MouseButton2"
			end
			if key then
				keybind:Set(key)
				keyButton.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
				listening = false
				conn:Disconnect()
			end
		end)
	end)

	if id then self.ParentWindow._configKeybindRefs[id] = keybind end
	return keybind
end

function Tab:AddDropdown(name, options, defaultValue, callback, id, optionColors)
	local dropdown = {Value = defaultValue or options[1] or "None", IsOpen = false}
	optionColors = optionColors or {}
	local function optColor(opt)
		return optionColors[opt] or Color3.fromRGB(200, 200, 200)
	end
	local container = create("Frame"){Parent = self.Page, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(20, 20, 30), BorderSizePixel = 0, ClipsDescendants = true}
	create("UICorner"){Parent = container, CornerRadius = UDim.new(0, 6)}
	create("UIStroke"){Parent = container, Thickness = 0.5, Color = Color3.fromRGB(60, 60, 80)}
	create("TextLabel"){Parent = container, Size = UDim2.new(1, -100, 0, 32), Position = UDim2.fromOffset(10, 0), Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left}
	local selectedButton = create("TextButton"){Parent = container, Size = UDim2.fromOffset(110, 26), Position = UDim2.new(1, -115, 0, 3), BackgroundColor3 = Color3.fromRGB(40, 40, 50), BorderSizePixel = 0, Text = dropdown.Value, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = optColor(dropdown.Value), AutoButtonColor = false}
	create("UICorner"){Parent = selectedButton, CornerRadius = UDim.new(0, 5)}

	local optionsList = create("Frame"){Parent = container, Size = UDim2.new(1, -10, 0, 0), Position = UDim2.fromOffset(5, 34), BackgroundTransparency = 1}
	create("UIListLayout"){Parent = optionsList, Padding = UDim.new(0, 2)}

	local win = self.ParentWindow
	function dropdown:Set(val)
		dropdown.Value = val
		selectedButton.Text = val
		selectedButton.TextColor3 = optColor(val)
		if callback then callback(val) end
		if win then win:ScheduleSessionSave() end
	end

	for _, opt in ipairs(options) do
		local c = optColor(opt)
		local optButton = create("TextButton"){Parent = optionsList, Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.fromRGB(35, 35, 45), BorderSizePixel = 0, Text = opt, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = c, AutoButtonColor = false}
		create("UICorner"){Parent = optButton, CornerRadius = UDim.new(0, 4)}
		create("UIStroke"){Parent = optButton, Thickness = 1, Color = c, Transparency = 0.55}
		optButton.MouseButton1Click:Connect(function()
			dropdown:Set(opt)
			container.Size = UDim2.new(1, 0, 0, 36)
			dropdown.IsOpen = false
		end)
	end

	selectedButton.MouseButton1Click:Connect(function()
		dropdown.IsOpen = not dropdown.IsOpen
		if dropdown.IsOpen then
			local height = 36 + (#options * 26) + 4
			container.Size = UDim2.new(1, 0, 0, height)
		else
			container.Size = UDim2.new(1, 0, 0, 36)
		end
	end)

	if id then self.ParentWindow._configToggleRefs[id] = dropdown end
	return dropdown
end

function Tab:AddPremiumTeaser(name)
	local container = create("Frame"){Parent = self.Page, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = Color3.fromRGB(32, 27, 10), BorderSizePixel = 0}
	create("UICorner"){Parent = container, CornerRadius = UDim.new(0, 6)}
	create("UIStroke"){Parent = container, Thickness = 0.5, Color = PREMIUM_GOLD, Transparency = 0.35}
	create("TextLabel"){Parent = container, Size = UDim2.fromOffset(18, 32), Position = UDim2.fromOffset(8, 0), Text = "★", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = PREMIUM_GOLD, BackgroundTransparency = 1}
	create("TextLabel"){Parent = container, Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(28, 0), Text = name, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = Color3.fromRGB(235, 220, 170), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}
	local switch = create("Frame"){Parent = container, Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -45, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(45, 38, 14), BorderSizePixel = 0}
	create("UICorner"){Parent = switch, CornerRadius = UDim.new(1, 0)}
	create("UIStroke"){Parent = switch, Thickness = 0.5, Color = PREMIUM_GOLD, Transparency = 0.5}
	local knob = create("TextLabel"){Parent = switch, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = PREMIUM_GOLD, BorderSizePixel = 0, Text = "X", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(40, 32, 5)}
	create("UICorner"){Parent = knob, CornerRadius = UDim.new(1, 0)}

	local shaking = false
	local function denied()
		TouchLine:CreateNotification("Premium Required", name .. " is premium only. Open the Premium tab and copy the loader to unlock it free with a key!", 4)
		if shaking then return end
		shaking = true
		task.spawn(function()
			local origPos = container.Position
			for i = 1, 4 do
				container.Position = origPos + UDim2.fromOffset(i % 2 == 0 and 4 or -4, 0)
				task.wait(0.04)
			end
			container.Position = origPos
			TweenService:Create(knob, TweenInfo.new(0.15), {Position = UDim2.fromOffset(20, 2)}):Play()
			task.wait(0.25)
			TweenService:Create(knob, TweenInfo.new(0.2), {Position = UDim2.fromOffset(2, 2)}):Play()
			shaking = false
		end)
	end

	container.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			denied()
		end
	end)
	return container
end

-- Mobile: hook the game's Charge button and Tackle button directly
local function HookMobileButtons()
	if not IS_MOBILE then return end
	local pGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not pGui then return end
	local main = pGui:FindFirstChild("Main")
	if not main then return end
	local gameGui = main:FindFirstChild("Game")
	if not gameGui then return end
	local mobile = gameGui:FindFirstChild("Mobile")
	if not mobile then return end

	-- Charge button
	local chargeBtn = mobile:FindFirstChild("Charge")
	if chargeBtn and chargeBtn:IsA("GuiButton") then
		chargeBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				TouchModule.ChargeAction()
			end
		end)
		chargeBtn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				TouchModule.ReleaseAction()
			end
		end)
	end

	-- Tackle button
	local tackleBtn = mobile:FindFirstChild("Tackle")
	if tackleBtn and tackleBtn:IsA("GuiButton") then
		tackleBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				isTackling = true
				cancelActiveDetection()
			end
		end)
		tackleBtn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				isTackling = false
			end
		end)
	end
end

HookMobileButtons()

local isCompact = IS_MOBILE
local window = TouchLine:CreateWindow(isCompact and "TouchLine Free" or "TouchLine Free V8.7", nil, nil, {isPC = not isCompact})

local MainTab = window:AddTab("Main")
local VisualTab = window:AddTab("Visual")

MainTab:AddLabel("■ Hitbox", ACCENT_COLOR)
MainTab:AddToggle("Hitbox Enabled", true, function(v) Settings.HitboxEnabled = v end, "HitboxEnabled")
MainTab:AddSlider("Hitbox Size", 5, 50, 30, function(v) Settings.HitboxSize = v end, "HitboxSize")
MainTab:AddToggle("PReview", true, function(v) Settings.ShowOutline = v end, "ShowOutline")
MainTab:AddToggle("use theme preview", true, function(v) Settings.HitboxUseTheme = v end, "HitboxUseTheme")
MainTab:AddSlider("Preview Opacity", 0, 0.9, 0.2, function(v) Settings.OutlineTransparency = 1 - v end, "PreviewOpacity")
MainTab:AddKeybind("Hitbox Toggle Key", "None", function(k) MetaExploits.HitboxKeybind = k end, "HitboxKeybind")
MainTab:AddSlider("Touch Bursts (anti double-touch)", 1, 6, 4, function(v) TouchGuard.bursts = math.floor(v) end, "TouchBursts")
MainTab:AddSlider("Touch Cooldown (s)", 0.03, 0.4, 0.09, function(v) TouchGuard.minGap = v end, "TouchMinGap")

MainTab:AddLabel("■ Air Dribble", AIR_SECTION_COLOR)
MainTab:AddToggle("Air Dribble Lift", false, function(v)
	MetaExploits.AirDribble = v
	if not v then
		airDribbleKeyHeld = false
		airDribbleMouseHeld = false
		mobileAirDribbleActive = false
	end
end, "AirDribble")
MainTab:AddKeybind("Air Lift Key", "None", function(k) MetaExploits.AirDribbleKeybind = k end, "AirDribbleKeybind")
MainTab:AddToggle("Air Surface under ball", false, function(v) MetaExploits.AirDribblePlatform = v end, "AirDribblePlatform")
MainTab:AddToggle("Air Ball ESP", false, function(v) MetaExploits.AirBallESP = v end, "AirBallESP")
MainTab:AddSlider("Lift Height", 1, 12, 6, function(v) MetaExploits.AirDribbleHeight = v end, "AirDribbleHeight")
MainTab:AddSlider("Lift Forward", 0, 8, 2, function(v) MetaExploits.AirDribbleForward = v end, "AirDribbleForward")
MainTab:AddSlider("Lift Power", 0.15, 0.4, 0.28, function(v) MetaExploits.AirDribblePower = v end, "AirDribblePower")

MainTab:AddLabel("■ Auto Kick", ACCENT_COLOR)
MainTab:AddToggle("Auto Kick", false, function(v) MetaExploits.AutoKick = v end, "AutoKick")
MainTab:AddKeybind("Auto Kick Key", "None", function(k) MetaExploits.AutoKickKeybind = k end, "AutoKickKeybind")
MainTab:AddSlider("Auto Kick Delay", 0.1, 2, 0.2, function(v) MetaExploits.AutoKickDelay = v end, "AutoKickDelay")
MainTab:AddSlider("Auto Kick Power", 0.2, 1, 0.9, function(v) MetaExploits.AutoKickPower = v end, "AutoKickPower")
MainTab:AddSlider("Auto Kick Height", 0, 25, 10, function(v) MetaExploits.AutoKickHeight = v end, "AutoKickHeight")
MainTab:AddToggle("Auto Kick to Goal", false, function(v) MetaExploits.AutoKickTargetGoal = v end, "AutoKickTargetGoal")

MainTab:AddLabel("■ Power", ACCENT_COLOR)
MainTab:AddDropdown("Power Mode", {"Normal", "Low", "High"}, "Normal", function(v) MetaExploits.PowerMode = v end, "PowerMode")
MainTab:AddToggle("Always Max Power", false, function(v) MetaExploits.AlwaysMaxPower = v end, "AlwaysMaxPower")

MainTab:AddLabel("■ Goalkeeper", ACCENT_COLOR)
MainTab:AddToggle("Auto Save Hitbox", false, function(v) AutoGK.Enabled = v end, "AutoGK")
MainTab:AddSlider("GK Radius", 5, 25, 12, function(v) AutoGK.SaveRadius = v end, "GKRadius")
MainTab:AddSlider("GK Cooldown", 0.5, 5, 2, function(v) AutoGK.CooldownTime = v end, "GKCooldown")

MainTab:AddLabel("■ Curves", Color3.fromRGB(180, 120, 255))
MainTab:AddToggle("Always Curve Right (E)", false, function(v) CurveSettings.AlwaysCurveRight = v end, "CurveRight")
MainTab:AddToggle("Always Curve Left (Q)", false, function(v) CurveSettings.AlwaysCurveLeft = v end, "CurveLeft")
MainTab:AddToggle("Always Ground Shot (C)", false, function(v) CurveSettings.AlwaysGroundShot = v end, "GroundShot")

MainTab:AddLabel("■ Useless", ACCENT_COLOR)
if isCompact then
	MainTab:AddButton("TP to Ball (once)", function()
		local ball = findBall()
		if ball and HumanoidRootPart then
			HumanoidRootPart.CFrame = CFrame.new(ball.Position + Vector3.new(0, 3, 0))
			TouchLine:CreateNotification("TP", "Teleported!", 1.2)
		end
	end)
end
MainTab:AddToggle("TP to Ball (loop)", false, function(v) MetaExploits.TPToBall = v end, "TPToBall")
MainTab:AddToggle("Auto Aim Goal", false, function(v) MetaExploits.AutoAimGoal = v end, "AutoAimGoal")
MainTab:AddToggle("Cam Lock Ball", false, function(v) MetaExploits.CamLockBall = v end, "CamLockBall")
MainTab:AddToggle("Anti Vote Kick", false, function(v)
	MetaExploits.AntiVoteKick = v
	setAntiVoteKick(v)
end, "AntiVoteKick")

VisualTab:AddLabel("Theme", ACCENT_COLOR)
VisualTab:AddDropdown("Accent Theme", themeNames(), "Cyan", function(v)
	applyTheme(v)
	TouchLine:CreateNotification("Theme", v .. " applied", 1.4)
end, "AccentTheme")
VisualTab:AddButton("Randomise Theme", function()
	local pick = THEMES[math.random(1, #THEMES)]
	applyTheme(pick.name)
	TouchLine:CreateNotification("Theme", pick.name, 1.4)
end)

VisualTab:AddLabel("Visuals", ACCENT_COLOR)
VisualTab:AddToggle("Ball ESP", false, function(v)
	VisualSettings.BallESP = v
	if not v then destroyBallESP() end
end, "BallESP")
VisualTab:AddToggle("Player ESP", false, function(v)
	VisualSettings.PlayerESP = v
	if not v then destroyPlayerESP() end
end, "PlayerESP")
VisualTab:AddToggle("FPS Boost", false, function(v)
	VisualSettings.FPSBoost = v
	if v then
		pcall(function()
			for _, obj in pairs(game:GetDescendants()) do
				if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
					obj.Enabled = false
				end
			end
		end)
		TouchLine:CreateNotification("FPS Boost", "Enabled", 2)
	end
end, "FPSBoost")

local PremiumTab = window:AddTab("Premium ★")

PremiumTab:AddLabel("Get Premium Script for FREE with Key")

PremiumTab:AddButton("Copy Premium Loader", function()
	if setclipboard then setclipboard(PREMIUM_LOADER) end
	TouchLine:CreateNotification("Premium", "Loader copied! Paste and execute in your executor to get the premium script for free with key.", 5)
end)

PremiumTab:AddLabel("New in the Premium update", PREMIUM_GOLD)
PremiumTab:AddPremiumTeaser("Auto Dribble[Beta..Comming]")
PremiumTab:AddPremiumTeaser("Auto tackle")
PremiumTab:AddPremiumTeaser("Shot Controller  power + height adjuster")
PremiumTab:AddPremiumTeaser("Aims inside the frame, no more balloons")
PremiumTab:AddPremiumTeaser("Smart Auto Pass  reads passing lanes")
PremiumTab:AddPremiumTeaser("Skill Repeat  detects and re-fires skills")
PremiumTab:AddPremiumTeaser("Match-End Server Finder  Discord webhook")

PremiumTab:AddPremiumTeaser("More hitbox size + x,y,z + ")
PremiumTab:AddPremiumTeaser("Config profiles  save / load / autoload")

PremiumTab:AddLabel("Also included", PREMIUM_GOLD)
PremiumTab:AddPremiumTeaser("MAGNET Dribble (auto-steer to goal)")
PremiumTab:AddPremiumTeaser("Magnet Follows Camera")
PremiumTab:AddPremiumTeaser("Moss (Special Cross Reach)")
PremiumTab:AddPremiumTeaser("Auto Moss Shot (rocket to goal)")
PremiumTab:AddPremiumTeaser("Perfect Aimbot (when near goal)")
PremiumTab:AddPremiumTeaser("Sky Launcher kick")
PremiumTab:AddPremiumTeaser("Smart Aim (avoid goalie)")
PremiumTab:AddPremiumTeaser("First Touch Steal (auto trap)")
PremiumTab:AddPremiumTeaser("Ball Trajectory Predictor")
PremiumTab:AddPremiumTeaser("Auto GK  dive, rush, line positioning")
PremiumTab:AddPremiumTeaser("Auto Celebrate on goal")
PremiumTab:AddPremiumTeaser("Votekick spy + auto vote guard")

PremiumTab:AddLabel("Copy the loader above to unlock all of this free with a key.")

pcall(function()
	local pb = PremiumTab.Button
	if pb then
		pb.BackgroundColor3 = Color3.fromRGB(55, 45, 12)
		pb.TextColor3 = PREMIUM_GOLD
		for _, child in ipairs(pb:GetChildren()) do
			if child:IsA("UIStroke") then child.Thickness = 0.5 end
		end
	end
end)

local sideBarGui = registerThemeRoot(create("ScreenGui"){Name = "TouchLine_SideBar", Parent = RootGuiParent, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global, Visible = true})
local sideBarBtn = create("TextButton"){Parent = sideBarGui, Size = UDim2.fromOffset(38, 70), Position = UDim2.new(0, 4, 0.45, -35), BackgroundColor3 = Color3.fromRGB(20, 20, 30), BorderSizePixel = 0, Text = "▶", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false}
create("UICorner"){Parent = sideBarBtn, CornerRadius = UDim.new(0, 8)}
create("UIStroke"){Parent = sideBarBtn, Thickness = 0.5, Color = ACCENT_COLOR}
sideBarBtn.Draggable = true

sideBarBtn.MouseButton1Click:Connect(function()
	window.ScreenGui.Enabled = true
	sideBarGui.Visible = false
	TouchLine:CreateNotification("UI", "Opened", 1)
end)

window.ScreenGui.Enabled = true

local function autoLoadLastConfig()
	if not readfile or not isfile then
		window._sessionReady = true
		return
	end
	ensureConfigFolder()
	local lastPath = CONFIG_FOLDER .. "/__LAST_SESSION__.json"
	if not isfile(lastPath) then
		window._sessionReady = true
		return
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(lastPath))
	end)
	window._sessionReady = true
	if ok and data then
		pcall(function() window:ApplyConfigData(data) end)
		TouchLine:CreateNotification("Config", "Auto-restored your last settings", 2.5)
	end
end

task.spawn(function()
	task.wait(1.2)
	autoLoadLastConfig()
end)

task.spawn(function()
	task.wait(5)
	if not discordNotifActive and (tick() - lastDiscordShown > 300) then
		discordNotifActive = true
		getDiscordLink(function(link)
			if link and link:find("discord") then
				TouchLine:CreateNotification("Discord", "Join our community!", 5, {showCopy = true, copyText = link, isDiscord = true})
				lastDiscordShown = tick()
				task.wait(3)
				discordNotifActive = false
			end
		end)
	end
end)

pcall(function()
	local env = (getgenv and getgenv()) or _G
	env.TouchLine_Cleanup = function()
		SCRIPT_KILLED = true
		autoTPKickerActive = false
		AutoGK.Enabled = false
		MetaExploits.AutoTPKickerLoop = false
		MetaExploits.AirDribble = false
		MetaExploits.CamLockBall = false
		airDribbleKeyHeld = false
		airDribbleMouseHeld = false
		mobileAirDribbleActive = false
		for _, conn in ipairs(_cleanupConnections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(_cleanupConnections)

		pcall(function()
			if Camera and Camera.CameraType == Enum.CameraType.Scriptable then
				Camera.CameraType = Enum.CameraType.Custom
			end
		end)

		if hitboxPreviewPart and hitboxPreviewPart.Parent then pcall(function() hitboxPreviewPart:Destroy() end) end
		hitboxPreviewPart = nil
		destroyTrackedParts()
		destroyExistingUI()
	end
end)

TouchLine:CreateNotification("TouchLine " .. fx.version, "premuim gone be paid only buy it before it epensive. ", 6)
task.delay(7, function()
	local items = table.concat(UPDATE_LOG.items or {}, " | ")
	TouchLine:CreateNotification("UPDATE LOG " .. (UPDATE_LOG.version or fx.version), items, 8)
end)

return TouchLine
