---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon

---@class GambleUI
local ui = {}

Private.UI = ui

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
        mainFrame.TitleContainer:SetFrameStrata("HIGH")
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

    mainFrame.tabs = {}
    mainFrame.numTabs = 0
    mainFrame.selectedTab = 0

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
    loyaltyPercent:SetText(addon:GetDatabaseValue("loyaltyPercent") or "5")
    loyaltyPercent.Instructions:SetText("Enter VIP %")
    loyaltyPercent:HookScript("OnTextChanged", loyaltyUpdate)


    local jackpotEnabled = ui:CreateCheckbox(mainFrame,
        { { "TOPLEFT", loyaltyPercent, "BOTTOMLEFT", -10, -2.5 } },
        "Enable Jackpot", "Enable the Jackpot feature for consecutive wins.",
        "jackpotEnabled")

    local function CreateJackpotCheckbox(parent, point, text, databaseKey)
        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(80, 24)
        local checkbox = CreateFrame("CheckButton", nil, container, "ChatConfigCheckButtonTemplate")
        checkbox:SetSize(24, 24)
        checkbox:SetPoint("LEFT", container, "LEFT", 0, 0)
        checkbox:SetHitRectInsets(0, -24, 0, 0)

        checkbox.Text:SetText(text)
        checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)

        checkbox.tooltip = "Enable " .. text .. " Jackpot"
        checkbox:SetChecked(addon:GetDatabaseValue(databaseKey))
        checkbox:HookScript("OnClick", function(self)
            addon:SetDatabaseValue(databaseKey, self:GetChecked())
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

        container:SetPoint(unpack(point))

        container:EnableMouse(false)

        return checkbox
    end

    local function CreateJackpotInput(parent, point, defaultValue, databaseKey)
        local input = CreateFrame("EditBox", nil, parent, "InputBoxInstructionsTemplate")
        input:SetSize(40, 20)
        input:SetPoint(unpack(point))
        input:SetNumeric(true)
        input:SetText(addon:GetDatabaseValue(databaseKey) or defaultValue)
        input:SetAutoFocus(false)
        input:SetScript("OnTextChanged", function(self)
            local value = tonumber(self:GetText()) or defaultValue
            addon:SetDatabaseValue(databaseKey, value)
        end)
        input.Instructions:ClearAllPoints()
        input.Instructions:SetPoint("RIGHT", input, "RIGHT", -5, 0)
        input.Instructions:SetText("%")
        return input
    end

    local jackpotx3Checkbox = CreateJackpotCheckbox(mainFrame, { "TOPLEFT", jackpotEnabled, "BOTTOMLEFT", 20, -5 }, "3x",
        "jackpotx3Enabled")
    local jackpotx3Input = CreateJackpotInput(mainFrame, { "LEFT", jackpotx3Checkbox, "RIGHT", 25, 0 }, "25",
        "jackpotx3Percent")

    local jackpotx5Checkbox = CreateJackpotCheckbox(mainFrame, { "TOPLEFT", jackpotx3Checkbox, "BOTTOMLEFT", 0, -5 },
        "5x", "jackpotx5Enabled")
    local jackpotx5Input = CreateJackpotInput(mainFrame, { "LEFT", jackpotx5Checkbox, "RIGHT", 25, 0 }, "250",
        "jackpotx5Percent")

    local jackpotx7Checkbox = CreateJackpotCheckbox(mainFrame, { "TOPLEFT", jackpotx5Checkbox, "BOTTOMLEFT", 0, -5 },
        "7x", "jackpotx7Enabled")
    local jackpotx7Input = CreateJackpotInput(mainFrame, { "LEFT", jackpotx7Checkbox, "RIGHT", 25, 0 }, "500",
        "jackpotx7Percent")

    local function ToggleJackpotInputs(show)
        jackpotx3Checkbox:SetShown(show)
        jackpotx3Input:SetShown(show)
        jackpotx5Checkbox:SetShown(show)
        jackpotx5Input:SetShown(show)
        jackpotx7Checkbox:SetShown(show)
        jackpotx7Input:SetShown(show)
    end

    jackpotEnabled:HookScript("OnClick", function(self)
        ToggleJackpotInputs(self:GetChecked())
    end)

    local function ToggleInputEnabled(checkbox, input)
        checkbox:HookScript("OnClick", function(self)
            input:SetEnabled(self:GetChecked())
        end)
    end

    ToggleInputEnabled(jackpotx3Checkbox, jackpotx3Input)
    ToggleInputEnabled(jackpotx5Checkbox, jackpotx5Input)
    ToggleInputEnabled(jackpotx7Checkbox, jackpotx7Input)

    -- Inicializar el estado de los inputs
    ToggleJackpotInputs(addon:GetDatabaseValue("jackpotEnabled"))
    jackpotx3Input:SetEnabled(addon:GetDatabaseValue("jackpotx3Enabled"))
    jackpotx5Input:SetEnabled(addon:GetDatabaseValue("jackpotx5Enabled"))
    jackpotx7Input:SetEnabled(addon:GetDatabaseValue("jackpotx7Enabled"))

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
        TradeFrame.GreenSquare:SetColorTexture(0, 1, 0, 1)
        TradeFrame.GreenSquare:Hide()
    end

    if not TradeFrame.RedSquare then
        TradeFrame.RedSquare = TradeFrame:CreateTexture(nil, "OVERLAY")
        TradeFrame.RedSquare:SetSize(20, 20)
        TradeFrame.RedSquare:SetPoint("LEFT", TradeFrame, "RIGHT", 5, 0)
        TradeFrame.RedSquare:SetColorTexture(1, 0, 0, 1)
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

    local activeGames = {}
    local tabButtons = {}
    local currentTabIndex = 1

    function ui:SelectTab(index)
        if mainFrame.selectedTab > 0 then
            PanelTemplates_DeselectTab(mainFrame.tabs[mainFrame.selectedTab])
        end
        PanelTemplates_SelectTab(mainFrame.tabs[index])
        mainFrame.selectedTab = index
        ui:UpdateGameDisplay(index)
    end

    local function CreateTab(parent, index)
        local tab = CreateFrame("Button", nil, parent, "TabButtonTemplate")
        tab:SetID(index)
        tab:SetText(tostring(index))

        tab:SetFrameStrata("LOW")
        tab:SetScript("OnClick", function(self)
            ui:SelectTab(self:GetID())
        end)
        return tab
    end

    local function UpdateTabs(numGames)
        local tabWidth = 50
        local spacing = 2

        for i = 1, numGames do
            if not mainFrame.tabs[i] then
                mainFrame.tabs[i] = CreateTab(mainFrame, i)
            end
            mainFrame.tabs[i]:Show()

            if i == 1 then
                mainFrame.tabs[i]:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 5, 30)
            else
                mainFrame.tabs[i]:SetPoint("TOPLEFT", mainFrame.tabs[i - 1], "TOPRIGHT", spacing, 0)
            end
        end

        for i = numGames + 1, #mainFrame.tabs do
            mainFrame.tabs[i]:Hide()
        end

        mainFrame.numTabs = numGames

        if mainFrame.selectedTab > numGames then
            mainFrame.selectedTab = numGames
        end

        if mainFrame.selectedTab == 0 and numGames > 0 then
            mainFrame.selectedTab = 1
        end

        if mainFrame.selectedTab > 0 then
            ui:SelectTab(mainFrame.selectedTab)
        end

        local totalWidth = (tabWidth + spacing) * numGames - spacing + 10
        if totalWidth > mainFrame:GetWidth() then
            mainFrame:SetWidth(totalWidth)
        end
    end
    function ui:UpdateGameState(games)
        activeGames = games

        local priorityIndex = 1
        local hasActiveGame = false
        for i, game in ipairs(activeGames) do
            if not game.outcome then
                hasActiveGame = true
                if game.choice then
                    priorityIndex = i
                    break
                else
                    priorityIndex = i
                end
            end
        end

        UpdateTabs(#activeGames)

        if hasActiveGame then
            ui:SelectTab(priorityIndex)
        else
            currentGame:SetText("Current Game (No Game)")
            gamePlayer:SetText("Player: No game")
            gameBet:SetText("Bet: ???")

            local r, g, b, a = 0, 0, 0, 1
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
    end

    function ui:UpdateGameDisplay(index)
        local gameInfo = activeGames[index]
        local r, g, b, a = 0, 0, 0, 1

        if gameInfo then
            currentGame:SetText(string.format("Current Game ('%s'):", gameInfo.outcome or "ACTIVE"))
            gamePlayer:SetText(string.format("Player: %s", gameInfo.name))
            gameBet:SetText(string.format("Bet: %s", C_CurrencyInfo.GetCoinText(gameInfo.bet)))

            local needsRoll = gameInfo.choice and not gameInfo.outcome and #(gameInfo.rolls or {}) < 2

            if needsRoll then
                r, g, b = 0.8, 0, 0.8
            elseif not gameInfo.outcome then
                r, g, b = 1, 1, 1
            end
        else
            currentGame:SetText("Current Game (No Game)")
            gamePlayer:SetText("Player: No game")
            gameBet:SetText("Bet: ???")
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
