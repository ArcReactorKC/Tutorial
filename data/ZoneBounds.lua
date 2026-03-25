--- Zone boundary definitions for whereAmI().
--- Each entry defines the coordinate bounds for a named area.
--- Fields: name, yMin, yMax, xMin, xMax, and optionally zMin, zMax, walk.
--- Zone 188 (jail) is handled separately and not included here.
local ZONE_BOUNDS = {
	{ name = "StartArea",        yMin = -298,  yMax = 154,   xMin = -309,  xMax = 63 },
	{ name = "Hall1",            yMin = -447,  yMax = -299,  xMin = -386,  xMax = -99 },
	{ name = "RatBat",           yMin = -614,  yMax = -448,  xMin = -430,  xMax = -325 },
	{ name = "SpiderHall",       yMin = -685,  yMax = -498,  xMin = -384,  xMax = -361 },
	{ name = "SpiderRoom",       yMin = -1025, yMax = -685,  xMin = -672,  xMax = -204 },
	{ name = "QueenRoom",        yMin = -1238, yMax = -1025, xMin = -586,  xMax = -421 },
	{ name = "Hall2",            yMin = -552,  yMax = -497,  xMin = -598,  xMax = -431,  zMin = -40,  zMax = 5 },
	{ name = "RatBat2",          yMin = -572,  yMax = -420,  xMin = -711,  xMax = -598,  zMin = -3,   zMax = 10 },
	{ name = "Hall3",            yMin = -491,  yMax = -421,  xMin = -819,  xMax = -711,  zMin = -3,   zMax = 10 },
	{ name = "PitTop",           yMin = -640,  yMax = -210,  xMin = -1079, xMax = -820,  zMin = -3,   zMax = 10 },
	{ name = "PitSteps",         yMin = -570,  yMax = -444,  xMin = -994,  xMax = -884,  zMin = -60,  zMax = -2,   walk = true },
	{ name = "PitTunnel1",       yMin = -567,  yMax = -383,  xMin = -889,  xMax = -661,  zMin = -93,  zMax = -54 },
	{ name = "Rookfynn",         yMin = -490,  yMax = -322,  xMin = -797,  xMax = -645,  zMin = -86,  zMax = -69 },
	{ name = "PitTunnel2",       yMin = -708,  yMax = -563,  xMin = -971,  xMax = -750,  zMin = -86,  zMax = -53 },
	{ name = "PitMine",          yMin = -857,  yMax = -613,  xMin = -757,  xMax = -628,  zMin = -81,  zMax = -77 },
	{ name = "PitTunnel3",       yMin = -456,  yMax = -306,  xMin = -1166, xMax = -993,  zMin = -146, zMax = -114 },
	{ name = "Krenshin",         yMin = -579,  yMax = -415,  xMin = -1234, xMax = -1087, zMin = -133, zMax = -116 },
	{ name = "GloomingdeepMines",yMin = -648,  yMax = -446,  xMin = -1487, xMax = -1078, zMin = -32,  zMax = 4 },
	{ name = "MiningHall",       yMin = -498,  yMax = -231,  xMin = -1574, xMax = -1260, zMin = -105, zMax = -26 },
	{ name = "GloomingdeepFort", yMin = -445,  yMax = -79,   xMin = -1941, xMax = -1573 },
	{ name = "SlaveHall1",       yMin = -217,  yMax = -77,   xMin = -899,  xMax = -857 },
	{ name = "SlaveArea",        yMin = -77,   yMax = 68,    xMin = -960,  xMax = -853 },
	{ name = "SlaveHall2",       yMin = -58,   yMax = -38,   xMin = -853,  xMax = -739 },
	{ name = "JailEntry",        yMin = -61,   yMax = -19,   xMin = -739,  xMax = -658 },
	{ name = "ScoutArea",        yMin = -110,  yMax = 12,    xMin = -658,  xMax = -523 },
	{ name = "JailHall1",        yMin = -21,   yMax = 77,    xMin = -712,  xMax = -693 },
	{ name = "Jail1",            yMin = 76,    yMax = 326,   xMin = -812,  xMax = -511 },
	{ name = "LocksmithHall",    yMin = 190,   yMax = 417,   xMin = -512,  xMax = -326 },
	{ name = "Jail2",            yMin = 413,   yMax = 522,   xMin = -491,  xMax = -195 },
	{ name = "JailHall2",        yMin = 413,   yMax = 585,   xMin = -323,  xMax = -361 },
	{ name = "SlaveMaster",      yMin = 582,   yMax = 868,   xMin = -516,  xMax = -170 },
}

return ZONE_BOUNDS
