---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon
local msg = Private.MessageUtil
local tradesUtil = Private.TradesUtil

---@class GameUtil
local gameUtil = {
    ---@class GameInfo : TradeInfo
    ---@field rolls table
    ---@field payout number
    ---@field choice "UNDER"|"OVER"|"7"|?
    ---@field outcome "WIN"|"LOSE"|?
    activeGames = {}
}
Private.GameUtil = gameUtil

function gameUtil:UpdateUI()
    if Private.UI and Private.UI.UpdateGameState then
        local gamesArray = {}
        for _, game in pairs(self.activeGames) do
            table.insert(gamesArray, game)
        end
        Private.UI:UpdateGameState(gamesArray)
    end
end

---@param _ string
---@param tradeInfo TradeInfo
function gameUtil.NewGame(_, tradeInfo)
    if not tradeInfo then return end
    if not tradeInfo.bet or tradeInfo.bet <= 0 then return end
    local newGame = {
        guid = tradeInfo.guid,
        name = tradeInfo.name,
        bet = tradeInfo.bet,
        rolls = {},
        payout = 0,
        choice = nil
    }
    gameUtil.activeGames[tradeInfo.guid] = newGame
    gameUtil:UpdateUI()
end

function gameUtil.SelectChoice(...)
    local args = { ... }
    local guid, message

    if #args == 2 then
        -- Esta es una llamada de prueba
        guid, message = args[1], args[2]
    else
        -- Esta es una llamada normal del juego
        guid = select(14, ...)
        message = select(3, ...)
    end

    local game = gameUtil.activeGames[guid]
    if not game or game.choice then return end

    if const.CHOICES[message:upper()] then
        game.choice = message:upper()
        msg:SendMessage("CHOICE_PICKED", "WHISPER", { message }, game.name)

        -- Verificar si todos los juegos activos tienen una elección
        local allGamesHaveChoice = true
        local activePlayersWithChoice = {}
        for _, activeGame in pairs(gameUtil.activeGames) do
            if not activeGame.choice then
                allGamesHaveChoice = false
                break
            else
                table.insert(activePlayersWithChoice, activeGame.name)
            end
        end

        -- Si todos los juegos tienen una elección, enviar el mensaje "Rolling the dice, Good luck"
        if allGamesHaveChoice then
            local playerNames = table.concat(activePlayersWithChoice, " @")
            local goodLuckMessage = "Rolling the dice, Good luck @" .. playerNames
            SendChatMessage(goodLuckMessage, "SAY")
        end

        gameUtil:UpdateUI()
        return
    end
    msg:SendMessage("CHOICE_PENDING", "WHISPER", { game.name }, game.name)
end

function gameUtil:SaveGame(guid)
    local game = self.activeGames[guid]
    if not game then return end

    local gameToSave = {
        guid = game.guid,
        name = game.name,
        bet = game.bet,
        rolls = game.rolls,
        payout = game.payout,
        choice = game.choice,
        outcome = game.outcome,
        time = time()
    }

    local completeGames = addon:GetDatabaseValue("completeGames") or {}
    local gameCounter = addon:GetDatabaseValue("gameCounter") or 0
    gameCounter = gameCounter + 1

    completeGames[tostring(gameCounter)] = gameToSave
    addon:SetDatabaseValue("completeGames", completeGames)
    addon:SetDatabaseValue("gameCounter", gameCounter)

    -- Reiniciar el caché del historial para asegurar que se actualice en la próxima recuperación
    Private.StatsUtil.historyCache = {
        DB = {},
        indexedDB = {},
        lastUpdate = 0
    }

    if game.outcome == "WIN" then
        local pendingPayouts = addon:GetDatabaseValue("pendingPayout") or {}
        local previousPay = pendingPayouts[game.guid] or 0
        pendingPayouts[game.guid] = previousPay + game.payout
        addon:SetDatabaseValue("pendingPayout", pendingPayouts)
        msg:SendMessage("WON_PAYOUT", "WHISPER", { C_CurrencyInfo.GetCoinText(game.payout) }, game.name)
    elseif game.outcome == "LOSE" and addon:GetDatabaseValue("whisperLose") then
        msg:SendMessage("GAME_OUTCOME", "WHISPER", { game.rolls[1] + game.rolls[2], game.outcome }, game.name)
    end

    self.activeGames[guid] = nil
    gameUtil:UpdateUI()
end

function gameUtil.CheckRolls(_, _, message)
    if message:match(const.ROLL_MESSAGE_MATCH) then
        local roll = tonumber(message:match("%d")) or 0
        for guid, game in pairs(gameUtil.activeGames) do
            if game.choice and #game.rolls < 2 then
                table.insert(game.rolls, roll)
                gameUtil:ProcessOutcome(guid)
            end
        end
    end
end

function gameUtil:GetPlayerJackpotData(guid)
    local jackpotData = addon:GetDatabaseValue("playerJackpotData") or {}
    if not jackpotData[guid] then
        jackpotData[guid] = { consecutiveWins = 0, lastBetAmount = 0 }
        addon:SetDatabaseValue("playerJackpotData", jackpotData)
    end
    return jackpotData[guid]
end

function gameUtil:UpdatePlayerJackpotData(guid, consecutiveWins, lastBetAmount)
    local jackpotData = addon:GetDatabaseValue("playerJackpotData") or {}
    jackpotData[guid] = { consecutiveWins = consecutiveWins, lastBetAmount = lastBetAmount }
    addon:SetDatabaseValue("playerJackpotData", jackpotData)
end

function gameUtil:ProcessJackpot(game)
    if not addon:GetDatabaseValue("jackpotEnabled") then
        return 0
    end

    local jackpotData = self:GetPlayerJackpotData(game.guid)

    if game.bet == jackpotData.lastBetAmount then
        jackpotData.consecutiveWins = jackpotData.consecutiveWins + 1
    else
        jackpotData.consecutiveWins = 1
    end
    jackpotData.lastBetAmount = game.bet

    local bonusAmount = 0
    local jackpotHit = false

    local function checkJackpot(level, enabled, percent)
        if jackpotData.consecutiveWins == level and addon:GetDatabaseValue(enabled) then
            bonusAmount = math.floor(game.bet * (addon:GetDatabaseValue(percent) / 100))
            jackpotHit = true
            msg:SendMessage("JACKPOT_WIN", "WHISPER", { C_CurrencyInfo.GetCoinText(bonusAmount), level }, game.name)
        end
    end

    checkJackpot(3, "jackpotx3Enabled", "jackpotx3Percent")
    checkJackpot(5, "jackpotx5Enabled", "jackpotx5Percent")
    checkJackpot(7, "jackpotx7Enabled", "jackpotx7Percent")

    local highestEnabledJackpot = 0
    if addon:GetDatabaseValue("jackpotx7Enabled") then
        highestEnabledJackpot = 7
    elseif addon:GetDatabaseValue("jackpotx5Enabled") then
        highestEnabledJackpot = 5
    elseif addon:GetDatabaseValue("jackpotx3Enabled") then
        highestEnabledJackpot = 3
    end

    if not jackpotHit then
        msg:SendMessage("JACKPOT_PROGRESS", "WHISPER",
            { jackpotData.consecutiveWins, highestEnabledJackpot }, game.name)
    else
        if jackpotData.consecutiveWins >= highestEnabledJackpot then
            jackpotData.consecutiveWins = 0
        end
    end

    self:UpdatePlayerJackpotData(game.guid, jackpotData.consecutiveWins, jackpotData.lastBetAmount)
    return bonusAmount
end

function gameUtil:ProcessOutcome(guid)
    local game = self.activeGames[guid]
    if not game or game.outcome or #game.rolls < 2 then return end

    local sum = game.rolls[1] + game.rolls[2]
    local outcome = sum < 7 and "UNDER" or sum > 7 and "OVER" or "7"

    if outcome == game.choice then
        game.outcome = "WIN"
        game.payout = game.bet * 2
        if outcome == "7" then
            game.payout = game.payout * 2
        end

        game.payout = game.payout + self:ProcessJackpot(game)
    else
        game.outcome = "LOSE"
        self:UpdatePlayerJackpotData(game.guid, 0, 0)
    end

    self:SaveGame(guid)

    if game.outcome == "LOSE" and not addon:GetDatabaseValue("whisperLose") then
        return
    end
    msg:SendMessage("GAME_OUTCOME", "WHISPER", { sum, game.outcome }, game.name)
end

function gameUtil:HandleTradeRequest(playerName)
    local hasActiveGame = false
    for _, game in pairs(self.activeGames) do
        if game.name == playerName and not game.outcome then
            hasActiveGame = true
            break
        end
    end

    if hasActiveGame then
        msg:SendMessage("BUSY_WITH_GAME", "WHISPER", {}, playerName)
    end
end

function gameUtil:CreateDBCallback()
    addon:CreateDatabaseCallback("activeGame", gameUtil.NewGame)
end

-- Event registrations
addon:RegisterEvent("CHAT_MSG_SYSTEM", "GameUtil.lua", gameUtil.CheckRolls)
addon:RegisterEvent("CHAT_MSG_WHISPER", "GameUtil.lua", gameUtil.SelectChoice)
addon:RegisterEvent("CHAT_MSG_SAY", "GameUtil.lua", gameUtil.SelectChoice)

-- Commented out functions that might need revision:

-- function gameUtil:AttemptTargetPlayer(playerName)
--     local macroText = "/target " .. playerName
--     RunMacroText(macroText)

--     C_Timer.After(0.5, function()
--         if UnitName("target") == playerName then
--             if CheckInteractDistance("target", 2) then
--                 InitiateTrade("target")
--             else
--                 print("El jugador " .. playerName .. " está demasiado lejos para iniciar un intercambio.")
--             end
--         else
--             print("No se pudo encontrar al jugador " .. playerName .. " para iniciar el intercambio.")
--         end
--     end)
-- end

-- local function onTradeShow()
--     local playerName = tradesUtil.newTrade()
--     if playerName then
--         gameUtil:HandleTradeRequest(playerName)
--     else
--         print("Error: Trade initiated but couldn't get initiator's name")
--     end
-- end

-- addon:RegisterEvent("TRADE_SHOW", "GameUtil.lua", gameUtil.newTrade)
