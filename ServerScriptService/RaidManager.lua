-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

local RaidAction = Network:FindFirstChild("RaidAction") or Instance.new("RemoteEvent", Network); RaidAction.Name = "RaidAction"
local RaidUpdate = Network:FindFirstChild("RaidUpdate") or Instance.new("RemoteEvent", Network); RaidUpdate.Name = "RaidUpdate"

local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local CombatCore = require(script.Parent:WaitForChild("CombatCore"))

local ActiveRaids = {}
local TURN_DURATION = 15

local AoESkills = { ["Colossal Steam"] = 0.40, ["Titan Roar"] = 0.30, ["Stomp"] = 0.25, ["Crushed Boulders"] = 0.35 }

local function CreateCombatant(player)
	local wpnName = player:GetAttribute("EquippedWeapon") or "None"
	local accName = player:GetAttribute("EquippedAccessory") or "None"
	local wpnBonus = (ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Bonus) or {}
	local accBonus = (ItemData.Equipment[accName] and ItemData.Equipment[accName].Bonus) or {}

	local safeWpnName = wpnName:gsub("[^%w]", "")
	local awakenedString = player:GetAttribute(safeWpnName .. "_Awakened")
	local awakenedStats = { DmgMult = 1.0, DodgeBonus = 0, CritBonus = 0, HpBonus = 0, SpdBonus = 0, GasBonus = 0, HealOnKill = 0, IgnoreArmor = 0 }

	if awakenedString then
		for stat in string.gmatch(awakenedString, "[^|]+") do
			stat = stat:match("^%s*(.-)%s*$")
			if stat:find("DMG") then awakenedStats.DmgMult += tonumber(stat:match("%d+")) / 100
			elseif stat:find("DODGE") then awakenedStats.DodgeBonus += tonumber(stat:match("%d+"))
			elseif stat:find("CRIT") then awakenedStats.CritBonus += tonumber(stat:match("%d+"))
			elseif stat:find("MAX HP") then awakenedStats.HpBonus += tonumber(stat:match("%d+"))
			elseif stat:find("SPEED") then awakenedStats.SpdBonus += tonumber(stat:match("%d+"))
			elseif stat:find("GAS CAP") then awakenedStats.GasBonus += tonumber(stat:match("%d+"))
			elseif stat:find("IGNORE") then awakenedStats.IgnoreArmor += tonumber(stat:match("%d+")) / 100
			end
		end
	end

	local pMaxHP = ((player:GetAttribute("Health") or 10) + (wpnBonus.Health or 0) + (accBonus.Health or 0)) * 10 + awakenedStats.HpBonus
	local pMaxGas = ((player:GetAttribute("Gas") or 10) + (wpnBonus.Gas or 0) + (accBonus.Gas or 0)) * 10 + awakenedStats.GasBonus

	return {
		IsPlayer = true, Name = player.Name, PlayerObj = player, UserId = player.UserId,
		Clan = player:GetAttribute("Clan") or "None", Titan = player:GetAttribute("Titan") or "None",
		Style = ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Style or "None",
		HP = pMaxHP, MaxHP = pMaxHP, Gas = pMaxGas, MaxGas = pMaxGas, TitanEnergy = 100, MaxTitanEnergy = 100,
		TotalStrength = (player:GetAttribute("Strength") or 10) + (wpnBonus.Strength or 0) + (accBonus.Strength or 0),
		TotalDefense = (player:GetAttribute("Defense") or 10) + (wpnBonus.Defense or 0) + (accBonus.Defense or 0),
		TotalSpeed = (player:GetAttribute("Speed") or 10) + (wpnBonus.Speed or 0) + (accBonus.Speed or 0),
		TotalResolve = (player:GetAttribute("Resolve") or 10) + (wpnBonus.Resolve or 0) + (accBonus.Resolve or 0),
		Statuses = {}, Cooldowns = {}, Move = nil, TargetLimb = "Body", Aggro = 0
	}
end

local function EndRaid(raidId, isVictory)
	local raid = ActiveRaids[raidId]
	if not raid then return end

	local bData = EnemyData.RaidBosses[raid.BossId]

	for _, pData in ipairs(raid.Party) do
		local player = pData.PlayerObj
		if player and player.Parent then
			if isVictory then
				local drops = bData.Drops
				player.leaderstats.Dews.Value += drops.Dews
				player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + drops.XP)

				local lootMsg = "\nLoot: " .. drops.Dews .. " Dews, " .. drops.XP .. " XP"
				if drops.ItemChance then
					for iName, chance in pairs(drops.ItemChance) do
						if math.random(1, 100) <= chance then
							local safeName = iName:gsub("[^%w]", "") .. "Count"
							player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
							lootMsg = lootMsg .. "\n[RARE DROP] " .. iName .. "!"
						end
					end
				end
				Network.NotificationEvent:FireClient(player, "RAID CLEARED!" .. lootMsg, "Success")
				RaidUpdate:FireClient(player, "RaidEnded", true)
			else
				Network.NotificationEvent:FireClient(player, "Your party was wiped out...", "Error")
				RaidUpdate:FireClient(player, "RaidEnded", false)
			end
		end
	end
	ActiveRaids[raidId] = nil
end

local function ResolveRaidTurn(raidId)
	local raid = ActiveRaids[raidId]
	if not raid or raid.State == "Resolving" then return end
	raid.State = "Resolving"

	local turnDelay = 1.5
	-- [[ FIX: Provide the Combat Context so the engine doesn't break! ]]
	local raidContext = { Range = "Close", IsRaid = true }

	-- [[ PHASE 1: PLAYERS ATTACK ]]
	for _, actor in ipairs(raid.Party) do
		if actor.HP > 0 and raid.Boss.HP > 0 then
			if actor.Statuses and (actor.Statuses["Blinded"] or actor.Statuses["TrueBlind"] or actor.Statuses["Stun"]) then
				local logMsg = "<font color='#555555'>" .. actor.Name .. " is INCAPACITATED and lost their turn!</font>"
				for _, p in ipairs(raid.Party) do
					RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "None", BossData = raid.Boss, PartyData = raid.Party })
				end
				task.wait(turnDelay)
				continue
			end

			local skill = SkillData.Skills[actor.Move]
			if skill then
				if skill.GasCost then actor.Gas = math.max(0, actor.Gas - skill.GasCost) end
				if skill.EnergyCost then actor.TitanEnergy = math.max(0, actor.TitanEnergy - skill.EnergyCost) end
				if skill.Effect == "Rest" or actor.Move == "Recover" then actor.Gas = math.min(actor.MaxGas, actor.Gas + (actor.MaxGas * 0.40)) end
			end

			local startingBossHP = raid.Boss.HP
			-- [[ FIX: Passed raidContext into ExecuteStrike ]]
			local logMsg, didHit, shakeType = CombatCore.ExecuteStrike(actor, raid.Boss, actor.Move, actor.TargetLimb, actor.Name, raid.Boss.Name, "#55FFFF", "#FF5555", raidContext)

			local damageDealt = startingBossHP - raid.Boss.HP
			if damageDealt > 0 then actor.Aggro += damageDealt end

			for _, p in ipairs(raid.Party) do
				RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = shakeType, BossData = raid.Boss, SkillUsed = actor.Move, Attacker = actor.Name, PartyData = raid.Party })
			end
			task.wait(turnDelay)
		end
	end

	-- [[ PHASE 2: BOSS RETALIATES ]]
	local target = nil
	for _, p in ipairs(raid.Party) do
		if p.HP > 0 then
			if not target or p.Aggro > target.Aggro then target = p end
		end
	end

	if raid.Boss.HP > 0 and target then
		if raid.Boss.Statuses then
			if raid.Boss.Statuses["Stun"] then raid.Boss.Statuses["Crippled"] = raid.Boss.Statuses["Stun"]; raid.Boss.Statuses["Stun"] = nil end
			if raid.Boss.Statuses["Blinded"] then raid.Boss.Statuses["Weakened"] = raid.Boss.Statuses["Blinded"]; raid.Boss.Statuses["Blinded"] = nil end
			if raid.Boss.Statuses["TrueBlind"] then raid.Boss.Statuses["Weakened"] = raid.Boss.Statuses["TrueBlind"]; raid.Boss.Statuses["TrueBlind"] = nil end
		end

		local bSkills = raid.Boss.Skills
		local chosenSkill = bSkills[math.random(1, #bSkills)]

		if AoESkills[chosenSkill] then
			local aoePct = AoESkills[chosenSkill]
			local logMsg = "<font color='#FFAA00'><b>" .. raid.Boss.Name .. " unleashes " .. chosenSkill:upper() .. "! It hits the entire party!</b></font>\n"

			for _, p in ipairs(raid.Party) do
				if p.HP > 0 then
					local dmg = math.floor(p.MaxHP * aoePct)
					p.HP = math.max(0, p.HP - dmg)
					logMsg = logMsg .. "- " .. p.Name .. " takes " .. dmg .. " damage!\n"
				end
			end

			for _, p in ipairs(raid.Party) do
				RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = "Heavy", BossData = raid.Boss, SkillUsed = chosenSkill, Attacker = raid.Boss.Name, PartyData = raid.Party })
			end
			task.wait(turnDelay + 1)
		else
			-- [[ FIX: Passed raidContext into ExecuteStrike ]]
			local logMsg, didHit, shakeType = CombatCore.ExecuteStrike(raid.Boss, target, chosenSkill, "Body", raid.Boss.Name, target.Name, "#FF5555", "#FFFFFF", raidContext)
			for _, p in ipairs(raid.Party) do
				RaidUpdate:FireClient(p.PlayerObj, "TurnStrike", { LogMsg = logMsg, ShakeType = shakeType, BossData = raid.Boss, SkillUsed = chosenSkill, Attacker = raid.Boss.Name, PartyData = raid.Party })
			end
			task.wait(turnDelay)
		end
	end

	local function TickStatusesAndCooldowns(combatant)
		if not combatant then return end
		if combatant.Cooldowns then
			for sName, cd in pairs(combatant.Cooldowns) do
				if cd > 0 then combatant.Cooldowns[sName] = cd - 1 end
			end
		end

		if not combatant.Statuses then return end
		if combatant.Statuses["Bleed"] then combatant.HP -= math.min(combatant.MaxHP * 0.05, 500) end
		if combatant.Statuses["Burn"] then combatant.HP -= math.min(combatant.MaxHP * 0.05, 600) end

		for sName, dur in pairs(combatant.Statuses) do
			if type(dur) == "number" and sName ~= "Transformed" then
				combatant.Statuses[sName] = dur - 1
				if combatant.Statuses[sName] <= 0 then combatant.Statuses[sName] = nil end
			end
		end
	end

	for _, p in ipairs(raid.Party) do if p.HP > 0 then TickStatusesAndCooldowns(p) end end
	TickStatusesAndCooldowns(raid.Boss)

	if raid.Boss.HP <= 0 then EndRaid(raidId, true); return end

	local aliveCount = 0
	for _, p in ipairs(raid.Party) do if p.HP > 0 then aliveCount += 1 end end
	if aliveCount == 0 then EndRaid(raidId, false); return end

	for _, p in ipairs(raid.Party) do p.Move = nil end
	raid.Turn += 1
	raid.TurnEndTime = os.time() + TURN_DURATION
	raid.State = "WaitingForMoves"

	for _, p in ipairs(raid.Party) do
		RaidUpdate:FireClient(p.PlayerObj, "NextTurnStarted", { EndTime = raid.TurnEndTime, BossData = raid.Boss, PartyData = raid.Party })
	end
end

task.spawn(function()
	while task.wait(1) do
		local now = os.time()
		for raidId, raid in pairs(ActiveRaids) do
			if raid.State == "WaitingForMoves" and now >= raid.TurnEndTime then
				for _, p in ipairs(raid.Party) do
					if p.HP > 0 and not p.Move then
						p.Move = (p.Statuses and p.Statuses["Transformed"]) and "Titan Punch" or "Basic Slash"
						p.TargetLimb = "Body"
					end
				end
				ResolveRaidTurn(raidId)
			end
		end
	end
end)

RaidAction.OnServerEvent:Connect(function(player, action, data)
	if action == "DeployParty" then
		if not _G.GetPlayerParty then Network.NotificationEvent:FireClient(player, "Party System is still loading.", "Error"); return end
		local partyData = _G.GetPlayerParty(player)
		if partyData.Leader.UserId ~= player.UserId then Network.NotificationEvent:FireClient(player, "Only the Party Leader can start the Raid.", "Error"); return end

		local bossData = EnemyData.RaidBosses[data.RaidId]
		if not bossData then return end

		local raidId = "Raid_" .. player.UserId .. "_" .. os.time()
		local memberCount = #partyData.Members
		local scale = 1 + ((memberCount - 1) * 0.3)
		local bMaxHP = math.floor(bossData.Health * scale)

		-- [[ FIX: Correctly import GateHP (Shields) so Armored Titan takes damage! ]]
		ActiveRaids[raidId] = {
			BossId = data.RaidId, Turn = 1, State = "WaitingForMoves", TurnEndTime = os.time() + TURN_DURATION, Party = {},
			Boss = { 
				IsPlayer = false, Name = bossData.Name, HP = bMaxHP, MaxHP = bMaxHP, 
				GateHP = bossData.GateHP, MaxGateHP = bossData.GateHP, GateType = bossData.GateType,
				TotalStrength = bossData.Strength, TotalDefense = bossData.Defense, TotalSpeed = bossData.Speed, 
				Skills = bossData.Skills, Statuses = {}, Cooldowns = {} 
			}
		}

		for _, member in ipairs(partyData.Members) do table.insert(ActiveRaids[raidId].Party, CreateCombatant(member)) end
		for _, member in ipairs(partyData.Members) do RaidUpdate:FireClient(member, "RaidStarted", { RaidId = raidId, BossData = ActiveRaids[raidId].Boss, PartyData = ActiveRaids[raidId].Party, EndTime = ActiveRaids[raidId].TurnEndTime }) end

	elseif action == "SubmitMove" then
		local raidId = data.RaidId
		local raid = ActiveRaids[raidId]
		if not raid or raid.State ~= "WaitingForMoves" then return end

		local allReady = true
		for _, p in ipairs(raid.Party) do
			if p.UserId == player.UserId then p.Move = data.Move; p.TargetLimb = data.Limb or "Body" end
			if p.HP > 0 and not p.Move then allReady = false end
		end

		if allReady then ResolveRaidTurn(raidId) end
	end
end)