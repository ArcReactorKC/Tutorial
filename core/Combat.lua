---@file Combat.lua
--- Core combat functions extracted from init.lua.
--- Includes mob selection, navigation-to-kill, and the main findAndKill loop.

---@type Mq
local mq = require("mq")
require("inc.Global")
---@type Note
local Note = require("ext.Note")
local State        = require("core.State")
local Utility      = require("core.Utility")
local HEALER_MOBS  = require("data.HealerMobs")
local knownTargets = require("data.KnownTargets")

local workSet = State.workSet

local TLO = mq.TLO
local Me         = TLO.Me
local Target     = TLO.Target
local Spawn      = TLO.Spawn
local Navigation = TLO.Navigation
local Mercenary  = TLO.Mercenary
local Pet        = TLO.Pet
local Group      = TLO.Group

local Combat = {}

--- Callback slots (set by init.lua to wire up cross-module dependencies)
Combat._navToSpawn            = nil  -- function(id, routine?): void
Combat._targetSpawnById       = nil  -- function(id): void
Combat._checkCombatCasting    = nil  -- function(): void
Combat._checkGroupHealth      = nil  -- function(): void
Combat._checkGroupMana        = nil  -- function(): void
Combat._checkMerc             = nil  -- function(): void
Combat._checkPet              = nil  -- function(): void
Combat._checkAllAccessNag     = nil  -- function(): void
Combat._amIDead               = nil  -- function(): boolean
Combat._handleRespawnRecovery = nil  -- function(): void  (throws on respawn)
Combat._whereAmI              = nil  -- function(): void

--- Return the first live, non-corpse XTarget entry, or nil if none.
--- The original 250ms unconditional delay has been removed; loop callers
--- already sleep 100ms per iteration so XTarget has time to update naturally.
---@return xtarget|nil
function Combat.getNextXTarget()
	FunctionEnter()

	for i = 1, Me.XTarget() do
		if (Me.XTarget(i).ID() > 0 and Me.XTarget(i).Type() ~= nil and Me.XTarget(i).Type() ~= "Corpse") then
			PrintDebugMessage(DebuggingRanks.Detail, "Me.XTarget(%s) ID: %s, Name: %s, Type: %s",
				i, Me.XTarget(i).ID(), Me.XTarget(i).Name(), Me.XTarget(i).Type())
			FunctionDepart()
			return Me.XTarget(i)
		end
	end

	FunctionDepart()
	return nil
end

--- Return true if no non-group PCs are within 30m of the spawn (safe to pull).
---@param spawn spawn
---@return boolean
function Combat.targetValidate(spawn)
	local search    = string.format("loc %s %s radius 30 pc notid %s", spawn.X(), spawn.Y(), Me.ID())
	local pcCount   = TLO.SpawnCount(search)()
	local grpCount  = TLO.SpawnCount(search .. " group")()
	pcCount = pcCount - grpCount

	if (pcCount > 0) then
		PrintDebugMessage(DebuggingRanks.Deep, "Players close to target: %s (%s)", spawn.CleanName(), spawn.ID())
		Delay(400)
		return false
	end

	return true
end

--- Populate mobList with spawns matching target within pull range.
---@param target TargetInfo
---@param mobList table<integer, MobInfo>
function Combat.findMobsInRange(target, mobList)
	FunctionEnter()

	local spawnPattern   = string.format("noalert 1 targetable radius %s zradius %s", workSet.PullRange, workSet.ZRadius)
	local searchExpr     = string.format("%s %s \"%s\"", spawnPattern, target.Type, target.Name)

	if (not mobList) then
		PrintDebugMessage(DebuggingRanks.Task, "mobList must be initialized")
		return
	end

	local mobsInRange = TLO.SpawnCount(searchExpr)()

	for i = 1, mobsInRange do
		local nearest = TLO.NearestSpawn(i, searchExpr)

		if (nearest.Name() ~= nil
			and (nearest.TargetOfTarget.ID() == 0 or nearest.TargetOfTarget.Name() == Me.Mercenary.Name())
			and nearest.ConColor() ~= "GREY"
			and not State.noPathList[nearest.ID()]
			and Combat.targetValidate(nearest)) then

			PrintDebugMessage(DebuggingRanks.Deep, "\atFound one — maybe, lets see if it has a path")

			if (Navigation.PathExists("id " .. nearest.ID())()) then
				---@type MobInfo
				local mobInfo = {
					Distance = Navigation.PathLength("id " .. nearest.ID())(),
					Type     = target.Type,
					Priority = target.Priority or 10,
				}
				mobList[nearest.ID()] = mobInfo
				PrintDebugMessage(DebuggingRanks.Deep, "Found path to \aw%s\ax (\aw%s\ax): %s", nearest.Name(), nearest.ID(), mobInfo)
			else
				State.noPathList[nearest.ID()] = true
				PrintDebugMessage(DebuggingRanks.Detail, "\at%s was not a valid pull target.", nearest.Name())
				PrintDebugMessage(DebuggingRanks.Detail, "\arPathExists: %s, Distance3D: %s, PathLength: %s",
					Navigation.PathExists("id " .. nearest.ID())(),
					nearest.Distance3D(),
					Navigation.PathLength("id " .. nearest.ID())())
			end
		end
	end

	FunctionDepart()
end

--- Sort mob IDs by priority (ascending) then path distance (ascending).
---@param mobList table<integer, MobInfo>
---@return integer[]
function Combat.sortMobIds(mobList)
	local keys = {}

	for key in pairs(mobList) do
		table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		if (mobList[a].Priority ~= mobList[b].Priority) then
			return mobList[a].Priority < mobList[b].Priority
		end
		return mobList[a].Distance < mobList[b].Distance
	end)

	return keys
end

--- Select the closest/highest-priority mob and set workSet.MyTargetID.
--- If an xtarget is active, that takes precedence.
---@param preferenceMobs? TargetInfo[]
function Combat.targetShortest(preferenceMobs)
	FunctionEnter()

	local xtarget = Combat.getNextXTarget()

	if (xtarget == nil) then
		---@type table<integer, MobInfo>
		local mobList = {}

		if (not preferenceMobs or Utility.tableCount(preferenceMobs) == 0) then
			PrintDebugMessage(DebuggingRanks.Deep, "No preference mobs given, find %s %s in radius of %s and ZRad: %s",
				workSet.TargetType, workSet.FarmMob, workSet.PullRange, workSet.ZRadius)
			---@type TargetInfo
			local target = { Name = workSet.FarmMob, Type = workSet.TargetType }
			Combat.findMobsInRange(target, mobList)
		else
			PrintDebugMessage(DebuggingRanks.Deep, "Search list %s in radius of %s and ZRad: %s",
				preferenceMobs, workSet.PullRange, workSet.ZRadius)
			for _, target in pairs(preferenceMobs) do
				Combat.findMobsInRange(target, mobList)
			end
		end

		PrintDebugMessage(DebuggingRanks.Deep, "There were %s mobs in radius of %s and ZRad: %s",
			Utility.tableCount(mobList), workSet.PullRange, workSet.ZRadius)

		if (Utility.tableCount(mobList) > 0) then
			local sortedKeys = Combat.sortMobIds(mobList)

			workSet.MyTargetID = sortedKeys[1]
			workSet.TargetType = mobList[workSet.MyTargetID].Type

			SetChatTitle("Going to kill " .. Spawn("id " .. workSet.MyTargetID).CleanName() .. "!")
		else
			workSet.MyTargetID = 0
			workSet.TargetType = "NPC"
		end
	else
		workSet.MyTargetID = xtarget.ID()
		workSet.TargetType = xtarget.Type()
	end

	PrintDebugMessage(DebuggingRanks.Deep, "targetId: %s", workSet.MyTargetID)
	PrintDebugMessage(DebuggingRanks.Deep, "targetType: %s", workSet.TargetType)
	FunctionDepart()
end

--- Find the nearest known healer mob within radius that has a navigable path.
---@param radius integer
---@return integer healerId  0 if none found
function Combat.getNearbyHealerId(radius)
	-- We intentionally do NOT require the healer to be targeting us;
	-- healers often target their ally while still keeping us in combat.
	local spawnPattern = string.format("noalert 1 targetable npc radius %d zradius %d", radius, workSet.ZRadius)

	for _, healerName in ipairs(HEALER_MOBS) do
		local searchExpr = string.format('%s "%s"', spawnPattern, healerName)
		local count = TLO.SpawnCount(searchExpr)()

		if (count and count > 0) then
			local nearest = TLO.NearestSpawn(1, searchExpr)
			if (nearest.ID() and nearest.ID() > 0
				and nearest.Type() ~= "Corpse"
				and nearest.ConColor() ~= "GREY") then
				if (Navigation.PathExists("id " .. nearest.ID())()) then
					return nearest.ID()
				end
			end
		end
	end

	return 0
end

--- Core combat loop: navigate to spawnId, engage, kill, handle healer priority.
--- opts.force skips target-of-target and xtarget checks (used for healer sub-kills).
---@param spawnId integer
---@param opts table|nil
function Combat.findAndKill(spawnId, opts)
	opts = opts or {}
	FunctionEnter()
	PrintDebugMessage(DebuggingRanks.Function, "spawnId: %s", spawnId)
	workSet.MyTargetID = spawnId

	local respawned = Combat._amIDead()
	if (respawned) then
		Combat._handleRespawnRecovery()
		FunctionDepart()
		return
	end

	local killSpawn = Spawn(workSet.MyTargetID)
	local xtarget

	-- Phase 1: Navigate towards the target, handling xtargets and ToT checks en route.
	while (killSpawn() and killSpawn.ID() > 0 and killSpawn.Distance() > 30) do
		if (killSpawn.Type() == "Corpse") then
			FunctionDepart()
			return
		end

		local totId   = killSpawn.TargetOfTarget.ID() or 0
		local totName = killSpawn.TargetOfTarget.CleanName() or killSpawn.TargetOfTarget.Name() or ""
		local isOurFight = false

		if (totId > 0) then
			if (totId == Me.ID()) then
				isOurFight = true
			elseif (Me.Mercenary.ID() and Me.Mercenary.ID() > 0 and totId == Me.Mercenary.ID()) then
				isOurFight = true
			elseif (Pet.ID() and Pet.ID() > 0 and totId == Pet.ID()) then
				isOurFight = true
			else
				for i = 1, Group.Members() do
					local memberId   = Group.Member(i).ID() or 0
					local memberName = Group.Member(i).Name() or ""
					if (memberId > 0 and (totId == memberId or (totName ~= "" and totName == memberName))) then
						isOurFight = true
						break
					end
				end
			end
		end

		if (not opts.force and totId > 0 and not isOurFight) then
			PrintDebugMessage(DebuggingRanks.Detail, "Skipping %s (ID %s): target-of-target is external (%s / %s)",
				killSpawn.CleanName(), killSpawn.ID(), totName, totId)
			FunctionDepart()
			return
		elseif (totId > 0) then
			PrintDebugMessage(DebuggingRanks.Deep, "Continuing %s (ID %s): target-of-target is ours (%s / %s)%s",
				killSpawn.CleanName(), killSpawn.ID(), totName, totId,
				opts.force and " (force override)" or "")
		end

		xtarget = Combat.getNextXTarget()

		if (not opts.force and xtarget and xtarget.ID() ~= spawnId) then
			local holdTarget     = workSet.MyTargetID
			local holdTargetType = workSet.TargetType
			workSet.TargetType   = xtarget.Type()

			Combat.findAndKill(xtarget.ID())

			workSet.MyTargetID = holdTarget
			workSet.TargetType = holdTargetType
		end

		Combat._navToSpawn(workSet.MyTargetID, Combat.findAndKill)
	end

	-- Phase 2: Target the mob if needed.
	if ((Target.ID() == 0 or Target.ID() ~= workSet.MyTargetID)
		and workSet.MyTargetID ~= 0
		and (xtarget == nil or opts.force)) then
		PrintDebugMessage(DebuggingRanks.Basic, "I'm targeting %s, ID: %s", killSpawn.CleanName(), workSet.MyTargetID)
		Combat._targetSpawnById(workSet.MyTargetID)
	end

	Delay(100)

	-- Phase 3: Kill loop — wait for the mob to die.
	local waitingOnDeadMob = true

	while (waitingOnDeadMob) do
		local died = Combat._amIDead()
		if (died) then
			Combat._handleRespawnRecovery()
			FunctionDepart()
			return
		end

		-- Healer priority: if a healer mob is nearby while we're in combat, kill it first.
		-- This prevents "yo-yo" fights caused by plaguebearers and spiritweaves healing allies.
		if (Me.Combat() and not workSet.HealerPriorityLock) then
			local healerId = Combat.getNearbyHealerId(workSet.HealerScanRadius)
			if (healerId and healerId > 0 and healerId ~= Target.ID()) then
				local healerSpawn = Spawn("id " .. healerId)
				if (healerSpawn.ID() > 0) then
					PrintDebugMessage(DebuggingRanks.Basic, "Healer nearby (%s). Prioritizing kill.", healerSpawn.CleanName())
					local holdTarget     = workSet.MyTargetID
					local holdTargetType = workSet.TargetType
					workSet.HealerPriorityLock = true

					if (Navigation.Active()) then mq.cmd("/squelch /nav stop") end
					mq.cmd("/squelch /target clear")
					mq.cmd("/squelch /stick off")
					mq.cmd("/squelch /attack off")
					Delay(50)
					Combat._targetSpawnById(healerId)

					workSet.TargetType = "NPC"
					Combat.findAndKill(healerId, { force = true })
					workSet.HealerPriorityLock = false
					workSet.MyTargetID  = holdTarget
					workSet.TargetType  = holdTargetType

					-- Reacquire original target after healer dies.
					local heldSpawn = Spawn("id " .. holdTarget)
					if (heldSpawn.ID() > 0 and heldSpawn.Type() ~= "Corpse") then
						Combat._targetSpawnById(holdTarget)
						mq.cmd.attack("on")
						if (Me.Mercenary.ID()) then mq.cmd("/mercassist") end
						if (Pet.ID() > 0) then mq.cmd.pet("attack") end
					end
				end
			end
		end

		if (Target.ID() > 0 and Target.Type() == workSet.TargetType) then
			if (waitingOnDeadMob and Target.Distance() < 30) then
				if (Navigation.Active()) then
					mq.cmd("/squelch /nav stop")
				end

				if (Utility.isClassMatch({"WAR","PAL","SHD"})
					or (Me.Grouped() and Group.Member(0).MainTank())
					or workSet.TargetType == "Object"
					or Target.CleanName() == knownTargets.spiderCocoon.Name) then
					mq.cmd.stick("8 uw loose moveback")
				end

				SetChatTitle("Killing " .. Target.CleanName())

				if (Me.Ducking()) then
					mq.cmd("/stand")
				end

				mq.cmd.attack("on")

				if (Me.Mercenary.ID()) then
					mq.cmd("/mercassist")
				end

				if (Pet.ID() > 0 and Pet.Target.ID() ~= Target.ID()) then
					mq.cmd.pet("attack")
				end

				Delay(1000)
			elseif (waitingOnDeadMob and Target.Distance() >= 30) then
				Combat._navToSpawn(workSet.MyTargetID, Combat.findAndKill)
			end

			Combat._checkCombatCasting()

			local targetSpawn = Spawn("id " .. Target.ID())
			PrintDebugMessage(DebuggingRanks.Detail, "targetSpawn ID: %s", targetSpawn.ID())
			PrintDebugMessage(DebuggingRanks.Detail, "targetSpawn Name: %s", targetSpawn.Name())

			if (targetSpawn.ID() == 0 or targetSpawn.Type() == "Corpse") then
				mq.cmd("/squelch /target clear")
				waitingOnDeadMob = false
			else
				if (targetSpawn.Distance() < 30
					and Me.PctHPs() < workSet.MoveAwayHP
					and workSet.MoveAway
					and Mercenary.State() == "ACTIVE"
					and Target.ID() > 0 and Target.PctAggro() > 99) then
					mq.cmd.attack("off")
					Delay(100)
					mq.cmd.keypress("backward hold")
					Delay(1000)
					mq.cmd.keypress("forward")
				end
			end
		else
			waitingOnDeadMob = false
		end

		xtarget = Combat.getNextXTarget()

		if (not opts.force and not waitingOnDeadMob and xtarget) then
			PrintDebugMessage(DebuggingRanks.Detail, "Have \aw%s\ax on XTarget", xtarget.Name())
			Combat.findAndKill(xtarget.ID())
		end

		Combat._checkAllAccessNag()
		Delay(100)
	end

	-- Phase 4: Post-kill group checks.
	Combat._checkGroupHealth()
	Combat._checkGroupMana()

	FunctionDepart()
end

--- Farming loop: select, target, and kill mobs of the specified type.
--- Handles group death, health/mana recovery, merc, and pet checks between kills.
---@param enemy? TargetInfo
function Combat.farmStuff(enemy)
	FunctionEnter()

	if (enemy) then
		workSet.FarmMob  = enemy.Name
		workSet.TargetType = enemy.Type

		if (DebugLevel > DebuggingRanks.None and workSet.ReportTarget < os.time()) then
			Note.Info("Looking for: %s", workSet.FarmMob)
			workSet.ReportTarget = os.time() + 5
		end

		Combat.targetShortest({enemy})
		PrintDebugMessage(DebuggingRanks.Deep, "spawn: %s",
			Spawn("id " .. workSet.MyTargetID .. " " .. workSet.TargetType).Name())
		Spawn("id " .. workSet.MyTargetID .. " " .. workSet.TargetType).DoTarget()

		Delay(3000, function()
			return Target.ID() == workSet.MyTargetID
		end)
	else
		Note.Info("Attacking anything I can get my grubby paws on.")
	end

	if (Target.Type() == "Corpse") then
		mq.cmd("/squelch /target clear")
	end

	if (TLO.Window("RespawnWnd").Open()) then
		Combat._checkGroupHealth()
	end

	local xtarget = Combat.getNextXTarget()

	if (xtarget == nil or TLO.Window("RespawnWnd").Open()) then
		Combat._checkGroupHealth()
		Combat._checkGroupMana()
		Combat._checkMerc()
		Combat._checkPet()
		Combat._checkAllAccessNag()
	end

	local targetSpawn = Spawn("id " .. workSet.MyTargetID)

	if ((targetSpawn.ID() == 0 or targetSpawn.Type() == "Corpse") and xtarget == nil) then
		PrintDebugMessage(DebuggingRanks.Task, "Getting a target!")

		workSet.MyTargetID = 0
		Combat.targetShortest()

		if (DebugLevel > DebuggingRanks.Basic and workSet.MyTargetID > 0) then
			Note.Info("Target is %s", Spawn("id " .. workSet.MyTargetID))
		end
	end

	Combat.findAndKill(workSet.MyTargetID)

	FunctionDepart()
end

return Combat
