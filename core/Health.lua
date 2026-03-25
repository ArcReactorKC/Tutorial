---@file Health.lua
--- Health, death, mana, and recovery functions extracted from init.lua.

---@type Mq
local mq = require("mq")
require("inc.Global")
---@type Note
local Note = require("ext.Note")
local State = require("core.State")
local Utility = require("core.Utility")
local SpellMgmt = require("core.SpellMgmt")

local workSet = State.workSet

local TLO = mq.TLO
local Me = TLO.Me
local Window = TLO.Window
local Zone = TLO.Zone
local Group = TLO.Group
local Navigation = TLO.Navigation

local Health = {}

--- Callback slots (set by the caller to wire up cross-module dependencies)
Health._basicBlessing = nil       -- function(): void
Health._basicNavToLoc = nil       -- function(y, x, z): void
Health._gotoSpiderHall = nil      -- function(): void
Health._getNextXTarget = nil      -- function(): xtarget|nil
Health._checkAllAccessNag = nil   -- function(): void
Health._safeSpace = nil           -- table<string, Location>
Health._RESPAWN_RESTART_SIGNAL = nil -- string

--- Forward declaration for medToFull (referenced before definition)
local medToFull

--- Death detection and respawn handling.
--- CRITICAL: Returns bool `died`. See MEMORY.md for bug-fix history.
---@return boolean died true if a respawn was performed
function Health.amIDead()
	FunctionEnter()

	local died = false
	local optionsList = Window("RespawnWnd").Child("RW_OptionsList")

	if (Window("RespawnWnd").Open()) then
		Note.Info("\arYOU~ have died! Waiting for YOU to get off your face.")
		SetChatTitle("You died, get back up")

		optionsList.Select(1)
		Delay(2000, function ()
			return optionsList.GetCurSel() == 1
		end)

		Window("RespawnWnd").Child("RW_SelectButton").LeftMouseUp()

		Delay(1000, function()
			return not Me.Hovering()
		end)

		workSet.JustRespawned = true
		workSet.Location = "StartArea"

		mq.cmd("/squelch /target clear")
		Health._basicBlessing()
		mq.cmd("/squelch /target clear")
		died = true
		workSet.DeathCount = workSet.DeathCount + 1
	end

	FunctionDepart()
	return died
end

--- Post-respawn recovery logic: navigate to StartArea safe spot, med to full, then
--- signal a restart via error().
function Health.handleRespawnRecovery()
	if (not workSet.JustRespawned) then
		return
	end

	Note.Info("Respawned: medding in StartArea")
	SetChatTitle("Respawned: medding in StartArea")

	local startSafe = Health._safeSpace["StartArea"]

	if (startSafe ~= nil) then
		Health._basicNavToLoc(startSafe.Y, startSafe.X, startSafe.Z)
		if (startSafe.Heading ~= nil) then
			mq.cmdf("/squelch /face heading %s nolook", startSafe.Heading)
		end
	else
		PrintDebugMessage(DebuggingRanks.Task, "No StartArea safe spot configured; medding in place.")
	end

	medToFull()
	workSet.JustRespawned = false
	error(Health._RESPAWN_RESTART_SIGNAL)
end

--- Find a safe location to rest based on current workSet.Location.
function Health.findSafeSpot()
	PrintDebugMessage(DebuggingRanks.Task, "Look for safe spot to rest in the \ag%s\ax area", workSet.Location)

	if (workSet.Location == "SpiderRoom" or workSet.Location == "QueenRoom") then
		Health._gotoSpiderHall()
	else
		local safeSpot = Health._safeSpace[workSet.Location]

		PrintDebugMessage(DebuggingRanks.Task, "%s", safeSpot)

		if (safeSpot ~= nil) then
			PrintDebugMessage(DebuggingRanks.None, "Moving to a safe place to regain health")
			PrintDebugMessage(DebuggingRanks.Basic, "PathExists: %s", Navigation.PathExists(string.format("loc %s %s %s", safeSpot.Y, safeSpot.X, safeSpot.Z)))
			Health._basicNavToLoc(safeSpot.Y, safeSpot.X, safeSpot.Z)
			if (safeSpot.Heading ~= nil) then
				mq.cmdf("/squelch /face heading %s nolook", safeSpot.Heading)
			end
		else
			PrintDebugMessage(DebuggingRanks.Task, "No safe spot found, rest here")
		end
	end
end

--- Sit and meditate until full health/mana (or until an xtarget appears).
medToFull = function()
	FunctionEnter()

	if (Zone.ID() == 188) then
		return
	end

	SetChatTitle("Waiting on YOUR health to reach " .. workSet.HealTill .. "%")

	while ((Me.PctHPs() < workSet.HealTill or (Me.PctMana() < workSet.MedTill and Me.Class.CanCast())) and Health._getNextXTarget() == nil) do
		if (Me.PctHPs() < workSet.HealTill and Utility.isClassMatch({ "CLR", "RNG", "PAL", "BST", "SHM" }) and Me.GemTimer(1)() == 0 and Me.PctMana() > 20) then
			mq.cmd.target(Me.CleanName())
			mq.cmd.cast(1)
			SpellMgmt.casting()
			mq.cmd("/squelch /target clear")
		elseif (Me.PctHPs() < workSet.HealTill and Utility.isClassMatch({ "DRU" }) and Me.GemTimer(2)() == 0 and Me.PctMana() > 20) then
			mq.cmd.target(Me.CleanName())
			mq.cmd.cast(2)
			SpellMgmt.casting()
			mq.cmd("/squelch /target clear")
		elseif (Me.PctHPs() < workSet.HealTill and Utility.isClassMatch({ "BRD" }) and not Me.Song("Hymn of Restoration")() and Me.Gem("Hymn of Restoration")()) then
			mq.cmd.stopsong()
			mq.cmd.cast(Me.Gem("Hymn of Restoration")())
			SpellMgmt.casting()
		elseif ((Me.Standing()) and (not Me.Casting.ID() or Utility.isClassMatch({"BRD"})) and (not Me.Mount.ID())) then
			Me.Sit()
		end

		Health._checkAllAccessNag()
		Delay(100)
	end

	FunctionDepart()
end

--- Public accessor for medToFull (the local is used for internal forward references).
Health.medToFull = medToFull

--- Check personal HP and heal/rest if below threshold.
function Health.checkPersonalHealth()
	FunctionEnter()

	if (Me.PctHPs() < workSet.HealAt) then
		Note.Info("\arYOU are low on Health!")

		if (TLO.FindItemCount("=Distillate of Celestial Healing II")() > 0 and
			not Me.Buff(TLO.FindItem("=Elixir of Healing II").Spell())() == nil and
			TLO.FindItem("=Distillate of Celestial Healing II").TimerReady() == 0) then
			mq.cmd.useitem("Distillate of Celestial Healing II")
		end

		Health.findSafeSpot()

		medToFull()
	end

	FunctionDepart()
end

--- Check personal mana and rest if below threshold.
function Health.checkPersonalMana()
	if (Me.PctMana() < workSet.MedAt and Me.Class.CanCast()) then
		Note.Info("\arYOU are low on mana!")
		SetChatTitle("Waiting on YOUR mana to reach " .. workSet.MedTill .. "%")

		Health.findSafeSpot()

		medToFull()
	end
end

-- --------------------------------------------------------------------------------------------
-- SUB: GroupDeathChk
-- --------------------------------------------------------------------------------------------
--- Check if any group members have died; handle own death/respawn first.
function Health.checkGroupDeath()
	FunctionEnter()
	local respawned = Health.amIDead()
	if (respawned) then
		Health.handleRespawnRecovery()
		FunctionDepart()
		return
	end

	local xtarget = Health._getNextXTarget()

	if (xtarget ~= nil) then
		FunctionDepart()

		return
	end

	if (Me.Grouped()) then
		for i = 1, Group.Members() do
			if (Group.Member(i).State == "Hovering") then
				Note.Info("%s has died. Waiting for them to get off their face.", Group.Member(i).Name())
				SetChatTitle(Group.Member(i).Name() .. " has died. Waiting for Rez")

				if (xtarget == nil) then
					while (Group.Member(i).State == "Hovering" and xtarget == nil) do
						if ((Me.Standing()) and (not Me.Casting.ID()) and (not Me.Mount.ID())) then
							Me.Sit()
						end

						for j = 1, Group.Members() do
							if (Group.Member(j).Standing() and Group.Member(j).Type() ~= "Mercenary") then
								mq.cmdf("/dex %s /sit", Group.Member(j).Name())
							end
						end

						Delay(100)

						xtarget = Health._getNextXTarget()
					end
				end
			end
		end
	end
	FunctionDepart()
end

-- --------------------------------------------------------------------------------------------
-- SUB: GroupManaChk
-- --------------------------------------------------------------------------------------------
--- Check group mana levels and wait if any caster is low.
function Health.checkGroupMana()
	FunctionEnter()

	local xtarget = Health._getNextXTarget()

	if (xtarget ~= nil) then
		FunctionDepart()

		return
	end

	local respawned = Health.amIDead()
	if (respawned) then
		Health.handleRespawnRecovery()
		FunctionDepart()
		return
	end

	if (not Me.Combat()) then
		SetChatTitle("Group Mana Check")
		Health.checkPersonalMana()

		if (Me.Grouped()) then
			for i = 1, Group.Members() do
				if ((not Group.Member(i).Dead() and not Group.Member(i).OtherZone() and Group.Member(i).PctMana() < workSet.MedAt) and (Group.Member(i).Class.CanCast())) then
					Note.Info("\ar%s is low on mana!", Group.Member(i).Name())
					SetChatTitle("Waiting on " .. Group.Member(i).Name() .. "'s mana to reach " .. workSet.MedTill .. "%")

					if (xtarget == nil) then
						while (not Group.Member(i).Dead() and Group.Member(i).PctMana() < workSet.MedTill and xtarget == nil) do
							if (Me.Standing() and not Me.Casting.ID() and not Me.Mount.ID()) then
								Me.Sit()
							end

							Health._checkAllAccessNag()
							Delay(100)

							xtarget = Health._getNextXTarget()
						end
					end
				end
			end
		end
	end

	FunctionDepart()
end

-- --------------------------------------------------------------------------------------------
-- SUB: GroupHealthChk
-- --------------------------------------------------------------------------------------------
--- Check group health levels and wait if any member is low.
function Health.checkGroupHealth()
	FunctionEnter()

	local xtarget = Health._getNextXTarget()

	if (xtarget ~= nil) then
		FunctionDepart()

		return
	end

	local respawned = Health.amIDead()
	if (respawned) then
		Health.handleRespawnRecovery()
		FunctionDepart()
		return
	end

	SetChatTitle("Group Health Check")

	if (not Me.Combat()) then
		Health.checkPersonalHealth()

		if (Me.Grouped()) then
			for i = 1, Group.Members() do
				if (Group.Member(i).ID() and not Group.Member(i).Dead()) then
					if (not Group.Member(i).OtherZone() and Group.Member(i).PctHPs() < workSet.HealAt) then
						Note.Info("%s is low on Health!", Group.Member(i).Name())
						SetChatTitle("Waiting on " .. Group.Member(i).Name() .. " health to reach " .. workSet.HealTill .. "%")
						if (Group.Member(i).Type() == "Mercenary") then
							Health.findSafeSpot()
						end
						if (xtarget == nil) then
							while (not Group.Member(i).Dead() and Group.Member(i).PctHPs() < workSet.HealTill and xtarget == nil) do
								if ((Me.Standing()) and (not Me.Casting.ID()) and (not Me.Mount.ID())) then
									Me.Sit()
								end

								for j = 1, Group.Members() do
									if (Group.Member(j).Standing() and Group.Member(j).Type() ~= "Mercenary") then
										mq.cmdf("/dex %s /sit", Group.Member(j).Name())
									end
								end

								Health._checkAllAccessNag()
								Delay(100)

								xtarget = Health._getNextXTarget()
							end
						end
					end
				end
			end
		end
	end

	FunctionDepart()
end

return Health
