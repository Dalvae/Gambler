---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon
local msg = Private.MessageUtil
local stats = Private.StatsUtil
local vipUtil = Private.VipUtil
local gameUtil = Private.GameUtil
---@class ChatCommands
local chatCommands = {}
Private.ChatCommands = chatCommands

local function matchCommand(message, commands)
    message = message:lower():gsub("^%s*!?%s*", "")
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

    if sender ~= UnitName("player") then
        local ruleCommands = {
            "rules", "rule", "info", "howtoplay", "howdoiplay", "howtogamble"
        }
        local jackpotCommands = {
            "jackpot", "jack pot"
        }
        if matchCommand(message, ruleCommands) or message:lower():match("how do i play") then
            msg:SendMessage("RULES1", "WHISPER", { sender }, sender)
            msg:SendMessage("RULES2", "WHISPER", {}, sender)
            msg:SendMessage("RULES3", "WHISPER", {}, sender)
            msg:SendMessage("RULES4", "WHISPER",
                { C_CurrencyInfo.GetCoinText(addon:GetDatabaseValue("minBet") * 10000), C_CurrencyInfo.GetCoinText(addon
                    :GetDatabaseValue("maxBet") * 10000) }, sender)

            if addon:GetDatabaseValue("jackpotEnabled") then
                msg:SendMessage("RULEJACKPOT", "WHISPER", {}, sender)
            end

            msg:SendMessage("RULES5", "WHISPER", {}, sender)
            return
        end

        if matchCommand(message, jackpotCommands) then
            if addon:GetDatabaseValue("jackpotEnabled") then
                msg:SendMessage("NO_FORMAT", "WHISPER",
                    {
                        "Win a Jackpot 5 times your bet by winning 5 consecutive bets of the same amount. Changing the bet amount resets the count. For example, five consecutive wins at 10,000g each nets you a 50,000g Jackpot!" },
                    sender)
            else
                msg:SendMessage("NO_FORMAT", "WHISPER", { "The Jackpot feature is currently disabled." }, sender)
            end
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
            if last7Games and #last7Games > 0 then
                local outcomes = {}
                for i, game in ipairs(last7Games) do
                    if game.rolls and #game.rolls == 2 then
                        local sum = game.rolls[1] + game.rolls[2]
                        table.insert(outcomes, string.format("[%d]", sum))
                    else
                        table.insert(outcomes, "[?]")
                    end
                end
                local rollsString = table.concat(outcomes, " ")
                msg:SendMessage("NO_FORMAT", "WHISPER", { "Last 7 Dice Rolls (Newest > Oldest): " .. rollsString },
                    sender)
            else
                msg:SendMessage("NO_FORMAT", "WHISPER", { "No se encontraron juegos recientes." }, sender)
            end
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
            local minLoyaltyPayout = 10000000 -- 1000 gold in copper

            if previousPay > 0 then
                msg:SendMessage("NO_FORMAT", "WHISPER",
                    { string.format("You already have a pending payout of %s. Trade me to receive it.",
                        C_CurrencyInfo.GetCoinText(previousPay)) },
                    sender)
            elseif currentLoyalty >= minLoyaltyPayout then
                addon:SetDatabaseValue("pendingPayout." .. senderGUID, currentLoyalty)
                msg:SendMessage("NO_FORMAT", "WHISPER",
                    { string.format("Trade me for your payout of your %s VIP Bonus.",
                        C_CurrencyInfo.GetCoinText(currentLoyalty)) },
                    sender)
            elseif currentLoyalty > 0 and currentLoyalty < minLoyaltyPayout then
                msg:SendMessage("NO_FORMAT", "WHISPER",
                    { string.format("You need at least %s in VIP Bonus to request a payout. Your current bonus is %s.",
                        C_CurrencyInfo.GetCoinText(minLoyaltyPayout),
                        C_CurrencyInfo.GetCoinText(currentLoyalty)) },
                    sender)
            else
                msg:SendMessage("NO_FORMAT", "WHISPER",
                    { "You don't have any VIP Bonus to payout at the moment." },
                    sender)
            end
        elseif command == "testwin" then
            local senderGUID = select(12, ...)
            local game = gameUtil.activeGames[senderGUID]

            if game and game.choice then
                -- Forzar las dos tiradas de dados con valor 1
                game.rolls[1] = 1
                game.rolls[2] = 1

                gameUtil:ProcessOutcome(senderGUID)
                print("Comand test win process for", sender)
            else
                print("There is no active game for ", sender)
            end
        end
    end
end

addon:RegisterEvent("CHAT_MSG_WHISPER", "ChatCommands.lua", chatCommands.OnWhisper)
