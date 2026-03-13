---@file Loot.lua
--- Loot, vendor, and reward functions extracted from init.lua.

---@type Mq
local mq = require("mq")
require("inc.Global")
---@type Note
local Note = require("ext.Note")
local State = require("core.State")
local Utility = require("core.Utility")
local Tasks = require("core.Tasks")
local SpellMgmt = require("core.SpellMgmt")

---@type Scribing
local Scribing = require("inc.Scribing")

local workSet = State.workSet
local lootedItems = State.lootedItems
local destroyList = State.destroyList

local isClassMatch = Utility.isClassMatch
local closeDialog = Tasks.closeDialog

local TLO = mq.TLO
local Me = TLO.Me
local Cursor = TLO.Cursor
local Spawn = TLO.Spawn
local Target = TLO.Target
local Merchant = TLO.Merchant
local Window = TLO.Window
local Navigation = TLO.Navigation

local Loot = {}

--- Callback slots (set by the caller to wire up cross-module dependencies)
Loot._navHail = nil           -- wired by init.lua to navHail
Loot._getNextXTarget = nil    -- wired by init.lua to getNextXTarget
Loot._navToSpawn = nil        -- wired by init.lua to navToSpawn
Loot._findAndKill = nil       -- wired by init.lua to findAndKill
Loot._targetSpawnById = nil   -- wired by init.lua to targetSpawnById
Loot._destroyItem = nil       -- wired by init.lua to destroyItem

--- Get quest reward from window.
function Loot.getReward()
	FunctionEnter()

	Delay(15000, function()
		return Window("RewardSelectionWnd").Open()
	end)
	Delay(1000)

	local giveUpTime = os.time() + (Window("RewardSelectionWnd/RewardPageTabWindow").TabCount() * 5)

	while (Window("RewardSelectionWnd").Open() and os.time() < giveUpTime) do
		Window("RewardSelectionWnd/RewardPageTabWindow").Tab(1).Child("RewardSelectionChooseButton").LeftMouseUp()
		Delay(1000, function()
			return Cursor.ID()
		end)

		if (Cursor.ID()) then
			mq.cmd.autoinventory()
			Delay(1000, function()
				return not Cursor.ID()
			end)
			Delay(100)
		end
	end

	FunctionDepart()
end

--- Leave an item on corpse.
function Loot.leaveItem()
	FunctionEnter()
	PrintDebugMessage(DebuggingRanks.Detail, "Leave \a-w%s", Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip())

	if (Window("AdvancedLootWnd").Child("ADLW_LeaveBtnTemplate").Enabled()) then
		Window("AdvancedLootWnd").Child("ADLW_LeaveBtnTemplate").LeftMouseUp()
		Delay(100)
	end

	FunctionDepart()
end

--- Loot a specific item.
function Loot.lootItem()
	FunctionEnter()

	local itemName = Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip()
	local invItem = TLO.FindItem("=" .. itemName)

	if (invItem() and invItem.Lore()) then
		Loot.leaveItem()
	else
		PrintDebugMessage(DebuggingRanks.Detail, "Loot \ay%s", itemName)

		if (Window("AdvancedLootWnd").Child("ADLW_LootBtnTemplate").Enabled()) then
			Window("AdvancedLootWnd").Child("ADLW_LootBtnTemplate").LeftMouseUp()
			Delay(100)

			if (Window("ConfirmationDialogBox").Open()) then
				Window("ConfirmationDialogBox").Child("CD_Yes_Button").LeftMouseUp()
				Delay(2000, function ()
					return not Window("ConfirmationDialogBox").Open()
				end)

				PrintDebugMessage(DebuggingRanks.Deep, "Total \ay%s\ax in inventory: \aw%s", itemName, TLO.FindItemCount("=" .. itemName))
			end
		end
	end

	FunctionDepart()
end

--- Main loot checking function.
---@param itemNeeded string
function Loot.checkLoot(itemNeeded)
	FunctionEnter()

	local xtarget = Loot._getNextXTarget()

	PrintDebugMessage(DebuggingRanks.Function, "AdvancedLootWnd Open: %s, Child ADLW_ItemBtnTemplate Open: %s, xtarget == nil: %s", Window("AdvancedLootWnd").Open(), Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Open(), xtarget == nil)
	PrintDebugMessage(DebuggingRanks.Detail, "Check to loot item '\ag%s\ax'", itemNeeded)

	while (Window("AdvancedLootWnd").Open() and Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Open() and xtarget == nil) do
		PrintDebugMessage(DebuggingRanks.Function, "Current item: '\aw%s\ax'", Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip())

		if (itemNeeded == "all" or Window("AdvancedLootWnd").Open() and Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip() == itemNeeded) then
			if (itemNeeded == "all") then
				table.insert(lootedItems, Window("AdvancedLootWnd").Open() and Window("AdvancedLootWnd").Child("ADLW_ItemBtnTemplate").Tooltip())
			end

			Loot.lootItem()
		else
			Loot.leaveItem()
		end

		xtarget = Loot._getNextXTarget()
	end

	FunctionDepart()
end

--- Sell a specific item to the current merchant target.
---@param itemName string
local function sellItem(itemName)
	FunctionEnter()

	local item = TLO.FindItem(itemName)

	if (item.Stack() and not item.NoTrade()) then
		PrintDebugMessage(DebuggingRanks.Deep, "Sell %s %s to %s", item.Stack(), item.Name(), Target.CleanName())
		mq.cmdf("/selectitem \"%s\"", item.Name())
		Delay(250)

		Merchant.Sell(item.Stack())

		Delay(1500, function ()
			return not item.Stack()
		end)
	elseif (item.NoTrade()) then
		PrintDebugMessage(DebuggingRanks.Deep, "Add %s to destroy list", item.Name())
		table.insert(destroyList, item.Name())
	end

	FunctionDepart()
end

--- Sell all looted items at the Wijdan vendor.
function Loot.sellLoot()
	FunctionEnter()

	if (#lootedItems > 0) then
		local wijdan = Spawn("Wijdan")
		Loot._navHail(wijdan.ID())
		closeDialog()

		Delay(150)

		--Target.RightClick()
		Merchant.OpenWindow()

		Delay(5000, function ()
			return Merchant.Open()
		end)

		Delay(10000, function ()
			return Merchant.ItemsReceived()
		end)

		if (Merchant.Open()) then
			for _, name in ipairs(lootedItems) do
				if (isClassMatch({"NEC", "SHD"}) and name == "Bone Chips") then
					PrintDebugMessage(DebuggingRanks.Basic, "Keeping bone chips for Necro pet")
				else
					sellItem(name)
				end
			end

			-- Clear the shared lootedItems table in-place
			for i = #lootedItems, 1, -1 do
				lootedItems[i] = nil
			end
		else
			PrintDebugMessage(DebuggingRanks.Basic, "Could not establish merchant mode")
		end
	end

	FunctionDepart()
end

--- Sell all non-NoDrop inventory items.
function Loot.sellInventory()
	FunctionEnter()

	for pack=23, 22 + Me.NumBagSlots() do
		--|** Check Top Level Inventory Slot to see if it has something in it **|
		local item = Me.Inventory(pack)

		if (item.ID()) then
			--|** Check Top Level Inventory Slot for bag/no bag **|
			if (item.Container() == 0) then
				--|** If it's not a bag do this **|
				if (not item.NoDrop()) then
					table.insert(lootedItems, item.Name())
				end
			else
				--|** If it's a bag do this **|
				for slot=1,Me.Inventory(pack).Container() do
					local packItem = item.Item(slot)

					if (not packItem.NoDrop()) then
						table.insert(lootedItems, packItem.Name())
					end
				end
			end
		end
	end

	Loot.sellLoot()

	FunctionDepart()
end

--- Buy pet reagents from current merchant.
---@return boolean purchased
function Loot.buyPetReagent()
	FunctionEnter()

	local reagent
	local purchased = false

	if (isClassMatch({"MAG"})) then
		reagent = "Malachite"
	elseif (isClassMatch({"NEC"})) then
		reagent = "Bone Chips"
	end

	if (reagent) then
		PrintDebugMessage(DebuggingRanks.Deep, "Buy reagent: \ay%s", reagent)
		Merchant.SelectItem("=" .. reagent)

		Delay(3500, function ()
			return Merchant.SelectedItem() and Merchant.SelectedItem.Name() == reagent
		end)

		PrintDebugMessage(DebuggingRanks.Deep, "SelectedItem: \ag%s", Merchant.SelectedItem.Name())
		PrintDebugMessage(DebuggingRanks.Deep, "Found reagent: \ag%s", Merchant.SelectedItem.Name() == reagent)
		if (Merchant.SelectedItem.Name() == reagent) then
			PrintDebugMessage(DebuggingRanks.Deep, "Figure out how many %s to buy", reagent)
			local maxQuantity = 5
			local reagentListItem = Window("MerchantWnd").Child("MW_ItemList")

			if (reagentListItem.List(reagentListItem.GetCurSel(), 3)() ~= "--") then
				maxQuantity = tonumber(reagentListItem.List(reagentListItem.GetCurSel(), 3)()) --[[@as integer]]

				if (maxQuantity > 5) then
					maxQuantity = 5
				end
			end

			local quantity = maxQuantity - TLO.FindItemCount(reagent)()
			PrintDebugMessage(DebuggingRanks.Deep, "Buy %s %s", quantity, reagent)

			local countBefore = TLO.FindItemCount("=" .. reagent)()
			Merchant.Buy(quantity)

			Delay(1500, function ()
				PrintDebugMessage(DebuggingRanks.Deep, "wait for reagent in inv")
				return TLO.FindItemCount("=" .. reagent)() > countBefore
			end)

			purchased = TLO.FindItemCount("=" .. reagent)() > countBefore
		end
	end

	FunctionDepart()
	return purchased
end

--- Restock pet reagents by navigating to vendor.
function Loot.restockPetReagent()
	FunctionEnter()

	State.isRestocking = true

	local reagent
	if (isClassMatch({"MAG"})) then
		reagent = "Malachite"
	elseif (isClassMatch({"NEC"})) then
		reagent = "Bone Chips"
	end

	if (reagent) then
		Note.Info("Restocking reagent: \ay%s\ax", reagent)

		if (Navigation.Active()) then
			mq.cmd.nav("stop")
			Delay(500, function() return not Navigation.Active() end)
		end

		local wijdan = Spawn("Wijdan")
		Loot._navHail(wijdan.ID())
		closeDialog()
		Delay(150)

		Merchant.OpenWindow()

		Delay(5000, function()
			return Merchant.Open()
		end)

		Delay(10000, function()
			return Merchant.ItemsReceived()
		end)

		if (Merchant.Open()) then
			local purchased = Loot.buyPetReagent()
			if (not purchased) then
				Note.Warn("\arReagent unavailable from merchant, abandoning pet spell for this run.")
				workSet.PetReagentUnavailable = true
			end
		end

		if (Merchant.Open()) then
			Window("MerchantWnd").DoClose()
			Delay(1500, function()
				return not Merchant.Open()
			end)
		end
	end

	State.isRestocking = false

	FunctionDepart()
end

--- Buy class pet spell from merchant.
function Loot.buyClassPet()
	FunctionEnter()

	local merchantName
	local spellName
	if (isClassMatch({"MAG"}) and Me.Level() >= 4 and Me.Pet.ID() == 0) then
		merchantName = "Tinkerer Gordish"
		spellName = "Elementalkin: Air"
	elseif (isClassMatch({"NEC"}) and Me.Level() >= 4 and Me.Pet.ID() == 0) then
		merchantName = "Tinkerer Oshran"
		spellName = "Leering Corpse"
	elseif (isClassMatch({"BST"}) and Me.Level() >= 8 and Me.Pet.ID() == 0) then
		merchantName = "Celrak"
		spellName = "Spirit of Sharik"
	end

	if (merchantName and not Me.Book(spellName)()) then
		local merchant = Spawn(merchantName)

		Loot._navToSpawn(merchant.ID(), Loot._findAndKill)
		Loot._targetSpawnById(merchant.ID())

		Merchant.OpenWindow()

		Delay(5000, function ()
			return Window("MerchantWnd").Open()
		end)

		Delay(10000, function ()
			return Merchant.ItemsReceived()
		end)

		if (Merchant.Open()) then
			local buySpellName = "Spell: " .. spellName
			Merchant.SelectItem(buySpellName)

			Delay(3500, function ()
				return Merchant.SelectedItem() and Merchant.SelectedItem.Name() == buySpellName
			end)

			Merchant.Buy(1)

			Delay(1500, function ()
				PrintDebugMessage(DebuggingRanks.Deep, "wait for spell in inv")
				PrintDebugMessage(DebuggingRanks.Deep, "spellName: %s", buySpellName)
				return TLO.FindItemCount(buySpellName)() > 0
			end)

			PrintDebugMessage(DebuggingRanks.Deep, "'\ag%s\ax' inv count: %s", buySpellName, TLO.FindItemCount(buySpellName))
			if (TLO.FindItemCount(buySpellName)() > 0) then
				-- DebugLevel = DebuggingRanks.Deep
				-- currentDebugLevel = DebuggingRanks.Deep
				Scribing.ScribeSpells()
				-- DebugLevel = DebuggingRanks.Basic
				-- currentDebugLevel = DebuggingRanks.Basic

				if (not Me.Gem(workSet.PetGem).ID()) then
					SpellMgmt.memSpell(workSet.PetGem, spellName)

					Delay(5000, function ()
						return Me.GemTimer(workSet.PetGem)() == 0
					end)

					SpellMgmt.checkPet()
				end
			end
		else
			PrintDebugMessage(DebuggingRanks.Basic, "Could not establish merchant mode")
		end
	end

	FunctionDepart()
end

--- Handle loot decisions: sell looted items, optionally buy reagent, destroy no-trade items.
---@param buyReagent boolean
function Loot.handleLoot(buyReagent)
	FunctionEnter()

	Loot.sellLoot()

	if (buyReagent) then
		Loot.buyPetReagent()
	end

	if (Merchant.Open()) then
		Window("MerchantWnd").DoClose()

		Delay(1500, function ()
			return not Merchant.Open()
		end)
	end

	for _, name in ipairs(destroyList) do
		Loot._destroyItem(name)
	end

	FunctionDepart()
end

return Loot
