---@file Zone.lua
--- Zone-related functions extracted from init.lua.

---@type Mq
local mq = require("mq")
require("inc.Global")
---@type Note
local Note = require("ext.Note")
local State = require("core.State")

local zoneBounds = require("data.ZoneBounds")

local TLO = mq.TLO
local Me = TLO.Me
local Navigation = TLO.Navigation

local workSet = State.workSet

local Zone = {}

--- Sets or clears walk mode.
---@param enable boolean  true to enable walking, false to disable
function Zone.setWalkMode(enable)
	if enable then
		if Me.Running() then
			mq.cmd("/squelch /walk")
		end
	else
		if not Me.Running() then
			mq.cmd("/squelch /walk")
		end
	end
end

--- Determines the player's current location by checking coordinate bounds.
--- Uses a data-driven loop over ZoneBounds entries instead of a long elseif chain.
--- Special-cases Zone ID 188 (jail zone) before the loop.
function Zone.whereAmI()
	FunctionEnter()

	Delay(1000)

	-- Special case: jail zone (ID 188)
	if (TLO.Zone.ID() == 188) then
		if (workSet.Location ~= "JailBreak") then
			workSet.Location = "JailBreak"
			Note.Info("\awLocation:\ag%s", workSet.Location)
			Zone.setWalkMode(false)
		end

		FunctionDepart()

		return
	end

	local y = Me.Y()
	local x = Me.X()
	local z = Me.Z()

	for _, entry in ipairs(zoneBounds) do
		if (y >= entry.yMin and y <= entry.yMax) and (x >= entry.xMin and x <= entry.xMax) then
			-- If entry has Z bounds, check those too
			if entry.zMin and entry.zMax then
				if not (z >= entry.zMin and z <= entry.zMax) then
					goto continue
				end
			end

			-- Matched this entry
			if (workSet.Location ~= entry.name) then
				workSet.Location = entry.name
				Note.Info("\awLocation:\ag%s", workSet.Location)
				Zone.setWalkMode(entry.walk == true)
			end

			FunctionDepart()

			return
		end

		::continue::
	end

	-- No entry matched
	if (workSet.Location ~= "Unknown") then
		workSet.Location = "Unknown"
		Note.Info("\awLocation:\ag%s (%.2f,%.2f,%.2f)", workSet.Location, y, x, z)
		Zone.setWalkMode(false)
	end

	FunctionDepart()
end

--- Verifies the player is in the tutorial zone (188 or 189); exits the script if not.
function Zone.checkZone()
	FunctionEnter()

	if (TLO.Zone.ID() ~= 188 and TLO.Zone.ID() ~= 189) then
		Note.Info("\arYou're not in the tutorial. Ending the macro!")
		mq.exit()
	end

	FunctionDepart()
end

--- Blocks until the player has finished zoning into zone 189.
function Zone.zoning()
	while (TLO.Zone.ID() ~= 189) do
		Delay(50)
	end

	while (Me.Zoning()) do
		Delay(50)
	end

	Delay(100)
end

--- Ensures a navigation mesh is loaded for the current zone; exits the script if not.
function Zone.checkMesh()
	if (not Navigation.MeshLoaded()) then
		mq.cmd.nav("reload")
		Delay(1000, function()
			return Navigation.MeshLoaded()
		end)
		if (not Navigation.MeshLoaded()) then
			Note.Info("No navigational mesh could be found for this zone. Make one and try again")
			Note.Info("Ending script.")
			mq.exit()
		end
	end
end

return Zone
