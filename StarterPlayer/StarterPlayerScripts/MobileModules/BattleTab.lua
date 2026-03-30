-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local BattleTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))

local player = Players.LocalPlayer
local MainFrame, ContentArea
local SubTabs = {}; local SubBtns = {}; local cBtns = {}; local rBtns = {}
local CompletionBanner, pBtn, pStats

local PartyAction = Network:WaitForChild("PartyAction")
local PartyUpdate = Network:WaitForChild("PartyUpdate")
local PartyListContainer = nil
local CurrentParty = {}
local PartyHeader = nil

local expeditionList = {
	{ Id = 1, Name = "The Fall of Shiganshina", Req = 0, Desc = "The breach of Wall Maria." },
	{ Id = 2, Name = "104th Cadet Corps Training", Req = 0, Desc = "Master your balance." },
	{ Id = 3, Name = "Clash of the Titans", Req = 0, Desc = "Battle at Utgard Castle." },
	{ Id = 4, Name = "The Uprising", Req = 0, Desc = "Fight the Interior MP." },
	{ Id = 5, Name = "Marleyan Assault", Req = 0, Desc = "Infiltrate Liberio." },
	{ Id = 6, Name = "Return to Shiganshina", Req = 0, Desc = "Reclaim Wall Maria." },
	{ Id = 7, Name = "War for Paradis", Req = 0, Desc = "Marley's counterattack." },
	{ Id = 8, Name = "The Rumbling", Req = 0, Desc = "The end of all things." }
}

local raidList = {
	{ Id = "Raid_Part1", Name = "Female Titan", Req = 1, Desc = "A deadly raid." },
	{ Id = "Raid_Part2", Name = "Armored Titan", Req = 2, Desc = "Pierce the armor." },
	{ Id = "Raid_Part3", Name = "Beast Titan", Req = 3, Desc = "Avoid the crushed boulders." },
	{ Id = "Raid_Part5", Name = "Founding Titan", Req = 5, Desc = "The Coordinate commands all." }
}

local function ApplyGradient(label, color1, color2)
	local grad = Instance.new("UIGradient", label)
	grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}
end

local function ApplyButtonGradient(btn, topColor, botColor, strokeColor)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	local grad = btn:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient", btn); grad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, topColor), ColorSequenceKeypoint.new(1, botColor)}; grad.Rotation = 90
	local corner = btn:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 4)
	if strokeColor then
		local stroke = btn:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", btn); stroke.Color = strokeColor; stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	if not btn:GetAttribute("GradientTextFixed") then
		btn:SetAttribute("GradientTextFixed", true)
		local textLbl = Instance.new("TextLabel", btn); textLbl.Name = "BtnTextLabel"; textLbl.Size = UDim2.new(1, 0, 1, 0); textLbl.BackgroundTransparency = 1; textLbl.Font = btn.Font; textLbl.TextSize = btn.TextSize; textLbl.TextScaled = btn.TextScaled; textLbl.RichText = btn.RichText; textLbl.TextWrapped = btn.TextWrapped; textLbl.TextXAlignment = btn.TextXAlignment; textLbl.TextYAlignment = btn.TextYAlignment; textLbl.ZIndex = btn.ZIndex + 1
		local tConstraint = btn:FindFirstChildOfClass("UITextSizeConstraint"); if tConstraint then tConstraint.Parent = textLbl end
		btn.ChildAdded:Connect(function(child) if child:IsA("UITextSizeConstraint") then task.delay(0, function() child.Parent = textLbl end) end end)
		textLbl.Text = btn.Text; textLbl.TextColor3 = btn.TextColor3; btn.Text = ""
		btn:GetPropertyChangedSignal("Text"):Connect(function() if btn.Text ~= "" then textLbl.Text = btn.Text; btn.Text = "" end end)
		btn:GetPropertyChangedSignal("TextColor3"):Connect(function() textLbl.TextColor3 = btn.TextColor3 end)
	end
end

function BattleTab.Init(parentFrame)
	MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "BattleFrame"; MainFrame.Size = UDim2.new(1, 0, 1, 0); MainFrame.BackgroundTransparency = 1; MainFrame.Visible = false

	local TopNav = Instance.new("ScrollingFrame", MainFrame)
	TopNav.Size = UDim2.new(1, 0, 0, 45); TopNav.BackgroundTransparency = 1; TopNav.ScrollBarThickness = 0; TopNav.ScrollingDirection = Enum.ScrollingDirection.X
	local navLayout = Instance.new("UIListLayout", TopNav); navLayout.FillDirection = Enum.FillDirection.Horizontal; navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; navLayout.VerticalAlignment = Enum.VerticalAlignment.Center; navLayout.Padding = UDim.new(0, 10)
	local navPad = Instance.new("UIPadding", TopNav); navPad.PaddingLeft = UDim.new(0, 10); navPad.PaddingRight = UDim.new(0, 10)

	ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Size = UDim2.new(1, 0, 1, -55); ContentArea.Position = UDim2.new(0, 0, 0, 55); ContentArea.BackgroundTransparency = 1

	local function CreateSubNavBtn(name, text)
		local btn = Instance.new("TextButton", TopNav); btn.Size = UDim2.new(0, 140, 0, 35); btn.Font = Enum.Font.GothamBold; btn.TextColor3 = Color3.fromRGB(180, 180, 180); btn.TextSize = 11; btn.Text = text
		ApplyButtonGradient(btn, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 65))
		btn.MouseButton1Click:Connect(function()
			for k, v in pairs(SubBtns) do ApplyButtonGradient(v, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 65)); v.TextColor3 = Color3.fromRGB(180, 180, 180) end
			ApplyButtonGradient(btn, Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), Color3.fromRGB(255, 215, 100)); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			for k, frame in pairs(SubTabs) do frame.Visible = (k == name) end
		end)
		SubBtns[name] = btn
		return btn
	end

	CreateSubNavBtn("Campaign", "CAMPAIGN"); CreateSubNavBtn("Endless", "ENDLESS"); CreateSubNavBtn("Paths", "THE PATHS"); CreateSubNavBtn("Raids", "RAIDS"); CreateSubNavBtn("World", "WORLD BOSSES")
	task.delay(0.1, function() TopNav.CanvasSize = UDim2.new(0, navLayout.AbsoluteContentSize.X + 20, 0, 0) end)

	-- [[ 1. CAMPAIGN ]]
	SubTabs["Campaign"] = Instance.new("ScrollingFrame", ContentArea); SubTabs["Campaign"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Campaign"].BackgroundTransparency = 1; SubTabs["Campaign"].BorderSizePixel = 0; SubTabs["Campaign"].ScrollBarThickness = 0; SubTabs["Campaign"].Visible = true
	local cListLayout = Instance.new("UIListLayout", SubTabs["Campaign"]); cListLayout.Padding = UDim.new(0, 10); cListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; cListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local cPad = Instance.new("UIPadding", SubTabs["Campaign"]); cPad.PaddingTop = UDim.new(0, 5); cPad.PaddingBottom = UDim.new(0, 20)

	CompletionBanner = Instance.new("TextLabel", SubTabs["Campaign"]); CompletionBanner.Size = UDim2.new(0.95, 0, 0, 35); CompletionBanner.BackgroundColor3 = Color3.fromRGB(40, 30, 20); CompletionBanner.Font = Enum.Font.GothamBlack; CompletionBanner.TextColor3 = Color3.fromRGB(255, 215, 100); CompletionBanner.TextSize = 11; CompletionBanner.TextWrapped = true; CompletionBanner.Text = "STORY COMPLETE! Replay missions to max your stats."; CompletionBanner.LayoutOrder = 0; CompletionBanner.Visible = false
	Instance.new("UICorner", CompletionBanner).CornerRadius = UDim.new(0, 6); Instance.new("UIStroke", CompletionBanner).Color = Color3.fromRGB(200, 150, 50)

	for _, dInfo in ipairs(expeditionList) do
		local card = Instance.new("Frame", SubTabs["Campaign"]); card.Size = UDim2.new(0.95, 0, 0, 80); card.BackgroundColor3 = Color3.fromRGB(20, 20, 25); card.LayoutOrder = dInfo.Id
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6); local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(50, 50, 60); stroke.Thickness = 1; stroke.Transparency = 0.55
		local accentBar = Instance.new("Frame", card); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255); Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local title = Instance.new("TextLabel", card); title.Size = UDim2.new(1, -110, 0, 20); title.Position = UDim2.new(0, 12, 0, 10); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.fromRGB(255, 255, 255); title.TextSize = 13; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = dInfo.Name
		local desc = Instance.new("TextLabel", card); desc.Size = UDim2.new(1, -110, 1, -35); desc.Position = UDim2.new(0, 12, 0, 30); desc.BackgroundTransparency = 1; desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(160, 160, 170); desc.TextSize = 10; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = dInfo.Desc

		local btn = Instance.new("TextButton", card); btn.Size = UDim2.new(0, 90, 0, 35); btn.AnchorPoint = Vector2.new(1, 0.5); btn.Position = UDim2.new(1, -10, 0.5, 0); btn.Font = Enum.Font.GothamBlack; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 11; btn.Text = "DEPLOY"
		ApplyButtonGradient(btn, Color3.fromRGB(25, 35, 25), Color3.fromRGB(15, 20, 15), Color3.fromRGB(80, 180, 80))

		btn.MouseButton1Click:Connect(function() if btn.Active then Network:WaitForChild("CombatAction"):FireServer("EngageStory", {PartId = dInfo.Id}) end end)
		cBtns[dInfo.Id] = { Btn = btn, Stroke = stroke, Accent = accentBar }
	end
	task.delay(0.1, function() SubTabs["Campaign"].CanvasSize = UDim2.new(0, 0, 0, cListLayout.AbsoluteContentSize.Y + 20) end)

	-- [[ 2. ENDLESS EXPEDITION TAB ]]
	SubTabs["Endless"] = Instance.new("Frame", ContentArea); SubTabs["Endless"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Endless"].BackgroundTransparency = 1; SubTabs["Endless"].Visible = false
	local eBox = Instance.new("Frame", SubTabs["Endless"]); eBox.Size = UDim2.new(0.95, 0, 0, 200); eBox.Position = UDim2.new(0.5, 0, 0.1, 0); eBox.AnchorPoint = Vector2.new(0.5, 0); eBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	Instance.new("UICorner", eBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", eBox).Color = Color3.fromRGB(150, 100, 255)
	local eTitle = Instance.new("TextLabel", eBox); eTitle.Size = UDim2.new(1, 0, 0, 40); eTitle.BackgroundTransparency = 1; eTitle.Font = Enum.Font.GothamBlack; eTitle.TextColor3 = Color3.fromRGB(220, 150, 255); eTitle.TextSize = 18; eTitle.Text = "ENDLESS EXPEDITION"
	local eDesc = Instance.new("TextLabel", eBox); eDesc.Size = UDim2.new(0.9, 0, 0, 90); eDesc.Position = UDim2.new(0.05, 0, 0, 40); eDesc.BackgroundTransparency = 1; eDesc.Font = Enum.Font.GothamMedium; eDesc.TextColor3 = Color3.fromRGB(180, 180, 190); eDesc.TextSize = 12; eDesc.TextWrapped = true; eDesc.Text = "Venture beyond the walls continuously. Drops are permanently multiplied by 1.2x. How long can you survive?"
	local eBtn = Instance.new("TextButton", eBox); eBtn.Size = UDim2.new(0, 160, 0, 40); eBtn.AnchorPoint = Vector2.new(0.5, 0); eBtn.Position = UDim2.new(0.5, 0, 1, -55); eBtn.Font = Enum.Font.GothamBlack; eBtn.TextColor3 = Color3.fromRGB(220, 150, 255); eBtn.TextSize = 14; eBtn.Text = "DEPART"
	ApplyButtonGradient(eBtn, Color3.fromRGB(35, 20, 45), Color3.fromRGB(20, 10, 25), Color3.fromRGB(150, 80, 200))
	eBtn.MouseButton1Click:Connect(function() Network:WaitForChild("CombatAction"):FireServer("EngageEndless") end)

	-- [[ 3. THE PATHS TAB ]]
	SubTabs["Paths"] = Instance.new("ScrollingFrame", ContentArea); SubTabs["Paths"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Paths"].BackgroundTransparency = 1; SubTabs["Paths"].ScrollBarThickness = 0; SubTabs["Paths"].Visible = false
	local pathsLayout = Instance.new("UIListLayout", SubTabs["Paths"]); pathsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; pathsLayout.Padding = UDim.new(0, 15)
	local pBox = Instance.new("Frame", SubTabs["Paths"]); pBox.Size = UDim2.new(0.95, 0, 0, 200); pBox.BackgroundColor3 = Color3.fromRGB(18, 18, 22); Instance.new("UICorner", pBox).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", pBox).Color = Color3.fromRGB(100, 200, 255)
	local pTitleLbl = Instance.new("TextLabel", pBox); pTitleLbl.Size = UDim2.new(1, 0, 0, 40); pTitleLbl.BackgroundTransparency = 1; pTitleLbl.Font = Enum.Font.GothamBlack; pTitleLbl.TextColor3 = Color3.fromRGB(255, 255, 255); pTitleLbl.TextSize = 18; pTitleLbl.Text = "THE PATHS"; ApplyGradient(pTitleLbl, Color3.fromRGB(150, 200, 255), Color3.fromRGB(200, 100, 255))
	local pDesc = Instance.new("TextLabel", pBox); pDesc.Size = UDim2.new(0.9, 0, 0, 70); pDesc.Position = UDim2.new(0.05, 0, 0, 40); pDesc.BackgroundTransparency = 1; pDesc.Font = Enum.Font.GothamMedium; pDesc.TextColor3 = Color3.fromRGB(180, 180, 190); pDesc.TextSize = 11; pDesc.TextWrapped = true; pDesc.Text = "Face brutally mutated memories that scale infinitely in power to earn Path Dust."
	pStats = Instance.new("TextLabel", pBox); pStats.Size = UDim2.new(1, 0, 0, 20); pStats.Position = UDim2.new(0, 0, 0, 120); pStats.BackgroundTransparency = 1; pStats.Font = Enum.Font.GothamBlack; pStats.TextColor3 = Color3.fromRGB(150, 255, 255); pStats.TextSize = 11; pStats.Text = "CURRENT MEMORY: 1   |   PATH DUST: 0"
	pBtn = Instance.new("TextButton", pBox); pBtn.Size = UDim2.new(0, 160, 0, 40); pBtn.AnchorPoint = Vector2.new(0.5, 0); pBtn.Position = UDim2.new(0.5, 0, 1, -50); pBtn.Font = Enum.Font.GothamBlack; pBtn.TextColor3 = Color3.fromRGB(150, 200, 255); pBtn.TextSize = 13; pBtn.Text = "ENTER THE PATHS"
	ApplyButtonGradient(pBtn, Color3.fromRGB(25, 25, 35), Color3.fromRGB(15, 15, 20), Color3.fromRGB(100, 150, 255))
	pBtn.MouseButton1Click:Connect(function() if pBtn.Active then Network:WaitForChild("CombatAction"):FireServer("EngagePaths") end end)

	-- [[ 4. RAIDS TAB (MOBILE OPTIMIZED: Stacked Layout) ]]
	SubTabs["Raids"] = Instance.new("ScrollingFrame", ContentArea); SubTabs["Raids"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Raids"].BackgroundTransparency = 1; SubTabs["Raids"].ScrollBarThickness = 0; SubTabs["Raids"].Visible = false
	local rListLayout = Instance.new("UIListLayout", SubTabs["Raids"]); rListLayout.Padding = UDim.new(0, 15); rListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; rListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local rPad = Instance.new("UIPadding", SubTabs["Raids"]); rPad.PaddingTop = UDim.new(0, 5); rPad.PaddingBottom = UDim.new(0, 20)

	-- Top Half: Raids
	local RaidContainer = Instance.new("Frame", SubTabs["Raids"]); RaidContainer.Size = UDim2.new(0.95, 0, 0, 0); RaidContainer.AutomaticSize = Enum.AutomaticSize.Y; RaidContainer.BackgroundTransparency = 1; RaidContainer.LayoutOrder = 1
	local rcLayout = Instance.new("UIListLayout", RaidContainer); rcLayout.Padding = UDim.new(0, 10); rcLayout.SortOrder = Enum.SortOrder.LayoutOrder

	for _, rInfo in ipairs(raidList) do
		local card = Instance.new("Frame", RaidContainer); card.Size = UDim2.new(1, 0, 0, 80); card.BackgroundColor3 = Color3.fromRGB(20, 20, 25); card.LayoutOrder = rInfo.Req
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6); local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(60, 50, 50); stroke.Thickness = 1
		local accentBar = Instance.new("Frame", card); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(180, 60, 60); Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local title = Instance.new("TextLabel", card); title.Size = UDim2.new(1, -110, 0, 20); title.Position = UDim2.new(0, 12, 0, 10); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.fromRGB(255, 100, 100); title.TextSize = 13; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = rInfo.Name
		local desc = Instance.new("TextLabel", card); desc.Size = UDim2.new(1, -110, 1, -35); desc.Position = UDim2.new(0, 12, 0, 30); desc.BackgroundTransparency = 1; desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(180, 170, 170); desc.TextSize = 10; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = rInfo.Desc

		local btn = Instance.new("TextButton", card); btn.Size = UDim2.new(0, 90, 0, 35); btn.AnchorPoint = Vector2.new(1, 0.5); btn.Position = UDim2.new(1, -10, 0.5, 0); btn.Font = Enum.Font.GothamBlack; btn.TextColor3 = Color3.fromRGB(255, 100, 100); btn.TextSize = 11; btn.Text = "DEPLOY"
		ApplyButtonGradient(btn, Color3.fromRGB(35, 20, 20), Color3.fromRGB(20, 10, 10), Color3.fromRGB(180, 60, 60))

		btn.MouseButton1Click:Connect(function() if btn.Active then Network:WaitForChild("RaidAction"):FireServer("DeployParty", {RaidId = rInfo.Id}) end end)
		rBtns[rInfo.Id] = { Btn = btn, Req = rInfo.Req, Stroke = stroke, Accent = accentBar }
	end

	-- Bottom Half: Party Menu
	local PartyPanel = Instance.new("Frame", SubTabs["Raids"]); PartyPanel.Size = UDim2.new(0.95, 0, 0, 180); PartyPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 25); PartyPanel.LayoutOrder = 2
	Instance.new("UICorner", PartyPanel).CornerRadius = UDim.new(0, 8); Instance.new("UIStroke", PartyPanel).Color = Color3.fromRGB(80, 80, 90)

	PartyHeader = Instance.new("TextLabel", PartyPanel); PartyHeader.Size = UDim2.new(1, 0, 0, 30); PartyHeader.BackgroundTransparency = 1; PartyHeader.Font = Enum.Font.GothamBlack; PartyHeader.Text = "RAID PARTY (1/3)"; PartyHeader.TextColor3 = Color3.fromRGB(255, 215, 100); PartyHeader.TextSize = 14

	PartyListContainer = Instance.new("ScrollingFrame", PartyPanel); PartyListContainer.Size = UDim2.new(1, -10, 0, 90); PartyListContainer.Position = UDim2.new(0, 5, 0, 30); PartyListContainer.BackgroundTransparency = 1; PartyListContainer.ScrollBarThickness = 0
	local pListLayout = Instance.new("UIListLayout", PartyListContainer); pListLayout.Padding = UDim.new(0, 5); pListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local pActionFrame = Instance.new("Frame", PartyPanel); pActionFrame.Size = UDim2.new(1, 0, 0, 45); pActionFrame.Position = UDim2.new(0, 0, 1, -50); pActionFrame.BackgroundTransparency = 1
	local pActionLayout = Instance.new("UIListLayout", pActionFrame); pActionLayout.FillDirection = Enum.FillDirection.Horizontal; pActionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; pActionLayout.VerticalAlignment = Enum.VerticalAlignment.Center; pActionLayout.Padding = UDim.new(0, 10)

	local InviteBox = Instance.new("TextBox", pActionFrame); InviteBox.Size = UDim2.new(0, 130, 0, 35); InviteBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18); InviteBox.TextColor3 = Color3.new(1,1,1); InviteBox.PlaceholderText = "Username..."; InviteBox.Font = Enum.Font.Gotham; InviteBox.TextSize = 12; Instance.new("UICorner", InviteBox).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", InviteBox).Color = Color3.fromRGB(60, 60, 70)

	local InviteBtn = Instance.new("TextButton", pActionFrame); InviteBtn.Size = UDim2.new(0, 80, 0, 35); InviteBtn.Font = Enum.Font.GothamBlack; InviteBtn.Text = "INVITE"; InviteBtn.TextColor3 = Color3.new(1,1,1); InviteBtn.TextSize = 11
	ApplyButtonGradient(InviteBtn, Color3.fromRGB(60, 120, 200), Color3.fromRGB(30, 60, 100), Color3.fromRGB(40, 80, 140))

	local LeavePartyBtn = Instance.new("TextButton", pActionFrame); LeavePartyBtn.Size = UDim2.new(0, 80, 0, 35); LeavePartyBtn.Font = Enum.Font.GothamBlack; LeavePartyBtn.Text = "LEAVE"; LeavePartyBtn.TextColor3 = Color3.new(1,1,1); LeavePartyBtn.TextSize = 11
	ApplyButtonGradient(LeavePartyBtn, Color3.fromRGB(160, 60, 60), Color3.fromRGB(100, 30, 30), Color3.fromRGB(60, 20, 20))

	InviteBtn.MouseButton1Click:Connect(function()
		if InviteBox.Text ~= "" then PartyAction:FireServer("Invite", InviteBox.Text); InviteBox.Text = ""
		else PartyAction:FireServer("Create") end
	end)
	LeavePartyBtn.MouseButton1Click:Connect(function() PartyAction:FireServer("Leave") end)

	task.delay(0.1, function() SubTabs["Raids"].CanvasSize = UDim2.new(0, 0, 0, rListLayout.AbsoluteContentSize.Y + 20) end)


	-- [[ 5. WORLD BOSSES TAB ]]
	SubTabs["World"] = Instance.new("ScrollingFrame", ContentArea); SubTabs["World"].Size = UDim2.new(1, 0, 1, 0); SubTabs["World"].BackgroundTransparency = 1; SubTabs["World"].BorderSizePixel = 0; SubTabs["World"].ScrollBarThickness = 0; SubTabs["World"].Visible = false
	local wListLayout = Instance.new("UIListLayout", SubTabs["World"]); wListLayout.Padding = UDim.new(0, 10); wListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; wListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	local wPad = Instance.new("UIPadding", SubTabs["World"]); wPad.PaddingTop = UDim.new(0, 5); wPad.PaddingBottom = UDim.new(0, 20)

	local sortedBosses = {}
	for bId, bData in pairs(EnemyData.WorldBosses) do table.insert(sortedBosses, {Id = bId, Data = bData}) end
	table.sort(sortedBosses, function(a, b) return (a.Data.Health or 0) < (b.Data.Health or 0) end)

	for _, bInfo in ipairs(sortedBosses) do
		local bId = bInfo.Id; local bData = bInfo.Data
		local card = Instance.new("Frame", SubTabs["World"]); card.Size = UDim2.new(0.95, 0, 0, 80); card.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6); local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(80, 60, 40); stroke.Thickness = 1; stroke.Transparency = 0.55
		local accentBar = Instance.new("Frame", card); accentBar.Size = UDim2.new(0, 4, 1, 0); accentBar.BackgroundColor3 = Color3.fromRGB(200, 120, 50); Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 4)

		local title = Instance.new("TextLabel", card); title.Size = UDim2.new(1, -110, 0, 20); title.Position = UDim2.new(0, 12, 0, 10); title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold; title.TextColor3 = Color3.fromRGB(255, 180, 50); title.TextSize = 13; title.TextXAlignment = Enum.TextXAlignment.Left; title.Text = bData.Name
		local desc = Instance.new("TextLabel", card); desc.Size = UDim2.new(1, -110, 1, -35); desc.Position = UDim2.new(0, 12, 0, 30); desc.BackgroundTransparency = 1; desc.Font = Enum.Font.GothamMedium; desc.TextColor3 = Color3.fromRGB(180, 170, 160); desc.TextSize = 10; desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.Text = bData.Desc or "A massive world boss event."

		local btn = Instance.new("TextButton", card); btn.Size = UDim2.new(0, 90, 0, 35); btn.AnchorPoint = Vector2.new(1, 0.5); btn.Position = UDim2.new(1, -10, 0.5, 0); btn.Font = Enum.Font.GothamBlack; btn.TextColor3 = Color3.fromRGB(255, 180, 50); btn.TextSize = 11; btn.Text = "ENGAGE"
		ApplyButtonGradient(btn, Color3.fromRGB(40, 30, 20), Color3.fromRGB(20, 15, 10), Color3.fromRGB(200, 120, 50))

		btn.MouseButton1Click:Connect(function() Network:WaitForChild("CombatAction"):FireServer("EngageWorldBoss", {BossId = bId}) end)
	end
	task.delay(0.1, function() SubTabs["World"].CanvasSize = UDim2.new(0, 0, 0, wListLayout.AbsoluteContentSize.Y + 20) end)

	local function UpdateLocks()
		local currentPart = player:GetAttribute("CurrentPart") or 1
		local prestigeObj = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige")
		local prestige = prestigeObj and prestigeObj.Value or 0

		local floor = player:GetAttribute("PathsFloor") or 1
		local dust = player:GetAttribute("PathDust") or 0
		if pStats then pStats.Text = "CURRENT MEMORY: " .. floor .. "   |   PATH DUST: " .. dust end

		if currentPart > 8 then
			if CompletionBanner then CompletionBanner.Visible = true end
			if pBtn then ApplyButtonGradient(pBtn, Color3.fromRGB(25, 20, 35), Color3.fromRGB(15, 10, 20), Color3.fromRGB(100, 150, 255)); pBtn.Text = "ENTER THE PATHS"; pBtn.TextColor3 = Color3.fromRGB(150, 200, 255); pBtn.Active = true end
		else
			if CompletionBanner then CompletionBanner.Visible = false end
			if pBtn then ApplyButtonGradient(pBtn, Color3.fromRGB(25, 25, 30), Color3.fromRGB(15, 15, 20), Color3.fromRGB(60, 60, 70)); pBtn.Text = "LOCKED (BEAT CAMPAIGN)"; pBtn.TextColor3 = Color3.fromRGB(120, 120, 120); pBtn.Active = false end
		end

		for id, data in pairs(cBtns) do
			if currentPart > id then
				ApplyButtonGradient(data.Btn, Color3.fromRGB(20, 30, 40), Color3.fromRGB(15, 20, 30), Color3.fromRGB(80, 140, 220)); data.Btn.Text = "REPLAY"; data.Btn.TextColor3 = Color3.fromRGB(150, 200, 255); data.Btn.Active = true; data.Stroke.Color = Color3.fromRGB(60, 80, 120); data.Accent.BackgroundColor3 = Color3.fromRGB(80, 140, 220)
			elseif currentPart == id then
				ApplyButtonGradient(data.Btn, Color3.fromRGB(25, 40, 25), Color3.fromRGB(15, 25, 15), Color3.fromRGB(80, 180, 80)); data.Btn.Text = "DEPLOY"; data.Btn.TextColor3 = Color3.fromRGB(150, 255, 150); data.Btn.Active = true; data.Stroke.Color = Color3.fromRGB(60, 100, 60); data.Accent.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
			else
				ApplyButtonGradient(data.Btn, Color3.fromRGB(25, 25, 30), Color3.fromRGB(15, 15, 20), Color3.fromRGB(60, 60, 70)); data.Btn.Text = "LOCKED"; data.Btn.TextColor3 = Color3.fromRGB(120, 120, 120); data.Btn.Active = false; data.Stroke.Color = Color3.fromRGB(40, 40, 50); data.Accent.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			end
		end

		for _, data in pairs(rBtns) do
			if prestige < data.Req then
				ApplyButtonGradient(data.Btn, Color3.fromRGB(25, 25, 30), Color3.fromRGB(15, 15, 20), Color3.fromRGB(60, 60, 70))
				data.Btn.Text = "LOCKED (PRESTIGE " .. data.Req .. ")"; data.Btn.TextColor3 = Color3.fromRGB(120, 120, 120); data.Btn.Active = false
				data.Stroke.Color = Color3.fromRGB(40, 40, 50); data.Accent.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
			else
				ApplyButtonGradient(data.Btn, Color3.fromRGB(40, 25, 25), Color3.fromRGB(25, 15, 15), Color3.fromRGB(180, 60, 60))
				data.Btn.Text = "DEPLOY PARTY"; data.Btn.TextColor3 = Color3.fromRGB(255, 150, 150); data.Btn.Active = true
				data.Stroke.Color = Color3.fromRGB(100, 50, 50); data.Accent.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
			end
		end
	end

	local lastKnownPart = player:GetAttribute("CurrentPart") or 1
	player.AttributeChanged:Connect(function(attr)
		if attr == "CurrentPart" then lastKnownPart = player:GetAttribute("CurrentPart") or 1; UpdateLocks()
		elseif attr == "PathsFloor" or attr == "PathDust" then UpdateLocks() end
	end)

	task.spawn(function()
		local pObj = player:WaitForChild("leaderstats", 10) and player.leaderstats:WaitForChild("Prestige", 10)
		if pObj then pObj.Changed:Connect(UpdateLocks) end
		UpdateLocks()
		ApplyButtonGradient(SubBtns["Campaign"], Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), Color3.fromRGB(255, 215, 100)); SubBtns["Campaign"].TextColor3 = Color3.fromRGB(255, 255, 255)
	end)

	Network:WaitForChild("CombatUpdate").OnClientEvent:Connect(function(action, data)
		if (action == "Defeat" or action == "Fled") and data.Battle and data.Battle.Context.IsPaths then
			for k, frame in pairs(SubTabs) do frame.Visible = (k == "Paths") end
			for k, v in pairs(SubBtns) do ApplyButtonGradient(v, Color3.fromRGB(50, 50, 55), Color3.fromRGB(25, 25, 30), Color3.fromRGB(60, 60, 65)); v.TextColor3 = Color3.fromRGB(180, 180, 180) end
			ApplyButtonGradient(SubBtns["Paths"], Color3.fromRGB(200, 150, 40), Color3.fromRGB(120, 80, 15), Color3.fromRGB(255, 215, 100)); SubBtns["Paths"].TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end)

	PartyUpdate.OnClientEvent:Connect(function(action, data)
		if action == "UpdateList" then
			CurrentParty = data
			PartyHeader.Text = "RAID PARTY (" .. #data .. "/3)"
			for _, child in ipairs(PartyListContainer:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
			for _, member in ipairs(data) do
				local mFrame = Instance.new("Frame", PartyListContainer); mFrame.Size = UDim2.new(1, 0, 0, 35); mFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35); Instance.new("UICorner", mFrame).CornerRadius = UDim.new(0, 6)
				local avatar = Instance.new("ImageLabel", mFrame); avatar.Size = UDim2.new(0, 25, 0, 25); avatar.Position = UDim2.new(0, 5, 0, 5); avatar.BackgroundTransparency = 1; avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. member.UserId .. "&w=150&h=150"
				local nameLbl = Instance.new("TextLabel", mFrame); nameLbl.Size = UDim2.new(0.7, 0, 1, 0); nameLbl.Position = UDim2.new(0, 40, 0, 0); nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold; nameLbl.Text = member.Name .. (member.IsLeader and " (Leader)" or ""); nameLbl.TextColor3 = member.IsLeader and Color3.fromRGB(255, 215, 100) or Color3.new(1,1,1); nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.TextSize = 11
			end
			task.delay(0.05, function() PartyListContainer.CanvasSize = UDim2.new(0, 0, 0, pListLayout.AbsoluteContentSize.Y + 10) end)
		elseif action == "Disbanded" then
			CurrentParty = {}; PartyHeader.Text = "RAID PARTY (0/3)"
			for _, child in ipairs(PartyListContainer:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
		elseif action == "IncomingInvite" then
			local leaderName = data
			local NotifMgr = require(script.Parent.NotificationManager)
			NotifMgr.Show("Raid Invite from " .. leaderName .. "! Type /accept " .. leaderName, "Success")
			local chatConn
			chatConn = player.Chatted:Connect(function(msg)
				if string.lower(msg) == "/accept " .. string.lower(leaderName) then PartyAction:FireServer("AcceptInvite", leaderName); chatConn:Disconnect() end
			end)
			task.delay(30, function() if chatConn then chatConn:Disconnect() end end) 
		end
	end)

	task.spawn(function() task.wait(2); PartyAction:FireServer("Create") end)
end

function BattleTab.Show() if MainFrame then MainFrame.Visible = true end end
return BattleTab