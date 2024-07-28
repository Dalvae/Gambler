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
    if not ... then return end
    local guid = select(14, ...)
    local game = gameUtil.activeGames[guid]
    if not game or game.choice then return end
    local message = select(3, ...)
    if const.CHOICES[message:upper()] then
        game.choice = message:upper()
        msg:SendMessage("CHOICE_PICKED", "WHISPER", { message }, game.name)
        gameUtil:UpdateUI()
        return
    end
    msg:SendMessage("CHOICE_PENDING", "WHISPER", { game.name }, game.name)
end

function gameUtil:SaveGame(guid)
    local game = self.activeGames[guid]
    local currentTime = time()
    addon:SetDatabaseValue("completeGames." .. currentTime, game)

    if game.outcome == "WIN" then
        local pendingPayouts = addon:GetDatabaseValue("pendingPayout")
        local previousPay = pendingPayouts[game.guid] or 0
        addon:SetDatabaseValue("pendingPayout." .. game.guid, previousPay + game.payout)
        msg:SendMessage("WON_PAYOUT", "WHISPER", { C_CurrencyInfo.GetCoinText(game.payout) }, game.name)
    end

    self.activeGames[guid] = nil
    gameUtil:UpdateUI()
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
    else
        game.outcome = "LOSE"
    end

    self:SaveGame(guid)

    if game.outcome == "LOSE" and not addon:GetDatabaseValue("whisperLose") then
        return
    end
    msg:SendMessage("GAME_OUTCOME", "WHISPER", { sum, game.outcome }, game.name)
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
