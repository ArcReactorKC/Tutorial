---@type table<string, Location>
local navLocs = {
	RatBat = {Y = -520, X = -378, Z = -38 },
	SpiderRoom = { Y = -658, X = -367, Z = -58 },
	QueenRoom = { Y = -1046, X = -482, Z = 1 },
	PitTop = { Y = -463, X = -812, Z = 2 },
}

---@type table<string, Location>
local safeSpace = {
	-- Add Heading = <degrees> to any entry to face a compass direction after arriving (N=0, W=90, S=180, E=270)
	SpiderRoom = { Y = -955, X = -658, Z = -23, Heading = 180 },
	QueenRoom = { Y = -1163, X = -536, Z = -8 },
	PitTop = { Y = -226, X = -834, Z = 2, Heading = 220 },
	PitSteps = { Y = -226, X = -834, Z = 2 },
	SlaveHall1 = { Y = -226, X = -834, Z = 2 },
	SlaveHall2 = { Y = -87, X = -626, Z = 12 },
	SlaveArea = { Y = -87, X = -626, Z = 12 },
	JailEntry = { Y = -87, X = -626, Z = 12 },
	JailHall1 = { Y = -87, X = -626, Z = 12 },
	Jail1 = { Y = 195, X = -795, Z = 23, Heading =90 },
	LocksmithHall = { Y = 598, X = -259, Z = -10 },
	Jail2 = { Y = 598, X = -259, Z = -10 },
	JailHall2 = { Y = 598, X = -259, Z = -10 },
	SlaveMaster = { Y = 598, X = -259, Z = -10, Heading = 0 },
	GloomingdeepFort = { Y = -90.86, X = -1743.17, Z = -103.61 },
	Krenshin = { Y = -380.23, X = -1048.61, Z = -145.72 },
}

return {
	navLocs = navLocs,
	safeSpace = safeSpace,
}
