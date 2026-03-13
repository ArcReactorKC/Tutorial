---@file CombatBuffs.lua
--- Combat buff and casting check functions extracted from init.lua.

---@type Mq
local mq = require("mq")
require("inc.Global")
local State     = require("core.State")
local Utility   = require("core.Utility")
local SpellMgmt = require("core.SpellMgmt")
local Inventory = require("core.Inventory")
local Tasks     = require("core.Tasks")

local workSet = State.workSet

local Note = require("ext.Note")

local TLO = mq.TLO
local Me         = TLO.Me
local Cursor     = TLO.Cursor
local Spawn      = TLO.Spawn
local Target     = TLO.Target
local Navigation = TLO.Navigation
local Mercenary  = TLO.Mercenary
local Window     = TLO.Window

local CombatBuffs = {}

--- Callback slots (set by the caller to wire up cross-module dependencies)
CombatBuffs._getNextXTarget   = nil  -- function(): xtarget|nil
CombatBuffs._targetSpawnById  = nil  -- function(id): void
CombatBuffs._navToSpawn       = nil  -- function(id, routine?): void
CombatBuffs._findAndKill      = nil  -- function(id, opts?): void
CombatBuffs._basicNavToSpawn  = nil  -- function(id): void  (simple, no xtarget handling)

--- Checks/applies swiftness-type buffs (SoW, etc.)
function CombatBuffs.checkSwiftness()
	FunctionEnter()

	if (workSet.Location == "PitSteps") then
		FunctionDepart()
		return
	end

	if (not TLO.InvSlot(19).Item.ID() and TLO.FindItemCount(67109)() == 1) then
		Inventory.grabItem("67109", "left")
		Delay(1000)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
	elseif (not TLO.InvSlot(19).Item.ID() and TLO.FindItemCount(67123)() == 1) then
		Inventory.grabItem("67123", "left")
		Delay(1000)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
	elseif (not TLO.InvSlot(19).Item.ID() and TLO.FindItemCount(67116)() == 1) then
		Inventory.grabItem("67116", "left")
		Delay(1000)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
	elseif (not TLO.InvSlot(19).Item.ID() and TLO.FindItemCount(67102)() == 1) then
		Inventory.grabItem("67102", "left")
		Delay(1000)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
	end

	local xtarget = CombatBuffs._getNextXTarget()

	if (not Me.Buff("Blessing of Swiftness").ID() and xtarget == nil) then
		if (TLO.FindItemCount("=Worn Totem")() > 0 and Me.Buff(TLO.FindItem("=Worn Totem").Spell())() == nil and
			TLO.FindItem("=Worn Totem").TimerReady() == 0 and not Me.Buff("Spirit of Wolf").ID()) then
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			Delay(1500, function()
				return not Me.Moving()
			end)

			SpellMgmt.castItem("Worn Totem")
		end
	end

	if (Utility.isClassMatch({"BRD"}) and not Me.Buff("Selo's Accelerando").ID()) then
		local seloGem = Me.Gem("Selo's Accelerando")()

		if (seloGem) then
			mq.cmd.stopsong()
			mq.cmd.cast(seloGem)
			SpellMgmt.casting()
		end
	elseif (Utility.isClassMatch({"SHM", "DRU"}) and not Me.Buff("Spirit of Wolf").ID() and xtarget == nil) then
		local sowGem = Me.Gem("Spirit of Wolf")()

		if (sowGem) then
			if (Navigation.Active()) then
				mq.cmd.nav("stop")
			end

			Delay(1500, function()
				return not Me.Moving()
			end)

			SpellMgmt.castThenRetarget(sowGem)
		end
	end

	FunctionDepart()
end

--- Checks and applies self-buffs outside of combat.
function CombatBuffs.checkSelfBuffs()
	FunctionEnter()

	if (Me.Gem(1).ID() and Me.GemTimer(1)() == 0) then
		if (Utility.isClassMatch({ "NEC", "WIZ" }) and not Me.Buff("Shielding").ID() and Me.PctMana() > 20) then
			SpellMgmt.castSpell(1)
		elseif (Utility.isClassMatch({ "DRU" }) and not Me.Buff("Gloomingdeep Guard").ID() and not Me.Buff("Skin like Wood").ID() and
			not Me.Buff("Inner Fire").ID() and Me.PctMana() > 20) then
			SpellMgmt.castThenRetarget(1)
		elseif (Utility.isClassMatch({ "CLR", "RNG", "PAL", "BST", "SHM" }) and Me.PctHPs() < 30 and Me.PctMana() > 20) then
			SpellMgmt.castThenRetarget(1)
		end
	end

	if (Me.Gem(2).ID() and Me.GemTimer(2)() == 0) then
		if (Utility.isClassMatch({ "MAG", "ENC" }) and not Me.Buff("Shielding").ID() and Me.PctMana() > 20) then
			SpellMgmt.castSpell(2)
		elseif (Utility.isClassMatch({ "SHM" }) and not Me.Buff("Gloomingdeep Guard").ID() and not Me.Buff("Skin like Wood").ID() and
			not Me.Buff("Inner Fire").ID() and Me.PctMana() > 20) then
			SpellMgmt.castThenRetarget(2)
		elseif (Utility.isClassMatch({ "CLR" }) and not Me.Buff("Gloomingdeep Guard").ID() and not Me.Buff("Courage").ID()) then
			SpellMgmt.castThenRetarget(2)
		end
	end

	FunctionDepart()
end

--- Checks combat spells to cast during fights (heals, nukes, dots, pet, etc.)
function CombatBuffs.checkCombatCasting()
	FunctionEnter()

	if (Me.Gem(1).ID() and Me.GemTimer(1)() == 0) then
		if (Utility.isClassMatch({ "MAG", "ENC", "SHD" }) and Target.ID() > 0 and Target.Type() ~= "Object" and Target.Distance() < 30 and Me.PctMana() > 20 and os.time() > workSet.DpsLImiter) then
			SpellMgmt.castSpell(1)
			workSet.DpsLImiter = os.time() + 10
		elseif (Utility.isClassMatch({ "CLR", "RNG", "PAL", "BST", "SHM" }) and Me.PctHPs() < 30 and Me.PctMana() > 20) then
			SpellMgmt.castThenRetarget(1)
		elseif (Utility.isClassMatch({ "BRD" }) and not Me.Song("Chant of Battle").ID()) then
			mq.cmd.stopsong()
			mq.cmd.cast(1)
			SpellMgmt.casting()
		end
	end

	if (Me.Gem(2).ID() and Me.GemTimer(2)() == 0) then
		if (Utility.isClassMatch({ "WIZ" }) and Target.ID() > 0 and Target.Type() ~= "Object"  and Target.Distance() < 30 and Me.PctMana() > 20 and os.time() > workSet.DpsLImiter) then
			SpellMgmt.castSpell(2)
			workSet.DpsLImiter = os.time() + 10
		elseif (Utility.isClassMatch({ "NEC" }) and Target.ID() > 0 and Target.Type() ~= "Object"  and Target.Distance() < 30 and Me.PctMana() > 20 and os.time() > workSet.DpsLImiter) then
			SpellMgmt.castSpell(2)
			workSet.DpsLImiter = os.time() + 10
		elseif (Utility.isClassMatch({ "DRU" }) and Me.PctHPs() < 30 and Me.PctMana() > 20) then
			SpellMgmt.castThenRetarget(2)
		end
	end

	if (Me.Gem(3).ID() and Me.GemTimer(3)() == 0) then
		if (Utility.isClassMatch({ "CLR" }) and not Me.Buff("Yaulp").ID() and Me.PctMana() > 20) then
			SpellMgmt.castSpell(3)
		end
	end

	FunctionDepart()
end

--- Checks/applies blessing-type buffs.
function CombatBuffs.checkBlessing()
	FunctionEnter()

	if (not Me.Buff("Gloomingdeep Guard").ID()) then
		local rytan = Spawn("Rytan")

		CombatBuffs._navToSpawn(rytan.ID(), CombatBuffs._findAndKill)
		CombatBuffs._targetSpawnById(rytan.ID())

		mq.cmd.say("Blessed")
		Delay(100)

		Tasks.closeDialog()
		Tasks.closeDialog()
		Tasks.closeDialog()

		Delay(1000, function()
			return Me.Buff("Gloomingdeep Guard").ID()
		end)

		mq.cmd("/squelch /target clear")
	end

	FunctionDepart()
end

--- Lightweight blessing: navigate (simple, no xtarget) to Rytan and say "Blessed".
--- Used immediately after respawn when the full combat nav is not safe.
function CombatBuffs.basicBlessing()
	FunctionEnter()

	if (not Me.Buff("Gloomingdeep Guard").ID()) then
		local rytan = Spawn("Rytan")

		CombatBuffs._basicNavToSpawn(rytan.ID())
		CombatBuffs._targetSpawnById(rytan.ID())

		mq.cmd.say("Blessed")
		Delay(100)

		Tasks.closeDialog()
		Tasks.closeDialog()
		Tasks.closeDialog()

		Delay(1000, function()
			return Me.Buff("Gloomingdeep Guard").ID()
		end)

		mq.cmd("/squelch /target clear")
	end

	FunctionDepart()
end

--- Revive a suspended mercenary and ensure it is on Aggressive stance.
function CombatBuffs.checkMerc()
	FunctionEnter()

	if (Mercenary.State() ~= "ACTIVE") then
		if (Me.Grouped()
			and Window("MMGW_ManageWnd").Child("MMGW_SuspendButton").Tooltip() == "Revive your current mercenary."
			and Window("MMGW_ManageWnd").Child("MMGW_SuspendButton").Enabled()) then
			Window("MMGW_ManageWnd").Child("MMGW_SuspendButton").LeftMouseUp()
		end
	end

	if (Mercenary.State() == "ACTIVE" and Mercenary.Stance() == "Passive") then
		mq.cmd("/stance Aggressive")
		Note.Info("Setting Mercenary to Aggressive")
	end

	FunctionDepart()
end

return CombatBuffs
