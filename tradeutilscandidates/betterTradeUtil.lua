---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon
local msg = Private.MessageUtil

---@class Trade
local Trade = {}

function Trade:new()
    local self = {}
    setmetatable(self, { __index = Trade })

    self.guid = UnitGUID("npc") or ""
    self.name, self.realm = GetUnitName("npc", true)
    if self.realm then
        self.name = string.format("%s-%s", self.name, self.realm)
    end

    local pendingPayouts = addon:GetDatabaseValue("pendingPayout")
    self.pendingPayout = pendingPayouts[self.guid]
    self.pendingPayout = self.pendingPayout and self.pendingPayout > 0 and self.pendingPayout or nil
    Private.UI:UpdatePendingPayoutText(self.pendingPayout, self.guid)

    self.bet = 0
    self.payout = 0
    self.newBetDuringPayout = false

    if self.pendingPayout then
        self:handlePendingPayout()
    else
        Private.UI:HideSquares()
    end

    return self
end

function Trade:handlePendingPayout()
    C_Timer.NewTicker(0.1, function(ticker)
        if TradeFrame then
            local gold = math.floor(self.pendingPayout / 10000)
            local silver = math.floor((self.pendingPayout % 10000) / 100)
            local copper = self.pendingPayout % 100

            TradePlayerInputMoneyFrameGold:SetText(gold)
            TradePlayerInputMoneyFrameSilver:SetText(silver)
            TradePlayerInputMoneyFrameCopper:SetText(copper)

            Private.UI:ShowGreenSquare()
            ticker:Cancel()
        end
    end)
end

function Trade:update(event, playerAccepted, targetAccepted)
    local bet = tonumber(GetTargetTradeMoney()) or 0
    local playerMoney = tonumber(GetPlayerTradeMoney()) or 0
    self.payout = playerMoney

    local maxBet = addon:GetDatabaseValue("maxBet") * 10000
    local minBet = addon:GetDatabaseValue("minBet") * 10000
    local tradeAccepted = (event == "TRADE_ACCEPT_UPDATE" and playerAccepted == 1 and targetAccepted == 1)
    local playerAcceptedTrade = (event == "TRADE_ACCEPT_UPDATE" and targetAccepted == 1)

    Private.UI:HideSquares()

    if self.pendingPayout and bet > 0 and tradeAccepted then
        addon:SetDatabaseValue("pendingPayout." .. self.guid, 0)
        self.pendingPayout = nil
        self.newBetDuringPayout = true
    end

    if bet > maxBet and playerAcceptedTrade then
        Private.UI:ShowRedSquare()
        msg:SendMessage("OVER_MAX_BET", "WHISPER",
            { C_CurrencyInfo.GetCoinText(bet), C_CurrencyInfo.GetCoinText(maxBet) },
            self.name)
        bet = 0
    elseif bet < minBet and bet > 0 and playerAcceptedTrade then
        Private.UI:ShowRedSquare()
        msg:SendMessage("UNDER_MIN_BET", "WHISPER",
            { C_CurrencyInfo.GetCoinText(bet), C_CurrencyInfo.GetCoinText(minBet) },
            self.name)
        bet = 0
    elseif bet > 0 and playerAcceptedTrade then
        Private.UI:ShowGreenSquare()
    end

    self.bet = min(bet, maxBet)

    if self.bet > 0 and (self.newBetDuringPayout or not self.pendingPayout) and tradeAccepted then
        self:save()
        self.newBetDuringPayout = false
    end
end

function Trade:save()
    addon:SetDatabaseValue("activeGame", self)
    msg:SendMessage("BET_ACCEPTED", "WHISPER", { C_CurrencyInfo.GetCoinText(self.bet) }, self.name)
end

function Trade:complete(message)
    if message == ERR_TRADE_COMPLETE then
        if self.pendingPayout and not self.newBetDuringPayout then
            local remainingPayout = max(0, self.pendingPayout - self.payout)
            addon:SetDatabaseValue("pendingPayout." .. self.guid, remainingPayout)

            if remainingPayout == 0 then
                addon:SetDatabaseValue("loyaltyAmount." .. self.guid, 0)
            end
        end

        if self.bet > 0 and addon:GetDatabaseValue("loyalty") then
            local loyaltyPercent = addon:GetDatabaseValue("loyaltyPercent")
            local loyaltyBonus = math.floor((self.bet * loyaltyPercent) / 100)
            local loyaltyValues = addon:GetDatabaseValue("loyaltyAmount")
            local previousLoyalty = loyaltyValues[self.guid] or 0

            addon:SetDatabaseValue("loyaltyAmount." .. self.guid, previousLoyalty + loyaltyBonus)
        end

        self.bet = 0
        self.pendingPayout = nil
        self.payout = 0
        self.newBetDuringPayout = false
    end
end

---@class TradesUtil
local tradesUtil = {}
Private.TradesUtil = tradesUtil

---@return Trade
function tradesUtil:GetTrade()
    return addon:GetDatabaseValue("activeGame")
end

---@param trade Trade
function tradesUtil:SaveTrade(trade)
    addon:SetDatabaseValue("activeGame", trade)
    msg:SendMessage("BET_ACCEPTED", "WHISPER", { C_CurrencyInfo.GetCoinText(trade.bet) }, trade.name)
end

local currentTrade = nil

local function onTradeShow()
    currentTrade = Trade:new()
end

local function onTradeUpdate(event, playerAccepted, targetAccepted)
    if currentTrade then
        currentTrade:update(event, playerAccepted, targetAccepted)
    end
end

local function onCompleteTrade(_, _, _, message)
    if currentTrade then
        currentTrade:complete(message)
        currentTrade = nil
    end
end

addon:RegisterEvent("TRADE_SHOW", onTradeShow)
addon:RegisterEvent("TRADE_MONEY_CHANGED", onTradeUpdate)
addon:RegisterEvent("TRADE_ACCEPT_UPDATE", onTradeUpdate)
addon:RegisterEvent("UI_INFO_MESSAGE", onCompleteTrade)
