-- @ScriptType: ModuleScript
local function UpdatePvPActionGrid()
	inputLocked = false

	-- [[ FIX: Don't destroy buttons, just hide them to save memory ]]
	for _, child in ipairs(ActionGrid:GetChildren()) do 
		if child:IsA("TextButton") then child.Visible = false end 
	end

	local eqWpn = player:GetAttribute("EquippedWeapon") or "None"
	local pStyle = (ItemData.Equipment[eqWpn] and ItemData.Equipment[eqWpn].Style) or "None"
	local pTitan = player:GetAttribute("Titan") or "None"
	local pClan = player:GetAttribute("Clan") or "None"
	local isTransformed = player:GetAttribute("Statuses") and player:GetAttribute("Statuses")["Transformed"]
	local isODM = (pStyle == "Ultrahard Steel Blades" or pStyle == "Thunder Spears" or pStyle == "Anti-Personnel")

	local function CreateBtn(sName, color, order)
		local sData = SkillData.Skills[sName]
		if not sData or sName == "Retreat" then return end
		if sName == "Transform" and (pClan == "Ackerman" or pClan == "Awakened Ackerman") then return end

		-- Check for existing button to prevent stutter
		local btn = ActionGrid:FindFirstChild("Btn_" .. sName)
		if not btn then
			btn = Instance.new("TextButton")
			btn.Name = "Btn_" .. sName
			btn.Parent = ActionGrid
			btn.RichText = true; btn.Font = Enum.Font.GothamBold; btn.TextSize = 12

			btn.MouseButton1Click:Connect(function()
				if not inputLocked then
					EffectsManager.PlaySFX("Click")
					if sData.Effect == "Rest" or sData.Effect == "TitanRest" or sData.Effect == "Eject" or sData.Effect == "Transform" or sData.Effect == "Block" then
						LockGridAndWait()
						Network.PvPAction:FireServer("SubmitMove", currentMatchId, sName, "Body")
					else
						pendingSkillName = sName
						ActionGrid.Visible = false
						TargetMenu.Visible = true
					end
				end
			end)
		end

		btn.Visible = true
		btn.LayoutOrder = order or 10
		ApplyButtonGradient(btn, color, Color3.new(color.R*0.7, color.G*0.7, color.B*0.7), color)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.Text = sName:upper()
	end

	if isTransformed then
		CreateBtn("Titan Recover", Color3.fromRGB(40, 140, 80), 1); CreateBtn("Titan Punch", Color3.fromRGB(120, 40, 40), 2); CreateBtn("Titan Kick", Color3.fromRGB(140, 60, 40), 3); CreateBtn("Eject", Color3.fromRGB(140, 40, 40), 4)
		local orderIndex = 5
		for sName, sData in pairs(SkillData.Skills) do
			if sData.Requirement == pTitan or sData.Requirement == "AnyTitan" or sData.Requirement == "Transformed" then
				if sName ~= "Titan Recover" and sName ~= "Eject" and sName ~= "Titan Punch" and sName ~= "Titan Kick" and sName ~= "Transform" then
					CreateBtn(sName, Color3.fromRGB(60, 40, 60), sData.Order or orderIndex); orderIndex += 1
				end
			end
		end
	else
		CreateBtn("Basic Slash", Color3.fromRGB(120, 40, 40), 1); CreateBtn("Maneuver", Color3.fromRGB(40, 80, 140), 2); CreateBtn("Recover", Color3.fromRGB(40, 140, 80), 3)
		if pTitan ~= "None" and pClan ~= "Ackerman" and pClan ~= "Awakened Ackerman" then CreateBtn("Transform", Color3.fromRGB(200, 150, 50), 5) end
		local orderIndex = 6
		for sName, sData in pairs(SkillData.Skills) do
			if sName == "Basic Slash" or sName == "Maneuver" or sName == "Recover" or sName == "Transform" then continue end
			local req = sData.Requirement
			if req == pStyle or req == pClan or (req == "Ackerman" and pClan == "Awakened Ackerman") or (req == "ODM" and isODM) then
				CreateBtn(sName, Color3.fromRGB(45, 40, 60), sData.Order or orderIndex); orderIndex += 1
			end
		end
	end
end