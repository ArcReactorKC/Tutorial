---@file Utility.lua
--- General-purpose utility functions extracted from init.lua.

---@type Mq
local mq = require("mq")
require("inc.Global")
---@type Note
local Note = require("ext.Note")

local TLO = mq.TLO
local Me = TLO.Me
local Window = TLO.Window

local alertIgnoreNames = require("data.AlertIgnores")

local Utility = {}

--- Ensures a required MQ plugin is loaded; exits the script if it cannot be loaded.
---@param plugin string
function Utility.checkPlugin(plugin)
	if (not TLO.Plugin(plugin)()) then
        PrintDebugMessage(DebuggingRanks.Deep, "\aw%s\ar not detected! \aw This script requires it! Loading ...", plugin)
        mq.cmdf("/squelch /plugin %s noauto", plugin)
		Delay(1000, function()
			return TLO.Plugin(plugin)()
		end)
		if (not TLO.Plugin(plugin)()) then
			Note.Info("Required plugin \aw%s\ax did not load! \ar Ending the script", plugin)
			mq.exit()
		end
	end
end

--- Returns true if the player's class ShortName matches any entry in the list.
---@param classes string[]
---@return boolean
function Utility.isClassMatch(classes)
	for _, class in ipairs(classes) do
		if (Me.Class.ShortName() == class) then
			return true
		end
	end

	return false
end

--- Counts the number of entries in a table (works for non-sequential keys).
---@param tbl table
---@return integer
function Utility.tableCount(tbl)
	local count = 0
  	for _ in pairs(tbl) do count = count + 1 end
  	return count
end

--- Dismisses the in-game Alert window if it is currently open.
function Utility.closeAlert()
	if (Window("AlertWnd").Open()) then
		Window("AlertWnd").Child("ALW_Dismiss_Button").LeftMouseUp()
		Delay(1000, function()
			return not Window("AlertWnd").Open()
		end)
	end
end

--- Populates alert list 1 with NPC names that should be ignored (friendly/non-combat).
--- Names are sourced from data/AlertIgnores.lua.
function Utility.loadIgnores()
	mq.cmd.squelch("/alert clear 1")
	for _, name in ipairs(alertIgnoreNames) do
		mq.cmd.squelch("/alert add 1 " .. name)
	end
end

return Utility
