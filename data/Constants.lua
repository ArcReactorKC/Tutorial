local Constants = {
	ZONE_JAIL              = 188,
	ZONE_TUTORIAL          = 189,
	RESPAWN_RESTART_SIGNAL = "__RESPAWN_RESTART__",
	SWIFT_ITEM_IDS         = { 67109, 67123, 67116, 67102 },

	-- Distance / timing thresholds (replaces magic numbers scattered through init.lua)
	IN_RANGE_DIST          = 30,   -- close enough to engage/target a spawn
	HEALER_SCAN_RADIUS     = 60,   -- radius for getNearbyHealerId
	XTAR_CACHE_MS          = 200,  -- ms to cache getNextXTarget result between calls
}

return Constants
