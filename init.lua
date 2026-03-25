
--Based on Tutorial.mac by Chatwiththisname and Cannonballdex
-- original Lua refactor by Rouneq

--
--Purpose:  Will conduct the tutorial for the current character
--			from immediately after character creation
--			to completing all steps (required and optional)
--			in both "Basic Training" and "The Revolt of Gloomingdeep"
--
--Usage: /lua run Tutorial [option]
--
--       where option can be "nopause" (sans double-quotes)

local mq = require("mq")
local Note = require("ext.Note")
require("ImGui")
local ICON = require("inc.icons")
local Scribing = require("inc.Scribing")

Note.prefix = "tutorial"
Note.outfile = string.format("Tutorial_%s.log", mq.TLO.Me.CleanName())

Note.useOutfile = true
Note.appendToOutfile = false
Note.Info("Begin logging")
Note.appendToOutfile = true
Note.useOutfile = false

require("inc.Global")
require("ext.ICaseTable")

-- Core modules 
local State       = require("core.State")
local Utility     = require("core.Utility")
local ZoneMod     = require("core.Zone")
local SpellMgmt   = require("core.SpellMgmt")
local Inventory   = require("core.Inventory")
local Loot        = require("core.Loot")
local Health      = require("core.Health")
local Combat      = require("core.Combat")
local CombatBuffs = require("core.CombatBuffs")
local Nav         = require("core.Navigation")
local Tasks       = require("core.Tasks")

-- Data modules
local knownTargets = require("data.KnownTargets")
local NavLocations = require("data.NavLocations")
local Constants    = require("data.Constants")

--UI module
local TutorialUI = require("ui.TutorialUI")

-- tlo shortcuts 
local TLO        = mq.TLO
local Me         = TLO.Me
local Cursor     = TLO.Cursor
local Spawn      = TLO.Spawn
local Target     = TLO.Target
local Merchant   = TLO.Merchant
local Ground     = TLO.Ground
local Group      = TLO.Group
local Window     = TLO.Window
local Navigation = TLO.Navigation
local MoveTo     = TLO.MoveTo
local ZoneInfo   = TLO.Zone        
local Mercenary  = TLO.Mercenary
local Pet        = TLO.Pet
local Math       = TLO.Math
local EQ         = TLO.EverQuest

-- Module state aliases
local workSet         = State.workSet
local debuggingValues = State.debuggingValues
local lootedItems     = State.lootedItems
local navLocs         = NavLocations.navLocs
local RESPAWN_RESTART_SIGNAL = Constants.RESPAWN_RESTART_SIGNAL

--Function aliases
-- Utility
local isClassMatch = Utility.isClassMatch
local checkPlugin  = Utility.checkPlugin
local closeAlert   = Utility.closeAlert
local loadIgnores  = Utility.loadIgnores
-- Zone
local checkZone  = ZoneMod.checkZone
local whereAmI   = ZoneMod.whereAmI
local zoning     = ZoneMod.zoning
local checkMesh  = ZoneMod.checkMesh
-- SpellMgmt
local casting          = SpellMgmt.casting
local castSpell        = SpellMgmt.castSpell
local castItem         = SpellMgmt.castItem
local castThenRetarget = SpellMgmt.castThenRetarget
local clearGem         = SpellMgmt.clearGem
local memSpell         = SpellMgmt.memSpell
local checkPet         = SpellMgmt.checkPet
-- Inventory
local grabItem               = Inventory.grabItem
local destroyItem            = Inventory.destroyItem
local GetAvailableInvSlot    = Inventory.GetAvailableInvSlot
local invItem                = Inventory.invItem
local giveItems              = Inventory.giveItems
-- Loot
local checkLoot    = Loot.checkLoot
local sellLoot     = Loot.sellLoot
local sellInventory = Loot.sellInventory
local buyPetReagent = Loot.buyPetReagent
local buyClassPet  = Loot.buyClassPet
local handleLoot   = Loot.handleLoot
local getReward    = Loot.getReward
-- Health
local medToFull             = Health.medToFull
local checkPersonalHealth   = Health.checkPersonalHealth
local checkPersonalMana     = Health.checkPersonalMana
local checkGroupHealth      = Health.checkGroupHealth
local checkGroupMana        = Health.checkGroupMana
local checkGroupDeath       = Health.checkGroupDeath
local amIDead               = Health.amIDead
local handleRespawnRecovery = Health.handleRespawnRecovery
-- Combat
local getNextXTarget = Combat.getNextXTarget
local targetShortest = Combat.targetShortest
local findAndKill    = Combat.findAndKill
local farmStuff      = Combat.farmStuff
local sortMobIds     = Combat.sortMobIds
-- Buffs
local checkSwiftness     = CombatBuffs.checkSwiftness
local checkSelfBuffs     = CombatBuffs.checkSelfBuffs
local checkCombatCasting = CombatBuffs.checkCombatCasting
local checkBlessing      = CombatBuffs.checkBlessing
local basicBlessing      = CombatBuffs.basicBlessing
local checkMerc          = CombatBuffs.checkMerc
-- Tasks
local tutorialCheck    = Tasks.tutorialCheck
local tutorialSelect   = Tasks.tutorialSelect
local acceptTask       = Tasks.acceptTask
local openTaskWnd      = Tasks.openTaskWnd
local closeDialog      = Tasks.closeDialog
local checkStep        = Tasks.checkStep
local checkContinue    = Tasks.checkContinue
local levelUp          = Tasks.levelUp
local checkAllAccessNag = Tasks.checkAllAccessNag
-- Navigation
local targetSpawn      = Nav.targetSpawn
local targetSpawnById  = Nav.targetSpawnById
local targetSpawnByName = Nav.targetSpawnByName
local navToSpawn       = Nav.navToSpawn
local navToLoc         = Nav.navToLoc
local navToKnownLoc    = Nav.navToKnownLoc
local navHail          = Nav.navHail
local waitNavGround    = Nav.waitNavGround
local moveToWait       = Nav.moveToWait
local basicNavToLoc    = Nav.basicNavToLoc
local basicNavToSpawn  = Nav.basicNavToSpawn
local gotoSpiderHall   = Nav.gotoSpiderHall

-- Callback wiring
-- Navigation
Nav._getNextXTarget        = Combat.getNextXTarget
Nav._findAndKill           = Combat.findAndKill
Nav._checkSwiftness        = CombatBuffs.checkSwiftness
Nav._checkSelfBuffs        = CombatBuffs.checkSelfBuffs
Nav._checkMerc             = CombatBuffs.checkMerc
Nav._checkPet              = SpellMgmt.checkPet
Nav._checkAllAccessNag     = Tasks.checkAllAccessNag
Nav._whereAmI              = ZoneMod.whereAmI
Nav._amIDead               = Health.amIDead
Nav._handleRespawnRecovery = Health.handleRespawnRecovery
-- Combat
Combat._navToSpawn            = Nav.navToSpawn
Combat._targetSpawnById       = Nav.targetSpawnById
Combat._checkCombatCasting    = CombatBuffs.checkCombatCasting
Combat._checkGroupHealth      = Health.checkGroupHealth
Combat._checkGroupMana        = Health.checkGroupMana
Combat._checkMerc             = CombatBuffs.checkMerc
Combat._checkPet              = SpellMgmt.checkPet
Combat._checkAllAccessNag     = Tasks.checkAllAccessNag
Combat._amIDead               = Health.amIDead
Combat._handleRespawnRecovery = Health.handleRespawnRecovery
Combat._whereAmI              = ZoneMod.whereAmI
-- Buffs
CombatBuffs._getNextXTarget  = Combat.getNextXTarget
CombatBuffs._targetSpawnById = Nav.targetSpawnById
CombatBuffs._navToSpawn      = Nav.navToSpawn
CombatBuffs._findAndKill     = Combat.findAndKill
CombatBuffs._basicNavToSpawn = Nav.basicNavToSpawn
-- Health
Health._basicBlessing         = CombatBuffs.basicBlessing
Health._basicNavToLoc         = Nav.basicNavToLoc
Health._gotoSpiderHall        = Nav.gotoSpiderHall
Health._getNextXTarget        = Combat.getNextXTarget
Health._checkAllAccessNag     = Tasks.checkAllAccessNag
Health._safeSpace             = NavLocations.safeSpace
Health._RESPAWN_RESTART_SIGNAL = Constants.RESPAWN_RESTART_SIGNAL
-- Tasks
Tasks._targetShortest = Combat.targetShortest
Tasks._findAndKill    = Combat.findAndKill
Tasks._checkLoot      = Loot.checkLoot
Tasks._amIDead        = Health.amIDead
-- Loot
Loot._navHail         = Nav.navHail
Loot._getNextXTarget  = Combat.getNextXTarget
Loot._navToSpawn      = Nav.navToSpawn
Loot._findAndKill     = Combat.findAndKill
Loot._targetSpawnById = Nav.targetSpawnById
Loot._destroyItem     = Inventory.destroyItem
-- SpellMgmt
SpellMgmt._restockPetReagent = Loot.restockPetReagent
SpellMgmt._targetSpawnById   = Nav.targetSpawnById
-- TutorialUI
TutorialUI._bindStep   = Tasks.bindStep
TutorialUI._bindResume = Tasks.bindResume

-- Local quest helpers

local function placeItemInContainer(itemName, containerSlot)
	FunctionEnter()

	grabItem(itemName, "left")
	Delay(1000, function ()
		return Cursor.ID()
	end)
	mq.cmdf("/nomodkey /itemnotify enviro%s leftmouseup", containerSlot)
	Delay(1000, function ()
		return not Cursor.ID()
	end)

	FunctionDepart()
end

local function makeRatSteaks()
	FunctionEnter()

	mq.cmd.say("rat steaks")
	Delay(2000, function ()
		mq.cmd.autoinventory()
		return not Cursor.ID()
	end)
	mq.cmd("/squelch /ItemTarget \"Oven\"")
	Delay(100)
	mq.cmd("/squelch /click left item")
	Delay(5000, function ()
		return Window("TradeSkillWnd").Open()
	end)
	mq.cmd("/notify TradeskillWnd COMBW_ExperimentButton leftmouseup")
	Delay(5000, function()
		return Window("ContainerCombine_Items").Open()
	end)
	placeItemInContainer("Rat Meat", 1)
	placeItemInContainer("Cooking Sauce", 2)
	mq.cmd("/notify ContainerCombine_Items Container_Combine leftmouseup")
	Delay(2000, function ()
		return Cursor.ID()
	end)
	mq.cmd.autoinventory()
	Delay(2000, function ()
		return not Cursor.ID()
	end)

	FunctionDepart()
end

local function insertAug()
	FunctionEnter()

	grabItem("Steatite Fragment", "left")
	Delay(1000, function()
		return Cursor.ID()
	end)

	local mainhandItem = TLO.InvSlot("mainhand").Item
	local mainhandID = mainhandItem.ID()

	if not mainhandID then
		Note.Info("\arNo mainhand weapon found for aug insertion! \awDo it manually!")
		if Cursor.ID() then
			mq.cmd.autoinventory()
		end
		FunctionDepart()
		return
	end

	mq.cmdf("/insertaug %d", mainhandID)
	Delay(1000, function()
		return not Cursor.ID()
	end)

	if Cursor.ID() then
		mq.cmd.autoinventory()
		Note.Info("\arFailed to insert Steatite Fragment! \awDo it manually!")
	end

	Delay(100)

	FunctionDepart()
end

local function gotoSpiders()
	FunctionEnter(DebuggingRanks.Task)

	navToLoc(-1007, -482, -3)
	navToLoc(-1016.50, -483.21, -3)
	mq.cmd.keypress("forward hold")
	Delay(1000)
	mq.cmd.keypress("forward")

	FunctionDepart()
end

local function leaveSpiders()
	FunctionEnter(DebuggingRanks.Task)

	navToLoc(-670, -374, -65)
	mq.cmd.face("loc -595,-373,-40")
	mq.cmd.keypress("forward hold")
	Delay(1000)
	mq.cmd.keypress("forward")

	FunctionDepart(DebuggingRanks.Task)
end

local function gotoQueen()
	FunctionEnter(DebuggingRanks.Task)

	navToLoc(-1007, -482, -3)
	navToLoc(-1016.50, -483.21, -3)
	mq.cmd.keypress("forward hold")
	Delay(1000)
	mq.cmd.keypress("forward")
	navToLoc(-1186, -446, 19)
	navToLoc(-1201, -467, 19)
	navToLoc(-1188, -444, 19)

	FunctionDepart(DebuggingRanks.Task)
end

local function leaveQueen()
	FunctionEnter(DebuggingRanks.Task)

	gotoSpiders()
	leaveSpiders()

	FunctionDepart(DebuggingRanks.Task)
end

local function EnterPit()
	FunctionEnter(DebuggingRanks.Task)

	if (Me.Z() > -29) then
		navToLoc(-479, -1051, -1)
		moveToWait(-483, -965, -19)
		moveToWait(-486, -897, -42)
		moveToWait(-418, -893, -61)
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function ExitPit()
	FunctionEnter(DebuggingRanks.Task)

	navToLoc(-436, -899, -63)
	navToLoc(-485, -897, -42)
	navToLoc(-479.66, -1036.44, 2.74)
	mq.cmd.face("loc -480,-1024,-1")

	FunctionDepart(DebuggingRanks.Task)
end

-- Quest NPC functions

local function Lyndroh()
	FunctionEnter(DebuggingRanks.Task)

	if (TLO.FindItemCount(32601)() < 2) then
		navHail(Spawn("Lyndroh").ID())

		Target.RightClick()
		Delay(100, function()
			return Window("bigbankwnd").Open()
		end)

		mq.cmd("/nomodkey /itemnotify bank1 leftmouseup")
		Delay(100, function()
			return TLO.FindItemCount(32601)() == 2
		end)
		Delay(1000)

		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end

		closeDialog()
		closeDialog()

		grabItem("Crescent Reach Guild Summons", "left")

		mq.cmd("/autobank")

		Delay(1500, function ()
			return not Cursor.ID()
		end)
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Poxan()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(21, 2)() ~= "Done") then
		navHail(Spawn("Poxan").ID())

		closeDialog()
		closeDialog()

		waitNavGround("Defiance")
		navHail(Spawn("Poxan").ID())
		Delay(500)

		grabItem("Poxan's Sword", "left")
		Delay(1000, function()
			return Cursor.ID()
		end)
		mq.cmd.usetarget()
		Delay(1000, function()
			return not Cursor.ID()
		end)

		Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
		Delay(1000, function()
			return not Window("GiveWnd").Open()
		end)
		Delay(100)

		if (Cursor.ID()) then
			mq.cmd.autoinventory()
			Delay(100)
		end

		closeDialog()
		closeDialog()
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Farquard()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(17, 2)() ~= "Done") then
		if (not tutorialCheck("Achievements")) then
			navHail(Spawn("Scribe Farquard").ID())
			closeDialog()
			acceptTask("Achievements")
		end

		if (tutorialSelect("Achievements")) then
			mq.cmd.hail()
			Delay(100)
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			Delay(200)
			mq.cmd("/achievement")
			getReward()
		end

		tutorialSelect("Basic Training")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function LuclinPriest()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(23, 2)() ~= "Done") then
		navHail(Spawn("Priest of Luclin").ID())
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Wijdan()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(13, 2)() ~= "Done") then
		navHail(Spawn("Wijdan").ID())
		closeDialog()
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Rashere()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(19, 2)() ~= "Done") then
		navHail(Spawn("Rashere").ID())
		mq.cmd.say("bind my soul")
		closeDialog()
		Delay(400)
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Frizznik()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(11, 2)() ~= "Done") then
		navHail(Spawn("Frizznik").ID())
		closeDialog()
		makeRatSteaks()
		closeDialog()
		closeDialog()
		closeDialog()
		closeDialog()

		grabItem("Rat Steak", "right")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Xenaida()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(5, 2)() ~= "Done") then
		local xenaida = Spawn("Xenaida")

		navHail(xenaida.ID())

		closeDialog()
		closeDialog()

		waitNavGround("mushroom")

		navToSpawn(xenaida.ID())
		targetSpawnById(xenaida.ID())

		grabItem("Gloomingdeep Mushrooms", "left")
		Delay(1000, function()
			return Cursor.ID()
		end)

		mq.cmd.usetarget()
		Delay(1000, function()
			return not Cursor.ID()
		end)

		Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
		Delay(1000, function()
			return not Window("GiveWnd").Open()
		end)

		closeDialog()
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Rytan()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		navHail(Spawn("Rytan").ID())
		mq.cmd.say("Blessed")
		Delay(1000, function()
			return Cursor.ID()
		end)

		Delay(250)

		local spellName = ""

		if (Cursor.ID()) then
			local givenSpell = Cursor.Name()

			mq.cmd.autoinventory()
			Delay(1000, function()
				return not Cursor.ID()
			end)

			spellName = TLO.FindItem(givenSpell).Spell.Name()
			PrintDebugMessage(DebuggingRanks.Basic, "Rytan gave us spell %s", spellName)

			if (not Window("InventoryWindow").Open()) then
				Window("InventoryWindow").DoOpen()
			end
			mq.cmd.keypress("OPEN_INV_BAGS")
			Delay(1000, function()
				return Window("InventoryWindow").Open()
			end)
			Scribing.ScribeSpells()
		end
		closeDialog()
		closeDialog()
		closeDialog()
		Delay(1000)

		if (spellName ~= "") then
			local gem = 1

			if (isClassMatch({"CLR"})) then
				gem = 3
			end

			if (not Me.Gem(gem).ID()) then
				memSpell(gem, spellName)
			end
		end

		mq.cmd.keypress("CLOSE_INV_BAGS")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Prathun()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(7, 2)() ~= "Done") then
		navHail(Spawn("Prathun").ID())
		closeDialog()
		closeDialog()
		closeDialog()
		closeDialog()
		closeDialog()
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Elegist()
	FunctionEnter(DebuggingRanks.Task)

	local elegist = Spawn("Elegist")

	if (tutorialCheck("Mercenaries for Hire")) then
		navToSpawn(elegist.ID(), findAndKill)
		targetSpawnByName("Elegist")
	else
		navHail(elegist.ID())
		acceptTask("Mercenaries for Hire")
		closeDialog()
		closeDialog()
		closeDialog()
	end

	if (tutorialSelect("Mercenaries for Hire")) then
		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
			Target.RightClick()
			Delay(2000, function()
				return Window("MMTW_MerchantWnd").Open()
			end)

			local mercWindow = Window("MMTW_MerchantWnd")
			Delay(1500)

			PrintDebugMessage(DebuggingRanks.Function, "Subscription: %s", Me.Subscription())

			if (Me.Subscription() == "GOLD") then
				PrintDebugMessage(DebuggingRanks.Function, "Select Journeyman Merc")
				local typeDropdown = mercWindow.Child("MMTW_TypeComboBox")
				typeDropdown.Select(2)
				Delay(2000, function ()
					return typeDropdown.GetCurSel() == 2
				end)

				PrintDebugMessage(DebuggingRanks.Function, "Selected Merc Type: '\ay%s\ax'", typeDropdown.List(typeDropdown.GetCurSel(), 1)())
				Delay(250)
				PrintDebugMessage(DebuggingRanks.Function, "Select Journeyman Tank")
			else
				PrintDebugMessage(DebuggingRanks.Function, "Select Apprentice Tank")
			end

			local availableMercs = mercWindow.Child("MMTW_SubtypeListBox")
			availableMercs.Select(2)
			Delay(2000, function ()
				return availableMercs.GetCurSel() == 2
			end)
			Delay(250)

			local mercStance = mercWindow.Child("MMTW_StanceListBox")
			mercStance.Select(1)
			Delay(2000, function ()
				return mercStance.GetCurSel() == 1
			end)
			Delay(250)

			mercWindow.Child("MMTW_HireButton").LeftMouseUp()
			Delay(2000, function ()
				return not mercWindow.Open()
			end)

			Delay(5000, function ()
				return Me.Grouped() and Group.Member(1).Type() == "Mercenary"
			end)

			targetSpawn(elegist)
			mq.cmd.hail()
			Delay(250)

			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()

			mq.cmdf("/grouproles set %s 2", Me.CleanName())
			Delay(250)

			PrintDebugMessage(DebuggingRanks.Detail, "Is not tank: %s", not isClassMatch({"WAR","PAL","SHD"}))

			if (not isClassMatch({"WAR","PAL","SHD"})) then
				PrintDebugMessage(DebuggingRanks.Detail, "/grouproles set %s 1", Group.Member(1).Name())
				mq.cmdf("/grouproles set %s 1", Group.Member(1).Name())
				Delay(250)
				mq.cmd("/popup SET THE NEW MERC TO MAIN TANK")
			end
		end

		if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
			mq.cmd("/squelch /target clear")

			while (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") do
				farmStuff(knownTargets.infiltrator)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				navHail(Spawn("Elegist").ID())
			end
		end

		Delay(100)
		mq.cmd("/stance aggressive")
		Delay(100)

		closeDialog()
		closeDialog()
		closeDialog()

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function BasherAlga()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(8, 2)() ~= "Done") then
		if (not tutorialCheck("Hotbars")) then
			navHail(Spawn("Basher Alga").ID())
			acceptTask("Hotbars")
		end

		if (tutorialSelect("Hotbars")) then
			mq.cmd.hail()
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			closeDialog()
			getReward()
			checkSwiftness()
		end

		tutorialSelect("Basic Training")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Absor()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
		navHail(Spawn("Absor").ID())

		local mainhandItem = TLO.InvSlot("mainhand").Item
		if (mainhandItem() and mainhandItem.Name()) then
			local oldWeaponName = mainhandItem.Name():gsub("%*", "")
			Note.Info("Handing %s to Absor", oldWeaponName)

			mq.cmd.keypress("OPEN_INV_BAGS")
			if (not Window("InventoryWindow").Open()) then
				Window("InventoryWindow").DoOpen()
			end
			Delay(1000, function()
				return Window("InventoryWindow").Open()
			end)

			-- Pick up currently equipped mainhand weapon
			Window("InventoryWindow").Child("InvSlot13").LeftMouseUp()
			Delay(1000, function()
				return Cursor.ID()
			end)

			-- Give it to Absor
			mq.cmd.usetarget()
			Delay(1000, function()
				return not Cursor.ID()
			end)

			if (Window("GiveWnd").Open()) then
				Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
				Delay(1000, function()
					return not Window("GiveWnd").Open()
				end)
			end

			-- Wait for a new weapon to appear on cursor or in inventory
			Delay(2000)

			-- Sometimes lands on cursor
			if (Cursor.ID()) then
				local cursorName = Cursor.Name() or "unknown item"
				Note.Info("Received upgraded weapon on cursor: %s", cursorName)

				-- Click onto mainhand
				mq.cmd("/itemnotify mainhand leftmouseup")
				Delay(1000, function()
					return not Cursor.ID()
				end)

				if (Cursor.ID()) then
					mq.cmd.autoinventory()
					Note.Info("\arFailed to equip upgraded weapon from cursor.")
				end
			else
				-- Otherwise try to find a likely upgraded weapon in inventory
				local oldLastWord = oldWeaponName:match("%S+$")
				local newWeapon = nil

				if (oldLastWord and TLO.FindItem("=" .. oldLastWord)()) then
					newWeapon = TLO.FindItem("=" .. oldLastWord)
				elseif (oldLastWord and TLO.FindItem(oldLastWord)()) then
					newWeapon = TLO.FindItem(oldLastWord)
				end

				if (newWeapon and newWeapon.Name()) then
					local newWeaponName = newWeapon.Name()
					Note.Info("Trying to equip upgraded weapon: %s", newWeaponName)

					grabItem(newWeaponName, "left")
					Delay(1000, function()
						return Cursor.ID()
					end)

					if (Cursor.ID()) then
						mq.cmd("/itemnotify mainhand leftmouseup")
						Delay(1000, function()
							return not Cursor.ID()
						end)
					end

					if (Cursor.ID()) then
						mq.cmd.autoinventory()
						Note.Info("\arFailed to equip upgraded weapon %s", newWeaponName)
					end
				else
					Note.Info("\arCould not find upgraded weapon after giving Absor the old one.")
				end
			end

			mq.cmd.keypress("CLOSE_INV_BAGS")
		else
			Delay(1000)
			Note.Info("\arNo mainhand weapon was equipped when talking to Absor.")
		end

		closeDialog()
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function VahlaraA()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
		navHail(Spawn("Vahlara").ID())
		Delay(1000, function()
			return Cursor.ID()
		end)
		Delay(100)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
		closeDialog()
		mq.cmd.say("others")
		closeDialog()
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function VahlaraB()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Clearing the Vermin Nests") and
		Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
		navHail(Spawn("Vahlara").ID())

		getReward()
		Delay(1000, function()
			return Cursor.ID()
		end)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
		Delay(1000, function()
			return not Cursor.ID()
		end)

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function McKenzie()
	FunctionEnter(DebuggingRanks.Task)

	if (TLO.FindItemCount("=Steatite Fragment")() > 0) then
		Note.Info("\ayYou already have the augment Steatite Fragment")

		return
	end

	if (not tutorialSelect("Kickin' Things Up A Notch - Augmentation")) then
		Note.Info("\agHeaded to get that aug for the KICK ASS WEAPON YOU JUST RECEIVED!!! Hang tight...")

		local mckenzie = Spawn("McKenzie")
		navHail(mckenzie.ID())
		mq.cmd.say("lesson")
		Delay(1000)
		mq.cmd.say("listenin")
		Delay(1000, function()
			return Cursor.ID()
		end)

		while (Cursor.ID()) do
			mq.cmd.autoinventory()
			Delay(250)
		end
		closeDialog()
		closeDialog()
		insertAug()
		mckenzie.DoTarget()
		Delay(100)
		mq.cmd.hail()
		Delay(100)
		closeDialog()
		closeDialog()
		closeDialog()
	end
	FunctionDepart(DebuggingRanks.Task)
end

local function AriasA()
	FunctionEnter(DebuggingRanks.Task)

	local arias = Spawn("Arias")
	navHail(arias.ID())
	mq.cmd.say("Escape")
	acceptTask("Jail Break!")

	---@type spawn
	local jailer
	Delay(500, function ()
		jailer = Spawn("The Gloomingdeep Jailor")
		return jailer.ID() > 0
	end)

	findAndKill(jailer.ID())

	Delay(1000, function()
		return Window("AdvancedLootWnd").Open()
	end)

	if (Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip() == "The Gloomingdeep Jailor's Key") then
		Window("AdvancedLootWnd").Child("ADLW_LootBtnTemplate").LeftMouseUp()
		Delay(1000, function()
			return not Window("AdvancedLootWnd").Open()
		end)
	end

	targetSpawnById(arias.ID())

	mq.cmd.keypress("OPEN_INV_BAGS")
	if (not Window("InventoryWindow").Open()) then
		Window("InventoryWindow").DoOpen()
	end
	Delay(1000, function()
		return Window("InventoryWindow").Open()
	end)

	grabItem("The Gloomingdeep Jailor's Key", "left")
	Target.LeftClick()
	Delay(1000, function()
		return not Cursor.ID()
	end)

	Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
	Delay(1000, function()
		return not Window("GiveWnd").Open()
	end)

	closeDialog()

	FunctionDepart(DebuggingRanks.Task)
end

local function AriasB()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
		navHail(Spawn("Arias").ID())
		closeDialog()
		mq.cmd("/squelch /target clear")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function AriasC()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(9, 2)() ~= "Done") then
		navHail(Spawn("Arias").ID())
		closeDialog()
		navHail(Spawn("Arias").ID())
		Delay(1000, function()
			return Cursor.ID()
		end)
		mq.cmd.hail()
		Delay(1000, function()
			return Cursor.Name() == "Kobold Skull Charm"
		end)
		Delay(100)
		if (Cursor.ID()) then
			mq.cmd.autoinventory()
		end
		Delay(1000, function()
			return not Cursor.ID()
		end)
		mq.cmd("/squelch /target clear")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function AriasD()
	FunctionEnter(DebuggingRanks.Task)

	navHail(Spawn("Arias").ID())
	mq.cmd("/squelch /target clear")

	FunctionDepart(DebuggingRanks.Task)
end

local function ClearNests()
	FunctionEnter(DebuggingRanks.Task)

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done" and
		tutorialSelect("Clearing the Vermin Nests")) then
		workSet.Targets = { "a_cave_rat", "a_cave_bat", "vermin" }
		knownTargets.caveRat.Priority = 2
		knownTargets.caveBat.Priority = 2
		knownTargets.verminNest.Priority = 2

		while (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() == "") do
			---@type TargetInfo[]
			local targetList = {}

			if (TLO.SpawnCount("npc " .. knownTargets.rufus.Name)() > 0) then
				table.insert(targetList, knownTargets.rufus)
			end

			table.insert(targetList, knownTargets.caveRat)

			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
				knownTargets.caveRat.Priority = 3
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.caveBat)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.verminNest)
			end

			targetShortest(targetList)
			findAndKill(workSet.MyTargetID)
		end

		checkLoot("all")

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function SpiderCaves()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Spider Caves")) then
		while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
			farmStuff(knownTargets.spiderCocoon)
			checkLoot("all")
			tutorialSelect("Spider Caves")
		end

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function SpiderCavesFinish()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("Spider Caves")

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
		if (workSet.Location == "SpiderRoom") then
			leaveSpiders()
		end

		navHail(Spawn("Vahlara").ID())
		giveItems("Gloomingdeep Cocoon Silk", 4)
		getReward()
		Delay(1000, function()
			return Cursor.ID()
		end)
		mq.cmd.autoinventory()
		Delay(1000, function()
			return not Cursor.ID()
		end)

		destroyItem("Gloomingdeep Cocoon Silk")

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function SpiderTamer()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Spider Tamer Gugan")) then
		while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
			if (workSet.Location ~= "SpiderRoom") then
				gotoSpiders()
			end

			farmStuff(knownTargets.gugan)
			checkLoot("Gloomingdeep Violet")
			tutorialSelect("Spider Tamer Gugan")
		end

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function SpiderTamerFinish()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("Spider Tamer Gugan")

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
		if (workSet.Location == "SpiderRoom") then
			leaveSpiders()
		end

		navHail(Spawn("Xenaida").ID())
		giveItems("Gloomingdeep Violet", 1)
		closeDialog()
		closeDialog()

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Arachnida()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(15, 2)() ~= "Done" and
		tutorialSelect("Arachnida")) then
		workSet.Targets = { "a_gloom_spider", "a_gloomfang_lurker" }

		while (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() == "") do
			---@type TargetInfo[]
			local targetList = {}

			if (TLO.SpawnCount("npc " .. knownTargets.venomfang.Name)() > 0) then
				table.insert(targetList, knownTargets.venomfang)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.gloomSpider)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.lurkerSpider)
			end

			targetShortest(targetList)
			findAndKill(workSet.MyTargetID)
		end

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function FinishArachnida()
	FunctionEnter(DebuggingRanks.Task)

	checkLoot("")

	if (tutorialSelect("Arachnida")) then
		navHail(Spawn("Guard Rahtiz").ID())
		mq.cmd("/squelch /target clear")
		closeDialog()

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Arachnophobia()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Arachnophobia (Group)")) then
		if (workSet.Location ~= "SpiderRoom") then
			gotoSpiders()
		end

		gotoQueen()

		while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
			navToLoc(-1201, -467, 19)
			farmStuff(knownTargets.gloomfang)
		end

		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
			leaveQueen()

			navHail(Spawn("Guard Hobart").ID())

			Delay(1000, function()
				return Cursor.ID()
			end)
			mq.cmd.autoinventory()

			if (Cursor.ID()) then
				mq.cmd.autoinventory()
			end

			getReward()

			Delay(1000, function()
				return Cursor.ID()
			end)

			mq.cmd.autoinventory()
			if (Cursor.ID()) then
				mq.cmd.autoinventory()
			end
			Delay(1000, function()
				return not Cursor.ID()
			end)

			mq.cmd("/squelch /target clear")
		end

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function FreedomStand()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(10, 2)() ~= "Done") then
		if (tutorialSelect("Freedom's Stand (Group)")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				navToLoc(-262, -1723, -99)
				Delay(250)
				workSet.PullRange = 250

				local targetList = {
					knownTargets.warrior,
					knownTargets.spiritweaver,
					knownTargets.gnikan,
				}

				while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
					targetShortest(targetList)
					findAndKill(workSet.MyTargetID)
					checkLoot("")

					debuggingValues.ActionTaken = true
				end
			end
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function FreedomStandFinish()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Freedom's Stand (Group)")) then
		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
			navHail(Spawn("Guard Hobart").ID())

			local newWeapon = Window("RewardSelectionWnd/RewardPageTabWindow").Tab(1).Child("RewardSelectionItemList").List(2)()
			PrintDebugMessage(DebuggingRanks.Detail, "New weapon: \aw%s", newWeapon)

			local mainhand = TLO.InvSlot("mainhand").Item
			local availableSlot = GetAvailableInvSlot(mainhand.Size())
			local packname = "pack" .. availableSlot
			grabItem(mainhand.Name(), "left")
			invItem(packname)

			getReward()

			mq.cmd("/squelch /target clear	")

			debuggingValues.ActionTaken = true
		end
	end

	medToFull()
	checkBlessing()

	FunctionDepart(DebuggingRanks.Task)
end

local function BustedLocks()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(19, 2)() ~= "Done") then
		if (tutorialSelect("Busted Locks")) then
			checkLoot("Gloomingdeep Master Key")

			while (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") do
				workSet.TargetType = "NPC"
				navToLoc(219, -419, 24)
				farmStuff(knownTargets.locksmith)
				checkLoot("Gloomingdeep Master Key")

				debuggingValues.ActionTaken = true
			end
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function BustedLocksB()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Busted Locks")) then
		tutorialSelect("The Revolt of Gloomingdeep")
		if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() == "Done") then
			navHail(Spawn("Kaikachi").ID())
			giveItems("Gloomingdeep Master Key", 1)
			getReward()
			mq.cmd("/squelch /target clear")
			Delay(1000, function()
				return Cursor.ID()
			end)

			mq.cmd.autoinventory()

			if (Cursor.ID()) then
				mq.cmd.autoinventory()
			end
			Delay(1000, function()
				return not Cursor.ID()
			end)

			destroyItem("Gloomingdeep Master Key")

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function PitFiend()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(25, 2)() ~= "Done") then
		if (tutorialSelect("Pit Fiend (Group)")) then
			workSet.ZRadius = 1200
			navToLoc(-479, -1051, -1)
			EnterPit()
			navToLoc(-318, -1109, -147)
			local krenshin = Spawn("Krenshin")

			while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
				while (krenshin.ID() == 0 or krenshin.TargetOfTarget.ID() > 0) do
					Delay(250)
					mq.doevents()
				end
				farmStuff(knownTargets.krenshin)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
				ExitPit()
			end

			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GuardRahtizA()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
		if (not tutorialCheck("Clearing the Vermin Nests")) then
			navHail(Spawn("Guard Rahtiz").ID())
			acceptTask("Clearing the Vermin Nests")
			mq.cmd("/squelch /target clear")
		end

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GuardRahtizB()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done" and
		not tutorialCheck("Rebellion Reloaded")) then
		navHail(Spawn("Guard Rahtiz").ID())
		acceptTask("Rebellion Reloaded")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(15, 2)() ~= "Done" and
		not tutorialCheck("Arachnida")) then
		navHail(Spawn("Guard Rahtiz").ID())
		acceptTask("Arachnida")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GuardRahtizC()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
		if (not tutorialCheck("Rebellion Reloaded")) then
			navHail(Spawn("Guard Rahtiz").ID())
			acceptTask("Rebellion Reloaded")
			mq.cmd("/squelch /target clear")
		end

		if (tutorialSelect("Rebellion Reloaded")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				workSet.ZRadius = 100
				workSet.PullRange = 200
				checkLoot("CLASS 1 Wood Point Arrow")

				if (TLO.FindItemCount("=CLASS 1 Wood Point Arrow")() == 0) then
					navToKnownLoc(navLocs.RatBat)
				end

				while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done" and
					TLO.FindItemCount("=CLASS 1 Wood Point Arrow")() == 0) do
					farmStuff(knownTargets.barrel)
					checkLoot("CLASS 1 Wood Point Arrow")
				end

				navHail(Spawn("Guard Rahtiz").ID())

				if (TLO.InvSlot("Ammo").Item.ID() == 8500) then
					mq.cmd("/nomodkey /ctrlkey /itemnotify ammo leftmouseup")
				end

				giveItems("CLASS 1 Wood Point Arrow", 1)
				closeDialog()
				closeDialog()
				closeDialog()
				mq.cmd("/squelch /target clear")

				if (TLO.FindItemCount("=CLASS 1 Wood Point Arrow")() > 0 and
					TLO.FindItem("=CLASS 1 Wood Point Arrow").ItemSlot() > 22) then
					destroyItem("CLASS 1 Wood Point Arrow")
				end

				if (workSet.MyTargetID) then
					workSet.MyTargetID = 0
				end
			end

			Delay(100)
			closeDialog()
			workSet.ZRadius = 1000
		end

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GuardVyrinn()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done" and
		not tutorialCheck("Spider Caves")) then
		navHail(Spawn("Guard Vyrinn").ID())
		acceptTask("Spider Caves")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(5, 2)() ~= "Done" and
		not tutorialCheck("Spider Tamer Gugan")) then
		navHail(Spawn("Guard Vyrinn").ID())
		acceptTask("Spider Tamer Gugan")

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GuardVyrinnB()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(17, 2)() ~= "Done") then
		navHail(Spawn("Guard Vyrinn").ID())
		acceptTask("Arachnophobia (Group)")
		mq.cmd("/squelch /target clear")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GuardHobart()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("The Revolt of Gloomingdeep") and
		Window("TaskWND").Child("Task_TaskElementList").List(9, 2)() ~= "Done") then
		if (not tutorialCheck("The Battle of Gloomingdeep")) then
			navHail(Spawn("Hobart").ID())
			acceptTask("The Battle of Gloomingdeep")

			debuggingValues.ActionTaken = true
		end

		if (not tutorialCheck("Freedom's Stand (Group)")) then
			navHail(Spawn("Hobart").ID())
			acceptTask("Freedom's Stand (Group)")

			debuggingValues.ActionTaken = true
		end

		mq.cmd("/squelch /target clear")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GloomingdeepBattle()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("The Battle of Gloomingdeep")) then
		mq.cmd("/squelch /target clear")

		workSet.PullRange = 1000
		workSet.ZRadius = 500

		if (Math.Distance("-625, -1025, 1")() > (workSet.PullRange / 2)) then
			navToLoc(-625, -1025, 1)
		end

		while (Window("TaskWND").Child("Task_TaskElementList").List(5, 2)() == "") do
			if ((Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done" or
				Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") and
				Math.Distance("-625, -1025, 1")() > workSet.PullRange) then
				navToLoc(-625, -1025, 1)
			end

			local targetList = {}

			if (TLO.SpawnCount("npc " .. knownTargets.silver.Name)() > 0) then
				table.insert(targetList, knownTargets.silver)
			end

			if (TLO.SpawnCount("npc " .. knownTargets.selandoor.Name)() > 0) then
				table.insert(targetList, knownTargets.selandoor)
			end

			if (TLO.SpawnCount("npc " .. knownTargets.brokenclaw.Name)() > 0) then
				table.insert(targetList, knownTargets.brokenclaw)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.grunt)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.warrior)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.slaveWarden)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
				table.insert(targetList, knownTargets.spiritweaver)
			end

			if (#targetList > 0) then
				targetShortest(targetList)
				findAndKill(workSet.MyTargetID)
			end
		end

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GloomingdeepBattleFinish()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("The Battle of Gloomingdeep")) then
		workSet.ZRadius = 1000
		navHail(Spawn("Hobart").ID())
		Delay(1000)

		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GuardMaddocA()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(21, 2)() ~= "Done" and
		not tutorialCheck("Kobold Leadership")) then
		navHail(Spawn("Guard Maddoc").ID())
		acceptTask("Kobold Leadership")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GuardMaddocB()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(24, 2)() ~= "Done" and
		not tutorialCheck("Pit Fiend (Group)")) then
		navHail(Spawn("Guard Maddoc").ID())
		acceptTask("Pit Fiend (Group)")
		mq.cmd("/squelch /target clear")

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function KoboldLeadership()
	FunctionEnter(DebuggingRanks.Task)

	while (tutorialSelect("Kobold Leadership")) do
		local targetList = {
			knownTargets.captain,
		}

		if (TLO.SpawnCount("npc " .. knownTargets.silver.Name)() > 0) then
			table.insert(targetList, knownTargets.silver)
		end

		if (TLO.SpawnCount("npc " .. knownTargets.ratasaurus.Name)() > 0) then
			table.insert(targetList, knownTargets.ratasaurus)
		end

		targetShortest(targetList)
		findAndKill(workSet.MyTargetID)
		checkLoot("")

		debuggingValues.ActionTaken = true
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function ScoutZajeer()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		if (not tutorialCheck("Scouting Gloomingdeep")) then
			navHail(Spawn("Zajeer").ID())
			acceptTask("Scouting Gloomingdeep")
			navHail(Spawn("Zajeer").ID())
			acceptTask("Sabotage")
			Delay(1000, function ()
				return Cursor.ID()
			end)

			if (Cursor.ID()) then
				mq.cmd.autoinventory()
				Delay(1000, function ()
					return not Cursor.ID()
				end)
			end
			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function ScoutKaikachiA()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(8, 2)() ~= "Done") then
		if (not tutorialCheck("Goblin Treachery")) then
			navHail(Spawn("Kaikachi").ID())
			acceptTask("Goblin Treachery")

			debuggingValues.ActionTaken = true
		end

		mq.cmd("/squelch /target clear")
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function ScoutKaikachiB()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(19, 2)() ~= "Done") then
		if (not tutorialCheck("Busted Locks")) then
			navHail(Spawn("Kaikachi").ID())
			acceptTask("Busted Locks")
			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GoblinTreachery()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(8, 2)() ~= "Done") then
		if (tutorialSelect("Goblin Treachery")) then
			while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
				workSet.PullRange = 2000
				workSet.ZRadius = 1500

				farmStuff(knownTargets.goblinSlave)
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				EnterPit()

				workSet.TargetType = "NPC"
				workSet.PullRange = 1000
			end

			while (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") do
				if (workSet.Location == "PitTop") then
					EnterPit()
				end

				if (workSet.Location == "PitSteps") then
					navToLoc(-418, -893, -61)
				end

				navToLoc(-387.67, -658.62, -77.56)
				farmStuff(knownTargets.rookfynn)
			end

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function GoblinTreacheryFinish()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(8, 2)() ~= "Done") then
		if (tutorialSelect("Goblin Treachery")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				navHail(Spawn("Kaikachi").ID())
				getReward()
				mq.cmd("/squelch /target clear")

				debuggingValues.ActionTaken = true
			end
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function Sabotage()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(7, 2)() ~= "Done") then
		if (tutorialSelect("Sabotage")) then
			local supplyBox = Spawn("kobold siege supplies")
			repeat
				navToSpawn(supplyBox.ID())
				targetSpawnById(supplyBox.ID())
				giveItems("Makeshift Lantern Bomb", 1)
				mq.cmd("/squelch /target clear")
				navToLoc(-254, -1539, -105)
			until TLO.FindItemCount("=Makeshift Lantern Bomb")() == 0

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function ScoutingGloomingdeepA()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		if (tutorialSelect("Scouting Gloomingdeep")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
				navToLoc(-47, -849, -29)

				debuggingValues.ActionTaken = true
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(2, 2)() ~= "Done") then
				navToLoc(-226, -866, -1)

				debuggingValues.ActionTaken = true
			end
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function ScoutingGloomingdeepB()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		if (tutorialSelect("Scouting Gloomingdeep")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(3, 2)() ~= "Done") then
				navToLoc(-519, -1101, 3)

				debuggingValues.ActionTaken = true
			end

			if (Window("TaskWND").Child("Task_TaskElementList").List(4, 2)() ~= "Done") then
				navToLoc(-254, -1539, -105)

				debuggingValues.ActionTaken = true
			end
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function ScoutingGloomingdeepC()
	FunctionEnter(DebuggingRanks.Task)

	tutorialSelect("The Revolt of Gloomingdeep")

	if (Window("TaskWND").Child("Task_TaskElementList").List(6, 2)() ~= "Done") then
		if (tutorialSelect("Scouting Gloomingdeep")) then
			if (Window("TaskWND").Child("Task_TaskElementList").List(5, 2)() ~= "Done") then
				navHail(Spawn("Zajeer").ID())
				getReward()
				mq.cmd("/squelch /target clear")

				debuggingValues.ActionTaken = true
			end
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function FlutterwingA()
	FunctionEnter(DebuggingRanks.Task)

	if (not tutorialCheck("Flutterwing's Dilemma")) then
		tutorialSelect("The Revolt of Gloomingdeep")

		if (Window("TaskWND").Child("Task_TaskElementList").List(23, 2)() ~= "Done") then
			navHail(Spawn("Flutterwing").ID())
			mq.cmd.say("Siblings")
			acceptTask("Flutterwing's Dilemma")
			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function FlutterwingB()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Flutterwing's Dilemma")) then
		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") then
			navToLoc(713, -259, -10)

			workSet.PullRange = 150
			knownTargets.plaguebearer.Priority = 2
			knownTargets.warrior.Priority = 3
			knownTargets.ruga.Priority = 4

			local targetList = {
				knownTargets.plaguebearer,
				knownTargets.warrior,
				knownTargets.ruga,
			}

			while (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() ~= "Done") do
				targetShortest(targetList)
				findAndKill(workSet.MyTargetID)

				checkLoot("Flutterwing's Unhatched Sibling")
			end

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

local function FlutterwingC()
	FunctionEnter(DebuggingRanks.Task)

	if (tutorialSelect("Flutterwing's Dilemma")) then
		tutorialSelect("The Revolt of Gloomingdeep")

		if (Window("TaskWND").Child("Task_TaskElementList").List(1, 2)() == "Done") then
			navHail(Spawn("Flutterwing").ID())
			giveItems("Flutterwing's Unhatched Sibling", 1)
			mq.cmd("/squelch /target clear")

			debuggingValues.ActionTaken = true
		end
	end

	FunctionDepart(DebuggingRanks.Task)
end

-- ─── Orchestrators ────────────────────────────────────────────────────────────

local function JailBreak()
	closeAlert()
	AriasA()
	zoning()
end

local function BasicTraining()
	if (tutorialSelect("Basic Training")) then
		closeDialog()

		AriasB()
		Elegist()
		Absor()
		Xenaida()
		Farquard()
		LuclinPriest()
		Wijdan()
		Lyndroh()
		Rytan()
		Prathun()
		Rashere()
		BasherAlga()
		Poxan()
		VahlaraA()
		McKenzie()
		Frizznik()
		AriasC()

		debuggingValues.ActionTaken = true
	end
end

local function GloomingdeepRevolt()
	if (tutorialSelect("The Revolt of Gloomingdeep")) then
		checkStep()
		medToFull()
		checkStep()
		GuardRahtizA()
		checkStep()

		if (Me.AltAbilityReady(481)) then
			mq.cmd.alt("act 481")
			Delay(1000, function ()
				return Me.Casting.ID()
			end)
			Delay(5000, function ()
				return not Me.Casting.ID()
			end)
		end

		ClearNests()

		if (#lootedItems > 0) then
			handleLoot(true)
		end

		checkStep()
		VahlaraB()

		checkStep()
		GuardRahtizB()
		GuardVyrinn()
		checkStep()
		Arachnida()
		checkStep()
		SpiderCaves()
		checkStep()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 6 or Me.Subscription() == "SILVER" and Me.Level() < 5 or Me.Level() < 4
		end,
		function ()
			workSet.PullRange = 1000
			navToLoc(-605, -372, -41)
		end,
		{
			knownTargets.gloomSpider,
			knownTargets.lurkerSpider,
		})

		SpiderTamer()
		checkStep()

		FinishArachnida()
		SpiderCavesFinish()
		SpiderTamerFinish()
		checkStep()

		if (#lootedItems > 0) then
			handleLoot(false)
		end

		buyClassPet()

		checkStep()
		GuardRahtizC()

		checkLoot("")

		checkContinue()

		checkBlessing()

		FlutterwingA()
		GuardVyrinnB()
		checkStep()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 8 or Me.Subscription() == "SILVER" and Me.Level() < 6 or Me.Level() < 5
		end,
		function ()
			workSet.PullRange = 500
			workSet.ZRadius = 1000
			navToLoc(-605, -372, -41)
		end,
		{
			knownTargets.gloomSpider,
			knownTargets.lurkerSpider,
		})

		Arachnophobia()
		checkStep()

		levelUp(function ()
			return Me.Level() < 6
		end,
		function ()
			workSet.PullRange = 500
			workSet.ZRadius = 1000
			navToLoc(-605, -372, -41)
			knownTargets.gloomSpider.Priority = 11

		end,
		{
			knownTargets.gloomSpider,
			knownTargets.lurkerSpider,
		})

		GuardHobart()
		GuardMaddocA()
		checkStep()
		ScoutZajeer()
		ScoutKaikachiA()
		checkStep()
		ScoutingGloomingdeepA()
		checkStep()
		GloomingdeepBattle()
		checkStep()
		GoblinTreachery()
		checkStep()
		ScoutingGloomingdeepB()
		checkStep()
		Sabotage()
		checkStep()
		KoboldLeadership()
		checkStep()
		GloomingdeepBattleFinish()
		checkStep()
		GuardMaddocB()
		checkStep()

		buyClassPet()

		checkContinue()

		checkBlessing()

		checkStep()
		ScoutingGloomingdeepC()
		checkStep()
		GoblinTreacheryFinish()
		checkStep()
		ScoutKaikachiB()
		checkStep()
		BustedLocks()
		checkStep()
        BustedLocksB()
		checkStep()


		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 13 or Me.Subscription() == "SILVER" and Me.Level() < 12 or Me.Level() < 10
		end,
		function ()
			workSet.PullRange = 500
			workSet.ZRadius = 1000

			knownTargets.slaveWarden.Priority = 10
			knownTargets.goblinSlave.Priority = 11
			knownTargets.diseasedRat.Priority = 11

			navToLoc(219, -419, 24)
		end,
		{
			knownTargets.warrior,
			knownTargets.spiritweaver,
			knownTargets.goblinSlave,
			knownTargets.diseasedRat,
			knownTargets.slaveWarden,
			knownTargets.locksmith,
		})

		FlutterwingB()
		checkStep()
		FlutterwingC()
		checkStep()

		checkContinue()

		checkBlessing()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 13 or Me.Subscription() == "SILVER" and Me.Level() < 12 or Me.Level() < 11
		end,
		function ()
			workSet.PullRange = 350
			workSet.ZRadius = 500

			knownTargets.goblinSlave.Priority = 11
			knownTargets.diseasedRat.Priority = 11

			navToLoc(752, -344, -13)
		end,
		{
			knownTargets.ruga,
			knownTargets.warrior,
			knownTargets.diseasedRat,
			knownTargets.goblinSlave,
			knownTargets.spiritweaver,
			knownTargets.slaveWarden,
			knownTargets.plaguebearer,
			knownTargets.pox,
		})

		FreedomStand()
		checkStep()
		FreedomStandFinish()
		checkStep()

		levelUp(function ()
			return Me.Subscription() == "FREE" and Me.Level() < 13 or Me.Subscription() == "SILVER" and Me.Level() < 13 or Me.Level() < 12
		end,
		function ()
			workSet.PullRange = 250
			workSet.ZRadius = 250

			navToLoc(-262, -1723, -99)
		end,
		{
			knownTargets.warrior,
			knownTargets.captain,
			knownTargets.spiritweaver,
			knownTargets.gnikan,
		})

		PitFiend()
		checkStep()
		AriasD()
	end
end

-- ─── Setup ────────────────────────────────────────────────────────────────────

local function basicSetup()
	if (TLO.Plugin("MQ2AutoForage")()) then
		mq.cmd.stopforage()
	end

	if (TLO.Plugin("MQ2AutoLoot")()) then
		mq.cmd.autoloot("turn off")
	end

	checkPlugin("MQ2Nav")
	checkPlugin("MQ2MoveUtils")
	checkPlugin("MQ2Melee")
	checkPlugin("MQ2Cast")

	mq.cmd("/squelch /melee taunt=off")
	checkZone()
	openTaskWnd()
	mq.cmd("/squelch /melee melee=1")
	loadIgnores()
	checkMesh()
	whereAmI()
end

-- ─── Bind commands ────────────────────────────────────────────────────────────
---@param debug? string
mq.bind("/step",   Tasks.bindStep)
mq.bind("/resume", Tasks.bindResume)

-- ─── Steps table and processArgs ─────────────────────────────────────────────
local args = {...}
local steps = CreateIcaseTable({
	JailBreak      = JailBreak,
	BasicTraining  = BasicTraining,
	Hotbars        = BasherAlga,
	AriasB         = AriasB,
	Lyndroh        = Lyndroh,
	Absor          = Absor,
	Rytan          = Rytan,
	Elegist        = Elegist,
	Guard_RahtizA  = GuardRahtizA,
	ClearNests     = ClearNests,
	VahlaraB       = VahlaraB,
	Guard_Vyrinn   = GuardVyrinn,
	Guard_RahtizB  = GuardRahtizB,
	Guard_RahtizC  = GuardRahtizC,
	Arachnida      = Arachnida,
	SpiderCaves    = SpiderCaves,
	SpiderTamer    = SpiderTamer,
	WhereAmI       = whereAmI,
	SellLoot       = sellInventory,
	ScribeSpells   = Scribing.ScribeSpells,
})

local function processArgs()
	if (#args == 0) then
		return
	end

	local index = 1
	local action = tostring(args[index]):lower()

	if (action == "step") then
		debuggingValues.StepProcessing = true
		workSet.ResumeProcessing = false
		workSet.LockContinue = false
		workSet.WaitingForResume = false

		return
	end

	if (action == "nopause") then
		workSet.ResumeProcessing = false
		workSet.LockContinue = false
		workSet.WaitingForResume = false

		return
	end

	basicSetup()

	if (action == "debug") then
		DebugLevel = DebuggingRanks.Deep
		index = index + 1
	end

	action = tostring(args[index]):lower()
	index = index + 1

	if (action == "tutorialcheck") then
		local checkFor = table.concat(args, ' ', index)
		Note.Info("TutorialCheck \ag%s\ax: \ay%s", checkFor, tutorialCheck(checkFor))
	elseif (action == "tutorialselect") then
		local checkFor = table.concat(args, ' ', index)
		Note.Info("TutorialSelect \ag%s\ax: \ay%s", checkFor, tutorialSelect(checkFor))
	elseif (action == "navspawn") then
		navToSpawn(Spawn(args[index]).ID(), findAndKill)
	elseif (action == "navloc") then
		navToLoc(args[index], args[index + 1], args[index + 2])
	elseif (action == "farmstuff") then
		---@type TargetInfo
		local enemy = {
			Name = table.concat(args, ' ', index + 1),
			Type = tostring(args[index])
		}
		farmStuff(enemy)
	elseif (action == "targetshortest") then
		---@type TargetInfo
		local target = {
			Name = table.concat(args, ' ', index + 1),
			Type = tostring(args[index])
		}
		local mobList = {}
		local spawnPattern = string.format("noalert 1 targetable radius %s zradius %s", 1500, 1500)
		local searchExpression = string.format("%s %s \"%s\"", spawnPattern, target.Type, target.Name)

		local mobsInRange = TLO.SpawnCount(searchExpression)()
		PrintDebugMessage(DebuggingRanks.None, "# mobs in range: %s", mobsInRange)

		for i = 1, mobsInRange do
			local nearest = TLO.NearestSpawn(i, searchExpression)

			if (nearest.Name() ~= nil and (nearest.TargetOfTarget.ID() == 0 or nearest.TargetOfTarget.Type() == "NPC")) then
				PrintDebugMessage(DebuggingRanks.None, "\atFound %s — maybe, lets see if it has a path", nearest.Name())

				if (Navigation.PathExists("id " .. nearest.ID())()) then
					---@type MobInfo
					local mobInfo = {
						Distance = Navigation.PathLength("id " .. nearest.ID())(),
						Type = target.Type,
						Priority = target.Priority or 10
					}
					mobList[nearest.ID()] = mobInfo
					PrintDebugMessage(DebuggingRanks.None, "Found path to \aw%s\ax (\aw%s\ax): %s", nearest.Name(), nearest.ID(), mobInfo)
				end
			end
		end

		local sortedKeys = sortMobIds(mobList)
		PrintDebugMessage(DebuggingRanks.None, "Sorted (by path lengt asc) mob list")

		for _, key in ipairs(sortedKeys) do
			PrintDebugMessage(DebuggingRanks.None, "%s: %s", key, mobList[key])
		end
	elseif (steps[action]) then
		steps[action]()
	end

	mq.exit()
end

-- ─── Main ─────────────────────────────────────────────────────────────────────

local function Main()
	basicSetup()

	if (ZoneInfo.ID() == 188) then
		checkMesh()
		JailBreak()
	end

	checkZone()

	if (ZoneInfo.ID() == 189) then
		Delay(1000)
		Note.Info("Let's get this party started!")
		whereAmI()
		openTaskWnd()

		BasicTraining()

		checkBlessing()

		GloomingdeepRevolt()

		Note.Info("The Tutorial Quest is now complete.")

		if (workSet.AutoCampDesktop) then
			mq.cmd("/sit")
			Delay(500)
			mq.cmd("/camp desktop")
		elseif (workSet.AutoCamp) then
			mq.cmd("/sit")
			Delay(500)
			mq.cmd("/camp")
		end
	else
		Note.Info("\arYou can't use this here! This is for the tutorial!")
	end
end

-- ─── Events ───────────────────────────────────────────────────────────────────

local function Event_LevelUp()
	closeDialog()
end

mq.event("LevelUp", "#*#You have gained a level!#*#", Event_LevelUp)

-- ─── Args processing ──────────────────────────────────────────────────────────
processArgs()

-- ─── ImGui registration ───────────────────────────────────────────────────────
ImGui.Register('TutorialGUI', TutorialUI.render)

-- ─── Main loop ────────────────────────────────────────────────────────────────
while (true) do
	local ok, err = xpcall(Main, debug.traceback)

	if (ok) then
		break
	end

	if (tostring(err):find(RESPAWN_RESTART_SIGNAL, 1, true)) then
		Note.Info("Respawn detected: restarting task flow from top")
	else
		error(err)
	end
end
