---@file Navigation.lua
--- Navigation, targeting, and movement functions extracted from init.lua.

---@type Mq
local mq = require("mq")
require("inc.Global")
---@type Note
local Note = require("ext.Note")
local State = require("core.State")

local workSet = State.workSet

local TLO = mq.TLO
local Me = TLO.Me
local Target = TLO.Target
local Spawn = TLO.Spawn
local Ground = TLO.Ground
local Cursor = TLO.Cursor
local Navigation = TLO.Navigation
local MoveTo = TLO.MoveTo
local Math = TLO.Math

local Nav = {}

--- Callback slots (set by init.lua to wire up cross-module dependencies)
Nav._getNextXTarget       = nil  -- function(): xtarget|nil
Nav._findAndKill          = nil  -- function(id, opts?): void
Nav._checkSwiftness       = nil  -- function(): void
Nav._checkSelfBuffs       = nil  -- function(): void
Nav._checkMerc            = nil  -- function(): void
Nav._checkPet             = nil  -- function(): void
Nav._checkAllAccessNag    = nil  -- function(): void
Nav._whereAmI             = nil  -- function(): void
Nav._amIDead              = nil  -- function(): boolean
Nav._handleRespawnRecovery = nil -- function(): void  (throws RESPAWN_RESTART_SIGNAL)

--- Target a spawn object and wait for targeting to confirm.
---@param spawn spawn
function Nav.targetSpawn(spawn)
	FunctionEnter()

	if (spawn.ID() > 0) then
		spawn.DoTarget()

		Delay(2000, function()
			return Target.ID() == spawn.ID()
		end)

		Delay(250)
	end

	FunctionDepart()
end

--- Target a spawn by numeric ID.
---@param targetId integer
function Nav.targetSpawnById(targetId)
	FunctionEnter()
	PrintDebugMessage(DebuggingRanks.Detail, "Target spawn: \ay%s", targetId)

	local spawn = Spawn("id " .. targetId)
	Nav.targetSpawn(spawn)

	FunctionDepart()
end

--- Target a spawn by name string.
---@param targetName string
function Nav.targetSpawnByName(targetName)
	FunctionEnter()
	PrintDebugMessage(DebuggingRanks.Detail, "Target spawn: \ay%s", targetName)

	local spawn = Spawn(targetName)
	Nav.targetSpawn(spawn)

	FunctionDepart()
end

--- Simple location navigation with no combat response and no xtarget handling.
--- Used for post-respawn and pre-combat movement.
---@param y number
---@param x number
---@param z number
function Nav.basicNavToLoc(y, x, z)
	FunctionEnter()

	local destLocYXZ = string.format("%s,%s,%s", y, x, z)
	local destLocYX  = string.format("%s,%s", y, x)

	local hasPathYXZ = Navigation.PathExists(string.format("locyxz %s", destLocYXZ))
	local hasPathYX  = Navigation.PathExists(string.format("loc %s", destLocYX))

	if hasPathYXZ or hasPathYX then
		PrintDebugMessage(DebuggingRanks.Function, "Nav to Y: %s, X: %s, Z: %s (PathYXZ=%s PathYX=%s)", y, x, z, hasPathYXZ, hasPathYX)

		while (Math.Distance(destLocYXZ)() > 15) do
			Nav._checkSwiftness()
			Nav._checkSelfBuffs()
			Nav._whereAmI()

			if Navigation.Active() then
				Delay(100)
			else
				if hasPathYXZ then
					mq.cmdf("/squelch /nav locyxz %s %s %s", y, x, z)
				else
					mq.cmdf("/squelch /nav loc %s %s", y, x)
				end
			end
		end

		if Navigation.Active() then mq.cmd.nav("stop") end
	end

	FunctionDepart()
end

--- Simple spawn navigation with no xtarget interruption.
--- Used for blessing/quest NPCs and post-respawn pathing.
---@param spawnId integer
function Nav.basicNavToSpawn(spawnId)
	FunctionEnter()
	PrintDebugMessage(DebuggingRanks.Function, "spawnId: %s", spawnId)

	Nav._checkSwiftness()
	Nav._checkSelfBuffs()

	local navSpawn = Spawn("id " .. spawnId)

	if (navSpawn.ID() == 0 or navSpawn.Type() == "Corpse" or navSpawn.Type() == nil) then
		FunctionDepart()
		return
	end

	mq.cmdf("/squelch /nav id %s", spawnId)
	SetChatTitle("Navigating to add " .. navSpawn.CleanName())

	while (navSpawn.ID() > 0 and navSpawn.Distance() > 30) do
		Delay(100)

		if (not Navigation.Active()) then
			mq.cmdf("/squelch /nav id %s", spawnId)
		end
	end

	if (Navigation.Active()) then
		mq.cmd.nav("stop")
	end

	FunctionDepart()
end

--- Navigate to the spider hall entrance (requires a keypress to cross the threshold).
function Nav.gotoSpiderHall()
	FunctionEnter(DebuggingRanks.Task)

	Nav.basicNavToLoc(-670, -374, -65)
	mq.cmd.face("loc -595,-373,-40")
	mq.cmd.keypress("forward hold")
	Delay(1000)
	mq.cmd.keypress("forward")

	FunctionDepart(DebuggingRanks.Task)
end

--- Navigate to a spawn while handling xtargets encountered en route.
--- Calls combatRoutine(id) for any xtarget that appears during navigation.
--- Returns early (via _handleRespawnRecovery which throws) if death is detected.
---@param spawnId integer
---@param combatRoutine? fun(spawnId: integer)
function Nav.navToSpawn(spawnId, combatRoutine)
	FunctionEnter()
	PrintDebugMessage(DebuggingRanks.Function, "spawnId: %s", spawnId)

	Nav._checkSwiftness()
	Nav._checkSelfBuffs()

	local navSpawn = Spawn("id " .. spawnId)

	if (navSpawn.ID() == 0 or navSpawn.Type() == "Corpse" or navSpawn.Type() == nil) then
		FunctionDepart()
		return
	end

	mq.cmdf("/squelch /nav id %s", spawnId)
	SetChatTitle("Navigating to spawn " .. navSpawn.CleanName())
	PrintDebugMessage(DebuggingRanks.Function, "navSpawn ID: %s", navSpawn.ID())
	PrintDebugMessage(DebuggingRanks.Function, "navSpawn Distance: %s", navSpawn.Distance())

	while (navSpawn.ID() > 0 and navSpawn.Distance() > 30) do
		local respawned = Nav._amIDead()
		if (respawned) then
			Nav._handleRespawnRecovery()
			mq.cmd.nav("stop")
			FunctionDepart()
			return
		end

		Nav._whereAmI()
		Delay(100)

		local xtarget = Nav._getNextXTarget()

		if (xtarget == nil) then
			Nav._checkMerc()
			Nav._checkPet()
			Nav._checkAllAccessNag()
		else
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			if (combatRoutine) then
				local holdTargetType = workSet.TargetType
				local holdTarget     = workSet.MyTargetID
				workSet.TargetType   = xtarget.Type()

				combatRoutine(xtarget.ID())

				workSet.MyTargetID = holdTarget
				workSet.TargetType = holdTargetType
			end

			if (Me.Combat() and Nav._getNextXTarget() == nil) then
				mq.cmd("/squelch /target clear")
			end

			Delay(100)
		end

		if (not Navigation.Active()) then
			mq.cmdf("/squelch /nav id %s", spawnId)
		end
	end

	if (Navigation.Active()) then
		mq.cmd.nav("stop")
	end

	FunctionDepart()
end

--- Navigate to a Y/X/Z coordinate, handling xtargets along the way.
---@param y number
---@param x number
---@param z number
function Nav.navToLoc(y, x, z)
	FunctionEnter()

	local destLoc = string.format("%s,%s,%s", y, x, z)

	if (Navigation.PathExists(string.format("locyxz %s", destLoc))) then
		PrintDebugMessage(DebuggingRanks.Function, "Nav to Y: %s, X: %s, Z: %s", y, x, z)
		SetChatTitle("Navigating to loc " .. destLoc)

		while (Math.Distance(destLoc)() > 15) do
			Nav._checkSwiftness()
			Nav._checkSelfBuffs()
			Nav._whereAmI()

			local xtarget = Nav._getNextXTarget()

			if (xtarget == nil) then
				Nav._checkMerc()
				Nav._checkPet()
				Nav._checkAllAccessNag()
			else
				if (Navigation.Active()) then
					mq.cmd.nav("stop")
				end

				workSet.TargetType = xtarget.Type()
				Nav._findAndKill(xtarget.ID())

				if (Me.Combat() and Nav._getNextXTarget() == nil) then
					mq.cmd("/squelch /target clear")
				end

				Delay(100)
			end

			if (not Navigation.Active()) then
				mq.cmdf("/squelch /nav locyxz %s %s %s", y, x, z)
			end
		end

		if (Navigation.Active()) then
			mq.cmd.nav("stop")
		end
	end

	FunctionDepart()
end

--- Navigate to a named location from a location table entry.
---@param loc Location
function Nav.navToKnownLoc(loc)
	FunctionEnter()

	if (loc) then
		Nav.navToLoc(loc.Y, loc.X, loc.Z)
	end

	FunctionDepart()
end

--- Navigate to a Y/X/Z coordinate using /moveto (slower, precise positioning).
---@param y integer
---@param x integer
---@param z integer
function Nav.moveToWait(y, x, z)
	FunctionEnter()

	Nav._checkSwiftness()
	Nav._checkSelfBuffs()

	local loc = string.format("loc %s %s %s", y, x, z)
	mq.cmd.moveto(loc)

	while (MoveTo.Moving()) do
		Nav._whereAmI()
		Nav._checkMerc()
		Nav._checkPet()
		Nav._checkAllAccessNag()

		Delay(100)
	end

	FunctionDepart()
end

--- Navigate to within hailing distance of a spawn, then target and hail it.
---@param navTargetID integer
function Nav.navHail(navTargetID)
	FunctionEnter()
	PrintDebugMessage(DebuggingRanks.Deep, "Nav and hail spawn id: %s", navTargetID)

	local navSpawn = Spawn("id " .. navTargetID)
	PrintDebugMessage(DebuggingRanks.Deep, "    spawn name: %s", navSpawn.Name())
	SetChatTitle("Navigating to spawn " .. navSpawn.CleanName())

	while (navSpawn.ID() > 0 and navSpawn.Distance() > 15) do
		Nav._checkSwiftness()
		Nav._checkSelfBuffs()
		Nav._whereAmI()

		local xtarget = Nav._getNextXTarget()

		if (xtarget == nil) then
			Nav._checkMerc()
			Nav._checkPet()
			Nav._checkAllAccessNag()
		else
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			workSet.TargetType = xtarget.Type()
			Nav._findAndKill(xtarget.ID())

			if (Me.Combat() and Nav._getNextXTarget() == nil) then
				mq.cmd("/squelch /target clear")
			end

			Delay(100)
		end

		if (not Navigation.Active()) then
			mq.cmdf("/squelch /nav id %s", navTargetID)
		end
	end

	if (Navigation.Active()) then
		mq.cmd("/squelch /nav stop")
	end

	Nav.targetSpawnById(navTargetID)

	mq.cmd.hail()
	Delay(250)

	FunctionDepart()
end

--- Navigate to a ground item, pick it up, and auto-inventory it.
---@param groundItemName string
function Nav.waitNavGround(groundItemName)
	FunctionEnter()

	local groundItem = Ground.Search(groundItemName)
	local groundLoc = string.format("loc %s %s %s", groundItem.Y(), groundItem.X(), groundItem.Z())
	Note.Info("GroundItemName: %s Distance: %s", groundItemName, groundItem.Distance3D())

	while (groundItem.Distance3D() > 15) do
		if (Navigation.Active()) then
			Delay(100)
		else
			mq.cmd.nav(groundLoc)
		end
	end

	if (Navigation.Active()) then
		mq.cmd.nav("stop")
	end

	Note.Info("GroundItemName: %s Distance: %s", groundItemName, groundItem.Distance3D())

	Ground.Search(groundItemName).DoTarget()
	Delay(100)
	Ground.Search(groundItemName).Grab()

	Delay(1000, function()
		return Cursor.ID() ~= nil
	end)

	Delay(100)
	mq.cmd.autoinventory()
	Delay(100)

	FunctionDepart()
end

return Nav
