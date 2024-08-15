---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon
local msg = Private.MessageUtil


---@class TradesUtil
local tradesUtil = {}
Private.TradesUtil = tradesUtil

---@return TradeInfo
function tradesUtil:GetTrade()
    return addon:GetDatabaseValue("activeGame")
end

---@param tradeInfo TradeInfo
function tradesUtil:SaveTrade(tradeInfo)
    addon:SetDatabaseValue("activeGame", tradeInfo)
    msg:SendMessage("BET_ACCEPTED", "WHISPER", { C_CurrencyInfo.GetCoinText(tradeInfo.bet) }, tradeInfo.name)
end

---@class TradeInfo
---@field guid string
---@field name string
---@field bet number
---@field payout number
---@field pendingPayout number
local tempTrade = {}
local betSaved = false
local function newTrade()
    local unitGUID = UnitGUID("npc")
    local unitName, unitRealm = GetUnitName("npc", true)
    if unitRealm then
        unitName = string.format("%s-%s", unitName, unitRealm)
    end
    local pendingPayouts = addon:GetDatabaseValue("pendingPayout")
    local pendingPayout = pendingPayouts[unitGUID]
    pendingPayout = pendingPayout and pendingPayout > 0 and pendingPayout or nil
    Private.UI:UpdatePendingPayoutText(pendingPayout, unitGUID)

    betSaved = false

    if pendingPayout then
        C_Timer.NewTicker(.1, function(self)
            if TradeFrame then
                local gold = math.floor(pendingPayout / 10000)
                local silver = math.floor((pendingPayout % 10000) / 100)
                local copper = pendingPayout % 100

                TradePlayerInputMoneyFrameGold:SetText(gold)
                TradePlayerInputMoneyFrameSilver:SetText(silver)
                TradePlayerInputMoneyFrameCopper:SetText(copper)

                Private.UI:ShowGreenSquare()
                self:Cancel()
            end
        end)
    else
        Private.UI:HideSquares()
    end
    tempTrade = {
        guid = unitGUID or "",
        name = unitName,
        bet = 0,
        pendingPayout = pendingPayout,
        payout = 0,
        consecutiveWins = 0,
        lastBetAmount = 0,
        newBetDuringPayout = false
    }
    return unitName
end

local function updateTrade(_, event, playerAccepted, targetAccepted)
    local bet = tonumber(GetTargetTradeMoney()) or 0
    local playerMoney = tonumber(GetPlayerTradeMoney()) or 0
    tempTrade.payout = playerMoney

    local maxBet = addon:GetDatabaseValue("maxBet") * 10000
    local minBet = addon:GetDatabaseValue("minBet") * 10000
    local tradeAccepted = (event == "TRADE_ACCEPT_UPDATE" and playerAccepted == 1 and targetAccepted == 1)
    local playerAcceptedTrade = (event == "TRADE_ACCEPT_UPDATE" and targetAccepted == 1)

    Private.UI:HideSquares()

    local loyaltyAdded = false

    if tempTrade.pendingPayout and playerMoney > 0 and tradeAccepted then
        -- Lógica para manejar el pago de ganancias anteriores
        local remainingPayout = max(0, tempTrade.pendingPayout - playerMoney)
        addon:SetDatabaseValue("pendingPayout." .. tempTrade.guid, remainingPayout)

        if remainingPayout == 0 then
            addon:SetDatabaseValue("loyaltyAmount." .. tempTrade.guid, 0)
        end

        tempTrade.pendingPayout = remainingPayout
        tempTrade.newBetDuringPayout = (bet > 0)

        -- Añadir puntos de lealtad por el pago
        if addon:GetDatabaseValue("loyalty") and not loyaltyAdded then
            local loyaltyPercent = addon:GetDatabaseValue("loyaltyPercent")
            local loyaltyBonus = math.floor((playerMoney * loyaltyPercent) / 100)
            local loyaltyValues = addon:GetDatabaseValue("loyaltyAmount")
            local previousLoyalty = loyaltyValues[tempTrade.guid] or 0
            addon:SetDatabaseValue("loyaltyAmount." .. tempTrade.guid, previousLoyalty + loyaltyBonus)
            loyaltyAdded = true
        end
    end

    if bet > maxBet and playerAcceptedTrade then
        Private.UI:ShowRedSquare()
        msg:SendMessage("OVER_MAX_BET", "WHISPER",
            { C_CurrencyInfo.GetCoinText(bet), C_CurrencyInfo.GetCoinText(maxBet) },
            tempTrade.name)
        bet = 0
    elseif bet < minBet and bet > 0 and playerAcceptedTrade then
        Private.UI:ShowRedSquare()
        msg:SendMessage("UNDER_MIN_BET", "WHISPER",
            { C_CurrencyInfo.GetCoinText(bet), C_CurrencyInfo.GetCoinText(minBet) },
            tempTrade.name)
        bet = 0
    elseif bet > 0 and playerAcceptedTrade then
        Private.UI:ShowGreenSquare()
    end

    tempTrade.bet = min(bet, maxBet)

    if tempTrade.bet > 0 and not betSaved and tradeAccepted then
        -- Añadir puntos de lealtad por la nueva apuesta
        if addon:GetDatabaseValue("loyalty") and not loyaltyAdded then
            local loyaltyPercent = addon:GetDatabaseValue("loyaltyPercent")
            local loyaltyBonus = math.floor((tempTrade.bet * loyaltyPercent) / 100)
            local loyaltyValues = addon:GetDatabaseValue("loyaltyAmount")
            local previousLoyalty = loyaltyValues[tempTrade.guid] or 0
            addon:SetDatabaseValue("loyaltyAmount." .. tempTrade.guid, previousLoyalty + loyaltyBonus)
        end

        tradesUtil:SaveTrade(tempTrade)
        betSaved = true
    end
end

local function completeTrade(_, _, _, message)
    if message == ERR_TRADE_COMPLETE then
        if tempTrade.pendingPayout and not tempTrade.newBetDuringPayout then
            local remainingPayout = max(0, tempTrade.pendingPayout - tempTrade.payout)
            addon:SetDatabaseValue("pendingPayout." .. tempTrade.guid, remainingPayout)

            if remainingPayout == 0 then
                addon:SetDatabaseValue("loyaltyAmount." .. tempTrade.guid, 0)
            end
        end

        if tempTrade.bet > 0 and addon:GetDatabaseValue("loyalty") then
            local loyaltyPercent = addon:GetDatabaseValue("loyaltyPercent")
            local loyaltyBonus = math.floor((tempTrade.bet * loyaltyPercent) / 100)
            local loyaltyValues = addon:GetDatabaseValue("loyaltyAmount")
            local previousLoyalty = loyaltyValues[tempTrade.guid] or 0

            addon:SetDatabaseValue("loyaltyAmount." .. tempTrade.guid, previousLoyalty + loyaltyBonus)
        end

        tempTrade = {
            guid = tempTrade.guid,
            name = tempTrade.name,
            bet = 0,
            pendingPayout = nil,
            payout = 0,
            consecutiveWins = 0,
            lastBetAmount = 0,
            newBetDuringPayout = false
        }
        betSaved = false
    end
end
addon:RegisterEvent("TRADE_SHOW", "TradesUtil.lua", newTrade)
addon:RegisterEvent("TRADE_MONEY_CHANGED", "TradesUtil.lua", updateTrade)
addon:RegisterEvent("TRADE_ACCEPT_UPDATE", "TradesUtil.lua", updateTrade)
addon:RegisterEvent("UI_INFO_MESSAGE", "TradesUtil.lua", completeTrade)
