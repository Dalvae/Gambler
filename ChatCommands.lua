---@class AddonPrivate*
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon
local msg = Private.MessageUtil
local stats = Private.StatsUtil
local vipUtil = Private.VipUtil
---@class ChatCommands*
local chatCommands = {}
Private.ChatCommands = chatCommands

local function matchCommand(message, commands)
    message = message:lower():gsub("^%s*!?%s*", "") -- Remove leading spaces and optional !
    for _, cmd in ipairs(commands) do
        if message:find("^" .. cmd) then
            return true
        end
    end
    return false
end

function chatCommands.OnWhisper(_, _, ...)
    local message, sender = ...
    local senderGUID = select(12, ...)

    local ruleCommands = {
        "rules", "rule", "info", "howtoplay", "howdoiplay", "howtogamble"
    }

    if matchCommand(message, ruleCommands) or message:lower():match("how do i play") then
        msg:SendMessage("RULES", "WHISPER",
            { { sender }, {}, {}, { C_CurrencyInfo.GetCoinText(addon:GetDatabaseValue("minBet") * 10000), C_CurrencyInfo.GetCoinText(addon:GetDatabaseValue("maxBet") * 10000) }, {} },
            sender)
        return
    end

    if not message:match("!") then return end
    local command = message:match("!([%a%d]+)")
    if not command then return end
    command = command:lower()

    if command == "stats" and addon:GetDatabaseValue("allowStats") then
        local playerStats = stats:GetPlayerStats(senderGUID)
        msg:SendMessage("PERSONAL_STATS", "WHISPER",
            { playerStats.wins, playerStats.loses, C_CurrencyInfo.GetCoinText(playerStats.won), C_CurrencyInfo
                .GetCoinText(playerStats.paid) }, sender)
    elseif command == "lb" then
        local dayTops = stats:GetDayTops()
        local msgLeaderboard = { shouldRepeat = true }
        for i, playerStats in ipairs(dayTops) do
            if i > 10 then return end
            tinsert(msgLeaderboard,
                { i, string.format("%s won a total of %s", playerStats.playerName,
                    C_CurrencyInfo.GetCoinText(playerStats.stats.won)) })
        end
        msg:SendMessage("NO_FORMAT", "WHISPER", { "Top Winners (Last 24 Hours)" }, sender)
        msg:SendMessage("NUM_ENTRY", "WHISPER", msgLeaderboard, sender)
    elseif command == "10" then
        local last7Games = stats:GetHistoryGames(7)
        local outcomes = {}
        for i = #last7Games, 1, -1 do
            local game = last7Games[i]
            local sum = 0
            for _, roll in ipairs(game.rolls) do
                sum = sum + roll
            end
            table.insert(outcomes, string.format("[%d]", sum))
        end
        local rollsString = table.concat(outcomes, " ")
        msg:SendMessage("NO_FORMAT", "WHISPER", { "Last 7 Dice Rolls (Newest > Oldest): " .. rollsString }, sender)
    elseif command == "vip" and vipUtil:CanUseCommands(senderGUID) then
        local currentLoyalty = vipUtil:GetPlayerValue(senderGUID)
        msg:SendMessage("NO_FORMAT", "WHISPER",
            { string.format("Your VIP Bonus is currently at %s. Use !payout to get this amount traded.",
                C_CurrencyInfo.GetCoinText(currentLoyalty)) },
            sender)
    elseif command == "payout" and vipUtil:CanUseCommands(senderGUID) then
        local currentLoyalty = vipUtil:GetPlayerValue(senderGUID)
        local pendingPayouts = addon:GetDatabaseValue("pendingPayout")
        local previousPay = pendingPayouts[senderGUID] or 0

        if previousPay > 0 then
            msg:SendMessage("NO_FORMAT", "WHISPER",
                { string.format("You already have a pending payout of %s. Trade me to receive it.",
                    C_CurrencyInfo.GetCoinText(previousPay)) },
                sender)
        elseif currentLoyalty > 0 then
            addon:SetDatabaseValue("pendingPayout." .. senderGUID, currentLoyalty)
            msg:SendMessage("NO_FORMAT", "WHISPER",
                { string.format("Trade me for your payout of your %s VIP Bonus.",
                    C_CurrencyInfo.GetCoinText(currentLoyalty)) },
                sender)
        else
            msg:SendMessage("NO_FORMAT", "WHISPER",
                { "You don't have any VIP Bonus to payout at the moment." },
                sender)
        end
    end
end

addon:RegisterEvent("CHAT_MSG_WHISPER", "ChatCommands.lua", chatCommands.OnWhisper)
