---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon
local msg = Private.MessageUtil
local stats = Private.StatsUtil
local vipUtil = Private.VipUtil

---@class ChatCommands
local chatCommands = {}

Private.ChatCommands = chatCommands

function chatCommands.OnWhisper(_, _, ...)
    local message, sender = ...
    local senderGUID = select(12, ...)
    if not message:match("!") then return end
    local command = message:match("!([%a%d]+)")
    if not command then return end
    command = command:lower()

    if command == "rules" then
        msg:SendMessage("RULES", "WHISPER",
            { { sender }, {}, {}, { C_CurrencyInfo.GetCoinText(addon:GetDatabaseValue("minBet") * 10000), C_CurrencyInfo.GetCoinText(addon:GetDatabaseValue("maxBet") * 10000) }, {} },
            sender)
    elseif command == "stats" and addon:GetDatabaseValue("allowStats") then
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
        local last10Games = stats:GetHistoryGames(10)
        local outcomes = { shouldRepeat = true }
        for i, game in ipairs(last10Games) do
            local sum = 0
            for _, roll in ipairs(game.rolls) do
                sum = sum + roll
            end
            tinsert(outcomes, { i, sum })
        end
        msg:SendMessage("NO_FORMAT", "WHISPER", { "Last Dice Rolls (Last 10 Games)" }, sender)
        msg:SendMessage("NUM_ENTRY", "WHISPER", outcomes, sender)
    elseif command == "vip" and vipUtil:CanUseCommands(senderGUID) then
        local currentLoyalty = vipUtil:GetPlayerValue(senderGUID)
        msg:SendMessage("NO_FORMAT", "WHISPER",
            { string.format("Your VIP Bonus is currently at %s. Use !payout to get this amount traded.", C_CurrencyInfo.GetCoinText(currentLoyalty)) },
            sender)
    elseif command == "payout" and vipUtil:CanUseCommands(senderGUID) then
        local currentLoyalty = vipUtil:GetPlayerValue(senderGUID)
        msg:SendMessage("NO_FORMAT", "WHISPER",
            { string.format("Trade me for your payout of your %s VIP Bonus.",
                C_CurrencyInfo.GetCoinText(currentLoyalty)) },
            sender)
        local pendingPayouts = addon:GetDatabaseValue("pendingPayout")
        local previousPay = pendingPayouts[senderGUID] or 0
        addon:SetDatabaseValue("pendingPayout." .. senderGUID, previousPay + currentLoyalty)
        addon:SetDatabaseValue("loyaltyAmount." .. senderGUID, 0)
    end
end

addon:RegisterEvent("CHAT_MSG_WHISPER", "ChatCommands.lua", chatCommands.OnWhisper)
