---@file SpellMgmt.lua
--- Spell/casting management functions extracted from init.lua.

local mq = require("mq")
require("inc.Global")
local Note = require("ext.Note")
local State = require("core.State")
local Utility = require("core.Utility")

local workSet = State.workSet

local TLO = mq.TLO
local Me = TLO.Me
local Target = TLO.Target
local Window = TLO.Window
local Navigation = TLO.Navigation

local isClassMatch = Utility.isClassMatch

local SpellMgmt = {}

-- callback slots for cross-module deps
SpellMgmt._restockPetReagent = nil  -- wired by init.lua to Loot.restockPetReagent
SpellMgmt._targetSpawnById = nil    -- wired by init.lua to targetSpawnById

function SpellMgmt.casting()
	FunctionEnter()

	Delay(1000, function ()
		return Window("CastingWindow").Open()
	end)

	while ((Me.Casting.ID() and not isClassMatch({"BRD"})) or Window("CastingWindow").Open()) do
		Delay(100)
	end

	FunctionDepart()
end

---@param ItemToCast string
function SpellMgmt.castItem(ItemToCast)
	FunctionEnter()

	mq.cmdf("/casting \"%s\"|Item", ItemToCast)
	Delay(1000, function()
		return Me.Casting.ID()
	end)
	Delay(TLO.FindItem("=" .. ItemToCast).CastTime.TotalSeconds() * 1000, function()
		return not Me.Casting.ID()
	end)

	FunctionDepart()
end

---@param gem integer
function SpellMgmt.castSpell(gem)
	FunctionEnter()

	if (not Me.Moving()) then
		mq.cmd.cast(gem)
		SpellMgmt.casting()
	end

	FunctionDepart()
end

---@param gem integer
function SpellMgmt.castThenRetarget(gem)
	FunctionEnter()

	if (not Me.Moving()) then
		local currentTarget = Target.ID()
		mq.cmd.target(Me.CleanName())
		mq.cmd.cast(gem)
		SpellMgmt.casting()
		SpellMgmt._targetSpawnById(currentTarget)
	end

	FunctionDepart()
end

---@param gem integer
function SpellMgmt.clearGem(gem)
	FunctionEnter()

	if (gem < 1 or gem > Me.NumGems()) then
		return
	end

	if (Me.Gem(gem).ID()) then
		Window("CastSpellWnd").Child("CSPW_Spell" .. gem).RightMouseUp()

		Delay(250, function ()
			return not Me.Gem(gem).ID()
		end)
	end

	FunctionDepart()
end

---@param gem integer
---@param spellName string
function SpellMgmt.memSpell(gem, spellName)
	FunctionEnter()

	PrintDebugMessage(DebuggingRanks.Basic, "Load spell '\at%s\ax' into slot %s", spellName, gem)
	mq.cmdf("/memspell %s \"%s\"", gem, spellName)

	Delay(2000, function()
		return Window("SpellBookWnd").Open()
	end)

	Delay(15000, function()
		return Me.Gem(gem).Name() == spellName or not Window("SpellBookWnd").Open()
	end)

	if (Window("SpellBookWnd").Open()) then
		Window("SpellBookWnd").DoClose()
	end

	FunctionDepart()
end

function SpellMgmt.exchangeSpells()
	FunctionEnter()

	local spell1 = Me.Gem(1).Name()
	local spell2 = Me.Gem(2).Name()

	SpellMgmt.clearGem(1)
	SpellMgmt.clearGem(2)

	SpellMgmt.memSpell(1, spell2)
	SpellMgmt.memSpell(2, spell1)

	FunctionDepart()
end

function SpellMgmt.checkPet()
	FunctionEnter()

	if (Me.Pet.ID() == 0 and Me.Gem(workSet.PetGem).ID()) then
		local needPet = false

		if (isClassMatch({"MAG"}) and Me.Level() >= 4) then
			needPet = true
		elseif (isClassMatch({"NEC"}) and Me.Level() >= 4) then
			needPet = true
		elseif (isClassMatch({"BST"}) and Me.Level() >= 8) then
			needPet = true
		end

		if (needPet) then
			local reagent = nil
			if (isClassMatch({"MAG"})) then
				reagent = "Malachite"
			elseif (isClassMatch({"NEC"})) then
				reagent = "Bone Chips"
			end

			if (reagent ~= nil and TLO.FindItemCount("=" .. reagent)() == 0) then
				if (not State.isRestocking and not workSet.PetReagentUnavailable) then
					Note.Info("\arMissing reagent '%s', restocking...", reagent)
					SpellMgmt._restockPetReagent()
				end
			else
				if (Navigation.Active()) then
					mq.cmd.nav("stop")
				end

				Delay(1500, function()
					return not Me.Moving()
				end)

				Delay(350)

				mq.cmd.cast(workSet.PetGem)
				SpellMgmt.casting()
			end
		end
	end

	FunctionDepart()
end

return SpellMgmt
