---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon

---@class GambleUI
local ui = {}

Private.UI = ui

local startMoveParent
local stopMoveParent


if addon:GetGameVersion() == "Retail" then
    function startMoveParent(self)
        self:GetParent():StartMoving()
    end

    function stopMoveParent(self)
        self:GetParent():StopMovingOrSizing()
        addon:SetDatabaseValue("framePosition", { self:GetParent():GetPoint() })
    end
else
    function startMoveParent(self)
        self:GetParent():GetParent():StartMoving()
    end

    function stopMoveParent(self)
        self:GetParent():GetParent():StopMovingOrSizing()
        addon:SetDatabaseValue("framePosition", { self:GetParent():GetParent():GetPoint() })
    end
end

local function maxBetUpdate(self)
    addon:SetDatabaseValue("maxBet", tonumber(self:GetText()) or 0)
end

local function minBetUpdate(self)
    addon:SetDatabaseValue("minBet", tonumber(self:GetText()) or 0)
end

local function loyaltyUpdate(self)
    addon:SetDatabaseValue("loyaltyPercent", tonumber(self:GetText()) or 0)
end


function ui:CreateCheckbox(parent, points, text, tooltip, databasePath)
    local checkbox = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
    for _, point in ipairs(points) do
        checkbox:SetPoint(unpack(point))
    end
    checkbox:SetSize(30, 30)
    checkbox.Text:SetText(text)
    checkbox.tooltip = tooltip
    checkbox:SetChecked(addon:GetDatabaseValue(databasePath))
    checkbox:HookScript("OnClick", function()
        addon:SetDatabaseValue(databasePath, checkbox:GetChecked())
    end)
    checkbox:SetNormalAtlas("checkbox-minimal")
    checkbox:SetPushedAtlas("checkbox-minimal")
    do
        local tex = checkbox:CreateTexture()
        tex:SetAtlas("checkmark-minimal")
        checkbox:SetCheckedTexture(tex)
    end
    do
        local tex = checkbox:CreateTexture()
        tex:SetAtlas("checkmark-minimal-disabled")
        checkbox:SetDisabledCheckedTexture(tex)
    end

    return checkbox
end

function ui:LoadUI()
    local mainFrame, rollBtn, resetOwed

    if addon:GetGameVersion() == "Retail" then
        mainFrame = CreateFrame("Frame", "gambler", UIParent, "PortraitFrameFlatTemplate")
        mainFrame:SetTitle(const.ADDON_NAME)
        ButtonFrameTemplate_HidePortrait(mainFrame)
        mainFrame.TitleContainer:SetFrameStrata("LOW")
        mainFrame.CloseButton:SetFrameStrata("MEDIUM")

        rollBtn = CreateFrame("Button", "GambleAddonRollButton", mainFrame,
            "SharedButtonTemplate, SecureActionButtonTemplate")
        resetOwed = CreateFrame("Button", nil, TradeFrame, "SharedButtonTemplate")
    else
        mainFrame = CreateFrame("Frame", "gambler", UIParent, "SettingsFrameTemplate")
        mainFrame.NineSlice.Text:SetText(const.ADDON_NAME)

        rollBtn = CreateFrame("Button", "GambleAddonRollButton", mainFrame,
            "UIPanelButtonTemplate, SecureActionButtonTemplate")
        resetOwed = CreateFrame("Button", nil, TradeFrame, "UIPanelButtonTemplate")
    end

    mainFrame:SetMovable(false)
    mainFrame:EnableMouse(false)
    mainFrame:SetSize(250, 160)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 400, 20)
    mainFrame:SetFrameStrata("BACKGROUND")

    local function ResetTitleColor()
        local r, g, b, a = 1, 1, 1, 1 -- Color blanco, puedes ajustarlo si el color original es diferente
        if addon:GetGameVersion() == "Retail" then
            if mainFrame.TitleContainer then
                mainFrame.TitleContainer:SetBackdropColor(r, g, b, a)
                if mainFrame.TitleContainer.TitleText then
                    mainFrame.TitleContainer.TitleText:SetTextColor(r, g, b, 1)
                end
            end
        else
            if mainFrame.NineSlice then
                if mainFrame.NineSlice.Text then
                    mainFrame.NineSlice.Text:SetTextColor(r, g, b, 1)
                end
                if mainFrame.NineSlice.TitleBg then
                    mainFrame.NineSlice.TitleBg:SetColorTexture(r, g, b, a)
                end
            end
        end
    end
    rollBtn:SetText("Roll Dice")
    rollBtn:SetSize(100, 40)
    rollBtn:SetPoint("BOTTOM", mainFrame.Bg, "BOTTOM", 0, 10)
    rollBtn:SetAttribute("type", "toy")
    rollBtn:SetAttribute("toy", 36862)
    rollBtn:RegisterForClicks("AnyUp", "AnyDown")

    local whisperLose = ui:CreateCheckbox(mainFrame,
        { { "TOPLEFT", mainFrame.NineSlice.TopRightCorner, "TOPRIGHT", 0, 0 } },
        "Whisper on Lose", "Activates / Deactivates Whispering on Lose.", "whisperLose")

    local allowStats = ui:CreateCheckbox(mainFrame,
        { { "TOPLEFT", whisperLose, "BOTTOMLEFT", 0, -2.5 } },
        "Allow !stats", "Check to Allow people seeing their own Stats.", "allowStats")

    local sayPopups = ui:CreateCheckbox(mainFrame,
        { { "TOPLEFT", allowStats, "BOTTOMLEFT", 0, -2.5 } },
        "Enable Say Popups", "Get Popups to repeat messages in /say.", "sayPopups")

    local loyalty = ui:CreateCheckbox(mainFrame,
        { { "TOPLEFT", sayPopups, "BOTTOMLEFT", 0, -2.5 } },
        "Enable VIP Program", "Players get a percent of their wagered gold back when requesting with !payout",
        "loyalty")

    local loyaltyInvite = ui:CreateCheckbox(mainFrame,
        { { "TOPLEFT", loyalty, "BOTTOMLEFT", 0, -2.5 } },
        "Invite VIP Only", "Only Enable VIP for selected Players (/gambe vip [add/remove/list] <playername>).",
        "loyaltyClosed")

    local loyaltyPercent = CreateFrame("EditBox", nil, mainFrame, "InputBoxInstructionsTemplate")
    loyaltyPercent:SetSize(150, 20)
    loyaltyPercent:SetPoint("TOPLEFT", loyaltyInvite, "BOTTOMLEFT", 10, -2.5)
    loyaltyPercent:ClearFocus()
    loyaltyPercent:SetAutoFocus(false)
    loyaltyPercent:SetNumeric(true)
    loyaltyPercent:SetText(addon:GetDatabaseValue("loyaltyPercent") or "")
    loyaltyPercent.Instructions:SetText("Enter VIP %")
    loyaltyPercent:HookScript("OnTextChanged", loyaltyUpdate)

    local minBet = CreateFrame("EditBox", nil, mainFrame, "InputBoxInstructionsTemplate")
    minBet:SetHeight(20)
    minBet:SetPoint("TOPLEFT", mainFrame.Bg, "TOPLEFT", 20, -10)
    minBet:SetPoint("TOPRIGHT", mainFrame.Bg, "TOP", -10, -10)
    minBet:ClearFocus()
    minBet:SetAutoFocus(false)
    minBet:SetNumeric(true)
    minBet:SetText(addon:GetDatabaseValue("minBet") or "")
    minBet.Instructions:SetText("Enter Min. Bet")
    minBet:HookScript("OnTextChanged", minBetUpdate)

    local maxBet = CreateFrame("EditBox", nil, mainFrame, "InputBoxInstructionsTemplate")
    maxBet:SetHeight(20)
    maxBet:SetPoint("TOPLEFT", mainFrame.Bg, "TOP", 10, -10)
    maxBet:SetPoint("TOPRIGHT", mainFrame.Bg, "TOPRIGHT", -20, -10)
    maxBet:ClearFocus()
    maxBet:SetAutoFocus(false)
    maxBet:SetNumeric(true)
    maxBet:SetText(addon:GetDatabaseValue("maxBet") or "")
    maxBet.Instructions:SetText("Enter Max. Bet")
    maxBet:HookScript("OnTextChanged", maxBetUpdate)

    local currentGame = mainFrame:CreateFontString()
    currentGame:SetFontObject(const.FONT_OBJECTS.NORMAL)
    currentGame:SetPoint("TOPLEFT", minBet, "BOTTOMLEFT", 0, -5)
    currentGame:SetText("Current Game (???):")

    local gamePlayer = mainFrame:CreateFontString()
    gamePlayer:SetFontObject(const.FONT_OBJECTS.NORMAL)
    gamePlayer:SetPoint("TOPLEFT", currentGame, "BOTTOMLEFT", 0, -5)
    gamePlayer:SetText("Player: ???")

    local gameBet = mainFrame:CreateFontString()
    gameBet:SetFontObject(const.FONT_OBJECTS.NORMAL)
    gameBet:SetPoint("TOPLEFT", gamePlayer, "BOTTOMLEFT", 0, -5)
    gameBet:SetText("Bet: ???")

    local owedMoney = TradeFrame:CreateFontString()
    owedMoney:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT")
    owedMoney:SetFontObject(const.FONT_OBJECTS.HEADING)

    resetOwed:SetPoint("TOPLEFT", owedMoney, "BOTTOMLEFT")
    resetOwed:SetSize(100, 20)
    resetOwed:SetText("Reset Pending")
    resetOwed:SetScript("OnClick", function()
        if resetOwed.guid then
            addon:SetDatabaseValue("pendingPayout." .. resetOwed.guid, 0)
            owedMoney:SetText("")
            resetOwed:Hide()
            resetOwed:Disable()
        end
    end)

    if not TradeFrame.GreenSquare then
        TradeFrame.GreenSquare = TradeFrame:CreateTexture(nil, "OVERLAY")
        TradeFrame.GreenSquare:SetSize(20, 20)
        TradeFrame.GreenSquare:SetPoint("LEFT", TradeFrame, "RIGHT", 5, 0)
        TradeFrame.GreenSquare:SetColorTexture(0, 1, 0, 0.8)
        TradeFrame.GreenSquare:Hide()
    end

    if not TradeFrame.RedSquare then
        TradeFrame.RedSquare = TradeFrame:CreateTexture(nil, "OVERLAY")
        TradeFrame.RedSquare:SetSize(20, 20)
        TradeFrame.RedSquare:SetPoint("LEFT", TradeFrame, "RIGHT", 5, 0)
        TradeFrame.RedSquare:SetColorTexture(1, 0, 0, 0.8)
        TradeFrame.RedSquare:Hide()
    end

    function ui:HideSquares()
        if TradeFrame then
            if TradeFrame.GreenSquare then
                TradeFrame.GreenSquare:Hide()
            end
            if TradeFrame.RedSquare then
                TradeFrame.RedSquare:Hide()
            end
        end
    end

    function ui:UpdatePendingPayoutText(amount, guid)
        local text = ""
        resetOwed:Hide()
        resetOwed:Disable()
        resetOwed.guid = nil
        if amount and amount > 0 then
            text = "Pending Payout:\n" .. C_CurrencyInfo.GetCoinText(amount)
            resetOwed.guid = guid
            resetOwed:Enable()
            resetOwed:Show()
        end
        owedMoney:SetText(text)
    end

    function ui:ShowGreenSquare()
        if TradeFrame and TradeFrame.GreenSquare then
            TradeFrame.GreenSquare:Show()
            if TradeFrame.RedSquare then
                TradeFrame.RedSquare:Hide()
            end
        end
    end

    function ui:ShowRedSquare()
        if TradeFrame and TradeFrame.RedSquare then
            TradeFrame.RedSquare:Show()
            if TradeFrame.GreenSquare then
                TradeFrame.GreenSquare:Hide()
            end
        end
    end

    function ui:HideTradeIndicators()
        if TradeFrame then
            if TradeFrame.GreenSquare then
                TradeFrame.GreenSquare:Hide()
            end
            if TradeFrame.RedSquare then
                TradeFrame.RedSquare:Hide()
            end
        end
    end

    function ui:UpdateGameState(gameInfo)
        local stage = gameInfo.outcome or gameInfo.choice or "Started"
        currentGame:SetText(string.format("Current Game ('%s'):", gameInfo.outcome or "ACTIVE"))
        gamePlayer:SetText(string.format("Player: %s", gameInfo.name))
        gameBet:SetText(string.format("Bet: %s", C_CurrencyInfo.GetCoinText(gameInfo.bet)))

        local isActive = not gameInfo.outcome
        local hasChoice = gameInfo.choice and not gameInfo.outcome
        local r, g, b, a = 1, 1, 1, 1 -- Default color (white)

        if isActive then
            if hasChoice then
                r, g, b = 0.8, 0, 0.8 -- Purple color when a choice is selected and the game is active
            else
                r, g, b = 1, 1, 1     -- White color when the game is active but no choice is selected
            end
        else
            r, g, b = 0, 0, 0
        end

        if addon:GetGameVersion() == "Retail" then
            if mainFrame.TitleContainer then
                mainFrame.TitleContainer:SetBackdropColor(r, g, b, a)
                if mainFrame.TitleContainer.TitleText then
                    mainFrame.TitleContainer.TitleText:SetTextColor(r, g, b, 1)
                end
            end
        else
            if mainFrame.NineSlice then
                if mainFrame.NineSlice.Text then
                    mainFrame.NineSlice.Text:SetTextColor(r, g, b, 1)
                end
                if mainFrame.NineSlice.TitleBg then
                    mainFrame.NineSlice.TitleBg:SetColorTexture(r, g, b, a)
                end
            end
        end
    end

    ---@param forceState boolean|?
    function ui:ToggleVisibility(forceState)
        mainFrame:SetShown(forceState ~= nil and forceState or not mainFrame:IsVisible())
    end
end
