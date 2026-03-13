---@file TutorialUI.lua
--- ImGui-based UI for the Tutorial script.
--- Extracted from init.lua (tutorialUi / makeTooltip).

---@type Mq
local mq = require("mq")
---@type ImGui
require("ImGui")
local ICON = require("inc.icons")
require("inc.Global")
local State = require("core.State")
local Note = require("ext.Note")

local TLO = mq.TLO
local EQ = TLO.EverQuest

local workSet = State.workSet
local debuggingValues = State.debuggingValues

local TutorialUI = {}

--- Callback slots -- set these from the outside so the UI buttons
--- can invoke bindStep / bindResume without a direct dependency.
---@type fun(debug?: string, timed?: string)|nil
TutorialUI._bindStep = nil
---@type fun()|nil
TutorialUI._bindResume = nil

---@param desc string
local function makeTooltip(desc)
    ImGui.SameLine(0, 0)
	ImGui.SetWindowFontScale(0.75)
    ImGui.TextDisabled(ICON.FA_QUESTION_CIRCLE)
	ImGui.SetWindowFontScale(1.0)

	if (ImGui.IsItemHovered()) then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

--- The main render function to be registered with ImGui.Register.
function TutorialUI.render()
    ImGui.SetNextWindowPos((EQ.ViewportXMax() - 450) / 2, 150, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(450, 155, ImGuiCond.FirstUseEver)
    workSet.UseGui, workSet.DrawGui = ImGui.Begin("Tutorial", workSet.UseGui)

    if (not workSet.UseGui) then
        mq.exit()
    end

    if (workSet.DrawGui) then
        ImGui.Text("Location: ")
        ImGui.SameLine()
        ImGui.TextColored(0, 1, 0, 1, workSet.Location)
        ImGui.Text("Task: ")
        ImGui.SameLine()
        ImGui.TextColored(1, 1, 0, 1, TaskName)

		ImGui.Separator()
        ImGui.Text("Status:")
        ImGui.SameLine()
        ImGui.Text(ChatTitle)
		ImGui.Separator()

		local previousResumeProcessing = workSet.ResumeProcessing
		workSet.ResumeProcessing = ImGui.Checkbox("Break For Spells/Skills", workSet.ResumeProcessing)
		if (previousResumeProcessing and not workSet.ResumeProcessing) then
			workSet.LockContinue = false
			workSet.WaitingForResume = false
		end
		makeTooltip("Pauses the tutorial at specific points to provide an opportunity to purchase/scribe new spells/tomes")

		if (workSet.WaitingForResume) then
            ImGui.SameLine()
			if (ImGui.Button("Resume")) then
				if TutorialUI._bindResume then
					TutorialUI._bindResume()
				end
			end
		end

		if (ImGui.CollapsingHeader("Debug")) then
			ImGui.Text("Debugging Level:")
			ImGui.SameLine()
			local previewValue = State.DebuggingText[DebugLevel]  -- Pass in the preview value visible before opening the combo (it could be anything)
			ImGui.SetNextItemWidth(100)

			if (ImGui.BeginCombo("##DebuggingLevels", previewValue)) then
				for i = 0, #State.DebuggingText do
					local isSelected = DebugLevel == i

					if (ImGui.Selectable(State.DebuggingText[i], isSelected)) then
						DebugLevel = i
						State.currentDebugLevel = i
					end

					if (isSelected) then
						ImGui.SetItemDefaultFocus()
					end
				end

				ImGui.EndCombo()
			end

			ImGui.SameLine()
            ImGui.SetCursorPosX(235)
			debuggingValues.ShowTimingInConsole = ImGui.Checkbox("Show Timing in Console", debuggingValues.ShowTimingInConsole)

			if (debuggingValues.ShowTimingInConsole ~= nil) then
				Note.useTimestampConsole = debuggingValues.ShowTimingInConsole --[[@as boolean]]
			end

            ImGui.SetCursorPosX(235)
			debuggingValues.LogOutput = ImGui.Checkbox("Log Output", debuggingValues.LogOutput)
			makeTooltip(string.format("Output will go to %s", Note.outfile))

			if (debuggingValues.LogOutput ~= nil) then
				Note.useOutfile = debuggingValues.LogOutput --[[@as boolean]]
			end

			debuggingValues.StepProcessing = ImGui.Checkbox("Step Through Tutorial", debuggingValues.StepProcessing)
			makeTooltip("Enable/Disable task stepping (pauses after most tasks)")

			if (debuggingValues.WaitingForStep) then
				ImGui.SameLine()
				if (ImGui.Button("Step")) then
					if TutorialUI._bindStep then
						TutorialUI._bindStep()
					end
				end

				ImGui.SameLine()
				ImGui.SetCursorPosX(235)
				debuggingValues.SkipRemainingSteps = ImGui.Checkbox("Continue", debuggingValues.SkipRemainingSteps)
				makeTooltip("Skip any remaining steps")
			end

			if (ImGui.CollapsingHeader("Call Stack")) then
				ImGui.Text(CallStack:tostring())
			end
		end
    end

	ImGui.End()
end

return TutorialUI
