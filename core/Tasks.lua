---@file Tasks.lua
--- Task/quest management functions extracted from init.lua.

local mq = require("mq")
require("inc.Global")
local Note = require("ext.Note")
local State = require("core.State")

local workSet = State.workSet
local debuggingValues = State.debuggingValues

local TLO = mq.TLO
local Me = TLO.Me
local Window = TLO.Window

local Tasks = {}

--- Callback slots (set by the caller to wire up cross-module dependencies)
Tasks._targetShortest = nil
Tasks._findAndKill    = nil
Tasks._checkLoot      = nil
Tasks._amIDead        = nil  -- function(): boolean  (returns true if just respawned)

function Tasks.closeDialog()
	FunctionEnter()

	Delay(1000, function()
		return Window("LargeDialogWindow").Open()
	end)

	if (Window("LargeDialogWindow").Open()) then
		Window("LargeDialogWindow").Child("LDW_OkButton").LeftMouseUp()
		Delay(1000, function()
			return not Window("LargeDialogWindow").Open()
		end)
		Delay(100)
	end

	FunctionDepart()
end

---@param checkFor string
---@return boolean
function Tasks.tutorialCheck(checkFor)
	PrintDebugMessage(DebuggingRanks.Function, "\attutorialCheck enter")
	PrintDebugMessage(DebuggingRanks.Function, "checkFor: \ag%s", checkFor)

	local returnValue = false
	local taskList = Window("TaskWND").Child("Task_TaskList")

	PrintDebugMessage(DebuggingRanks.Deep, "Number of tasks: %s", taskList.Items())

	for i = 1, taskList.Items() do
		PrintDebugMessage(DebuggingRanks.Deep, "Checking task: \at%s", taskList.List(i, 3)())
		PrintDebugMessage(DebuggingRanks.Deep, "Task = checkFor: \ay%s", taskList.List(i, 3)() == checkFor)

		if (taskList.List(i, 3)() == checkFor) then
			returnValue = true
			break
		end
	end

	PrintDebugMessage(DebuggingRanks.Function, "\attutorialCheck depart")
	return returnValue
end

---@param checkFor string
---@return boolean
function Tasks.tutorialSelect(checkFor)
	PrintDebugMessage(DebuggingRanks.Function, "\attutorialSelect enter")
	PrintDebugMessage(DebuggingRanks.Function, "checkFor: \ag%s", checkFor)

	local returnValue = false
	local taskList = Window("TaskWND").Child("Task_TaskList")

	PrintDebugMessage(DebuggingRanks.Deep, "Number of tasks: %s", taskList.Items())

	for i = 1, taskList.Items() do
		PrintDebugMessage(DebuggingRanks.Deep, "Checking task: \at%s", taskList.List(i, 3)())
		PrintDebugMessage(DebuggingRanks.Deep, "Task = checkFor: \ay%s", taskList.List(i, 3)() == checkFor)

		if (taskList.List(i, 3)() == checkFor) then
			taskList.Select(i)
			Delay(2000, function ()
				return taskList.GetCurSel() == i
			end)

			returnValue = true

			break
		end
	end

	PrintDebugMessage(DebuggingRanks.Function, "\attutorialSelect depart")
	return returnValue
end

function Tasks.acceptTask(taskName)
	FunctionEnter()

	Delay(15000, function()
		return Window("TaskSelectWnd").Open()
	end)

	local taskList = Window("TaskSelectWnd").Child("TSEL_TaskList")

	PrintDebugMessage(DebuggingRanks.Deep, "Number of available tasks: %s", taskList.Items())

	for i = 1, taskList.Items() do
		PrintDebugMessage(DebuggingRanks.Deep, "Checking task: \at%s", taskList.List(i, 1)())
		PrintDebugMessage(DebuggingRanks.Deep, "Task = taskName: \ay%s", taskList.List(i, 1)() == taskName)

		if (taskList.List(i, 1)() == taskName) then
			taskList.Select(i)
			Delay(5000, function ()
				return taskList.GetCurSel() == i
			end)

			break
		end
	end

	if (taskList.List(taskName, 1)() == taskList.GetCurSel()) then
		Window("TaskSelectWnd").Child("TSEL_AcceptButton").LeftMouseUp()

		Delay(5000, function()
			return not Window("TaskSelectWnd").Open()
		end)

		Delay(5000, function ()
			return Tasks.tutorialCheck(taskName)
		end)
	end

	FunctionDepart()
end

function Tasks.openTaskWnd()
	FunctionEnter()

	if (not Window("TaskWnd").Open()) then
		mq.cmd.keypress("ALT+Q")
		Delay(1000, function()
			return Window("TaskWnd").Open()
		end)
		Delay(100)
	end

	FunctionDepart()
end

function Tasks.checkStep()
	DebugLevel = State.currentDebugLevel
	Note.useTimestampConsole = false

	if (debuggingValues.StepProcessing and debuggingValues.ActionTaken) then
		PrintDebugMessage(DebuggingRanks.None, "Pause before the next step, use \aw/step\ax to continue")

		while (debuggingValues.LockStep) do
			debuggingValues.WaitingForStep = true
			mq.doevents()
			Delay(100)
		end

		debuggingValues.LockStep = true
		debuggingValues.WaitingForStep = false
	end

	debuggingValues.ActionTaken = false
end

function Tasks.checkContinue()
	if (workSet.ResumeProcessing) then
		PrintDebugMessage(DebuggingRanks.None, "Tutorial paused for spell/skill updates. Visit the approprate merchant to buy, scribe, and load or replace spells/skills. Use \aw/resume\ax to continue")
		workSet.WaitingForResume = true

		while (workSet.LockContinue and workSet.ResumeProcessing) do
			mq.doevents()
			Delay(100)
		end

		workSet.WaitingForResume = false

		if (workSet.ResumeProcessing) then
			workSet.LockContinue = true
		else
			workSet.LockContinue = false
		end
	end
end

function Tasks.checkAllAccessNag()
	if (Window("AlertWnd").Open()) then
		Window("AlertWnd").Child("ALW_Dismiss_Button").LeftMouseUp()
	end

	if (Window("AlertStackWnd").Open() and not Window("AlertWnd").Open()) then
		Window("ALSW_Alerts_Box").Child("ALSW_AlertTemplate_Button").LeftMouseUp()
	end
end

function Tasks.levelUp(conditions, initialization, targetList)
	FunctionEnter()

	if (conditions()) then
		PrintDebugMessage(DebuggingRanks.None, "\ayYou need to be a higher level before proceeding")
		SetChatTitle("Leveleing up a bit before proceeding")
		TaskName = "Level up"

		initialization()

		while (conditions()) do
			-- Guard against death inside the grind loop (fixes: character re-paths to mob after dying)
			if (Tasks._amIDead and Tasks._amIDead()) then
				break
			end
			Tasks._targetShortest(targetList)
			Tasks._findAndKill(workSet.MyTargetID)
			Delay(100)
		end

		Tasks._checkLoot("")
	end

	FunctionDepart()
end

function Tasks.bindStep(debug, timed)
	if (debug == "debug") then
		State.currentDebugLevel = DebugLevel
		DebugLevel = DebuggingRanks.Deep

		if (timed == "timed") then
			Note.useTimestampConsole = true
		end
	elseif (debug == "continue") then
		debuggingValues.StepProcessing = false
	end

	debuggingValues.LockStep = false
end

function Tasks.bindResume()
	workSet.LockContinue = false
end

return Tasks
