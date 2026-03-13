---@file State.lua
--- Centralized mutable state for the Tutorial Lua script.
--- Previously scattered as local variables in init.lua.

require("inc.Global")

local State = {}

--- Human-readable labels for each DebuggingRanks value.
---@type table<DebuggingRanks, string>
State.DebuggingText = {
	[DebuggingRanks.None] = "None",
	[DebuggingRanks.Basic] = "Basic",
	[DebuggingRanks.Task] = "Task",
	[DebuggingRanks.Detail] = "Detail",
	[DebuggingRanks.Function] = "Function",
	[DebuggingRanks.Deep] = "Deep",
}

--- Debugging-related UI/flow state.
State.debuggingValues = {
	---@type boolean|nil
	StepProcessing = false,
	---@type boolean|nil
	SkipRemainingSteps = false,
	LockStep = true,
	WaitingForStep = false,
	ActionTaken = false,
	---@type boolean|nil
	ShowTimingInConsole = false,
	---@type boolean|nil
	LogOutput = false,
}

--- Tracks the current debug level (mirrors DebugLevel from Global).
---@type DebuggingRanks
State.currentDebugLevel = DebugLevel

--- Main work-set: combat, UI, and flow configuration.
State.workSet = {
	---@type boolean|nil
	ResumeProcessing = true,
	---@type boolean
	LockContinue = true,
	WaitingForResume = false,

	---@type boolean|nil
	UseGui = true,
	---@type boolean|nil
	DrawGui = true,

	-- Edit Do you want to temporarily move away from mobs when hp gets lower than 50% true OR false
	---@type boolean
	MoveAway = true,
	-- Edit At what pct HP do you want to move away
	---@type integer
	MoveAwayHP = 50,

	---@type string[]
	Targets = {},
	---@type spawnType
	TargetType = "NPC",
	---@type integer
	PullRange = 1000,
	---@type integer
	ZRadius = 1000,
	---@type integer
	HealAt = 70,
	---@type integer
	HealTill = 100,
	---@type integer
	MedAt = 30,
	---@type integer
	MedTill = 100,
	---@type integer
	DpsLImiter = 0,
	---@type integer
	MyTargetID = 0,
	---@type string
	FarmMob = "",
	---@type integer
	ReportTarget = os.time() + 5,
	---@type string
	Location = "",
	---@type integer
	PetGem = 8,
	---@type boolean|nil
	JustRespawned = false,
	---@type boolean
	PetReagentUnavailable = false,

	-- Combat priority targeting
	---@type boolean
	HealerPriorityLock = false,
	---@type integer
	HealerScanRadius = 60,
}

--- Items that have already been looted (keyed by item).
State.lootedItems = {}

--- Items queued for destruction.
State.destroyList = {}

--- Spawn IDs for which no nav path could be found.
---@type table<integer, true>
State.noPathList = {}

--- Whether a pet-reagent restock is in progress.
State.isRestocking = false

return State
