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
    game = {}
}
Private.GameUtil = gameUtil

function gameUtil:UpdateUI()
    if Private.UI and Private.UI.UpdateGameState then
        Private.UI:UpdateGameState(self.game)
    end
end

---@param _ string
---@param tradeInfo TradeInfo
function gameUtil.NewGame(_, tradeInfo)
    if not tradeInfo then return end
    if not tradeInfo.bet or tradeInfo.bet <= 0 then return end
    gameUtil.game = {
        guid = tradeInfo.guid,
        name = tradeInfo.name,
        bet = tradeInfo.bet,
        rolls = {},
        payout = 0,
        choice = nil
    }
    gameUtil:UpdateUI()
end

function gameUtil.SelectChoice(...)
    if gameUtil.game.choice then return end
    if not ... then return end
    local guid = select(14, ...)
    if guid ~= gameUtil.game.guid then return end
    local message = select(3, ...)
    if const.CHOICES[message:upper()] then
        gameUtil.game.choice = message:upper()
        msg:SendMessage("CHOICE_PICKED", "WHISPER", { message }, gameUtil.game.name)
        gameUtil:UpdateUI()
        return
    end
    msg:SendMessage("CHOICE_PENDING", "WHISPER", { gameUtil.game.name }, gameUtil.game.name)
end

function gameUtil:SaveGame()
    local currentTime = time()
    addon:SetDatabaseValue("completeGames." .. currentTime, self.game)
    addon:SetDatabaseValue("activeGame", {})
    if self.game.outcome == "WIN" then
        local pendingPayouts = addon:GetDatabaseValue("pendingPayout")
        local previousPay = pendingPayouts[self.game.guid] or 0
        addon:SetDatabaseValue("pendingPayout." .. self.game.guid, previousPay + self.game.payout)
        msg:SendMessage("WON_PAYOUT", "WHISPER", { C_CurrencyInfo.GetCoinText(self.game.payout) }, self.game.name)
    end
    gameUtil:UpdateUI()
end

function gameUtil:ProcessOutcome()
    if self.game.outcome then return end
    if #self.game.rolls < 2 then return end
    local sum = 0
    for _, roll in ipairs(self.game.rolls) do
        sum = sum + roll
    end
    local outcome = ""
    if sum < 7 then
        outcome = "UNDER"
    elseif sum > 7 then
        outcome = "OVER"
    elseif sum == 7 then
        outcome = "7"
    end
    if outcome == self.game.choice then
        self.game.outcome = "WIN"
        self.game.payout = self.game.bet * 2
        if outcome == "7" then
            self.game.payout = self.game.payout * 2
        end
    else
        self.game.outcome = "LOSE"
    end
    self:SaveGame()

    if self.game.outcome == "LOSE" and not addon:GetDatabaseValue("whisperLose") then
        return
    end
    msg:SendMessage("GAME_OUTCOME", "WHISPER", { sum, self.game.outcome }, self.game.name)
end

function gameUtil.CheckRolls(_, _, message)
    if not gameUtil.game then return end
    if not gameUtil.game.choice then return end
    if message:match(const.ROLL_MESSAGE_MATCH) then
        local roll = message:match("%d")
        if #gameUtil.game.rolls < 2 then
            tinsert(gameUtil.game.rolls, tonumber(roll) or 0)
            gameUtil:ProcessOutcome()
        end
    end
end

function gameUtil:HandleTradeRequest(playerName)
    if self.game and not self.game.outcome then
        if playerName then
            msg:SendMessage("BUSY_WITH_GAME", "WHISPER", {}, playerName)
        else
            print("Error: Couldn't send whisper, player name is missing")
        end
    end
end

function gameUtil:CreateDBCallback()
    addon:CreateDatabaseCallback("activeGame", gameUtil.NewGame)
end

-- local function onTradeShow()
--     local playerName = tradesUtil.newTrade()
--     if playerName then
--         gameUtil:HandleTradeRequest(playerName)
--     else
--         print("Error: Trade initiated but couldn't get initiator's name")
--     end
-- end

-- addon:RegisterEvent("TRADE_SHOW", "GameUtil.lua", gameUtil.newTrade)
addon:RegisterEvent("CHAT_MSG_SYSTEM", "GameUtil.lua", gameUtil.CheckRolls)
addon:RegisterEvent("CHAT_MSG_WHISPER", "GameUtil.lua", gameUtil.SelectChoice)
addon:RegisterEvent("CHAT_MSG_SAY", "GameUtil.lua", gameUtil.SelectChoice)
