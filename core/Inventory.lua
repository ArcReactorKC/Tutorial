---@file Inventory.lua
--- Inventory management functions extracted from init.lua.
--- Covers item manipulation, slot management, and giving items to NPCs.

---@type Mq
local mq = require("mq")
require("inc.Global")
---@type Note
local Note = require("ext.Note")
local State = require("core.State")

local workSet = State.workSet

local TLO = mq.TLO
local Me = TLO.Me
local Cursor = TLO.Cursor
local Target = TLO.Target
local Window = TLO.Window

local Inventory = {}

--- Pick up / grab an item by name using /itemnotify.
---@param itemName string
---@param action string  "left" or "right"
function Inventory.grabItem(itemName, action)
	FunctionEnter()

	---@type string
	local keypress = ""
	if (action == "left") then
		keypress = "leftmouseup"
	else
		keypress = "rightmouseup"
	end

	local item = TLO.FindItem(itemName)
	local baseCmd = "/squelch /nomodkey /ctrl /itemnotify"
	local itemDetail

	if (item.ItemSlot() < 23 or item.ItemSlot2() == nil or item.ItemSlot2() == -1) then
		itemDetail = string.format("\"%s\"", item.Name())
	else
		itemDetail = string.format("in pack%s %s", item.ItemSlot() - 22, item.ItemSlot2() + 1)
	end

	mq.cmdf("%s %s %s", baseCmd, itemDetail, keypress)

	FunctionDepart()
end

--- Destroy all copies of the named item from inventory.
---@param itemName string
function Inventory.destroyItem(itemName)
	FunctionEnter()

	while (TLO.FindItemCount(itemName)() > 0) do
		Inventory.grabItem(itemName, "left")

		mq.cmd.destroy()

		Delay(1000, function ()
			return not Cursor.ID()
		end)
	end

	FunctionDepart()
end

--- Determine which top-level inventory slot is available for placing an item
---@return integer
function Inventory.getAvailableTopInvSlot()
	FunctionEnter()

    -- Find the first top-level inventory slot without anything in it
    for i = 1, Me.NumBagSlots() do
        local inv = TLO.InvSlot("pack" .. i).Item

        if (not inv.Container() and not inv.ID()) then
            return i
        end
    end

    -- Find the first top-level inventory slot without a container in it
    for i = 1, Me.NumBagSlots() do
        local inv = TLO.InvSlot("pack" .. i).Item

        if (not inv.Container()) then
            return i
        end
    end

	FunctionDepart()
    return 0
end

--- Determine which bag has an available inventory slot for the size specified
---@param size integer
---@return integer
function Inventory.getAvailableBagInvSlot(size)
	FunctionEnter()

    -- Find the first container which can hold an item of the specified size
    for i = 1, Me.NumBagSlots() do
        local inv = TLO.InvSlot("pack" .. i).Item

        if (inv.Container() and inv.SizeCapacity() >= size) then
            return i
        end
    end

	FunctionDepart()
    return 0
end

--- Determine which inventory slot is available for placing items
---@param size integer
---@return integer
function Inventory.GetAvailableInvSlot(size)
	FunctionEnter()

    local slot = Inventory.getAvailableTopInvSlot()

    if (slot > 0) then
        return slot
    end

	FunctionDepart()
    return Inventory.getAvailableBagInvSlot(size)
end

--- Either place the item in a specific location in inventory (if specified) or auto place it
---@param packname? string @Location in inventory to receive the item on the cursor
function Inventory.invItem(packname)
	FunctionEnter()

    PrintDebugMessage(DebuggingRanks.Detail, "packname: %s", packname)
	PrintDebugMessage(DebuggingRanks.Deep, "Put %s in %s", Cursor.Name(), packname)

    Delay(500, function ()
		mq.cmdf("/ctrlkey /itemnotify %s leftmouseup", packname)

        return Cursor.ID() == nil
    end)

	FunctionDepart()
end

--- Give items to the currently targeted NPC.
---@param itemToGive string
---@param amount? integer
function Inventory.giveItems(itemToGive, amount)
	FunctionEnter()

	if (not amount) then
		amount = 1
	end

	PrintDebugMessage(DebuggingRanks.Basic, "\aoGiving \ay%s \aox \ap%s \aoto \ag%s", amount, itemToGive, Target.CleanName())

	mq.cmd.keypress("OPEN_INV_BAGS")

	if (not Window("InventoryWindow").Open()) then
		Window("InventoryWindow").DoOpen()
	end

	Delay(1000, function()
		return Window("InventoryWindow").Open()
	end)
	Delay(100)

	for _ = 1, amount do
		Inventory.grabItem(itemToGive, "left")
		Delay(1000, function()
			return Cursor.ID()
		end)
		mq.cmd.usetarget()
		Delay(1000, function()
			return not Cursor.ID()
		end)
	end

	Window("GiveWnd").Child("GVW_Give_Button").LeftMouseUp()
	Delay(1000, function()
		return not Window("GiveWnd").Open()
	end)

	mq.cmd.keypress("CLOSE_INV_BAGS")
	Delay(100)

	FunctionDepart()
end

return Inventory
