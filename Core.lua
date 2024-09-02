---@class AddonPrivate
local Private = select(2, ...)

local const = Private.constants
local addon = Private.Addon
local timeFormatter = CreateFromMixins(SecondsFormatterMixin)
timeFormatter:Init(1, 3, true, true)

Private.TimeFormatter = timeFormatter

local gameUtil = Private.GameUtil
local statsUtil = Private.StatsUtil
local ui = Private.UI
local vipUtil = Private.VipUtil

function addon:OnInitialize(...)
    -- On Init
end

function addon:OnEnable(...)
    if not self.Database.loyaltyAmount then
        self:SetDatabaseValue("loyaltyAmount", {})
    end
    if not self.Database.pendingPayout then
        self:SetDatabaseValue("pendingPayout", {})
    end
    if not self.Database.loyaltyList then
        self:SetDatabaseValue("loyaltyList", {})
    end
    gameUtil:CreateDBCallback()
    ui:LoadUI()

    if not self.Database.gameCounter then
        self:SetDatabaseValue("gameCounter", 0)
    end

    self:RegisterCommand({ "gamble" }, function(_, args)
        if #args > 0 then
            if args[1] == "stats" then
                local playerGUID = statsUtil:LookupGUID(args[2])
                if not playerGUID then
                    self:FPrint("Couldn't find stats for '%s' in your history.", args[2] or "")
                    return
                end
                local playerStats = statsUtil:GetPlayerStats(playerGUID)
                local wonCurr, lostCurr = C_CurrencyInfo.GetCoinText(playerStats.won),
                    C_CurrencyInfo.GetCoinText(playerStats.paid - playerStats.won)
                self:FPrint("Stats for '%s':\nWins/Loses: %d / %d\nWon/Lost: %s / %s", args[2], playerStats.wins,
                    playerStats.loses, wonCurr, lostCurr)
                return
            elseif args[1] == "vip" then
                if not args[2] then
                    self:FPrint("To Change or Show the VIP List use /gamble [add/remove/list] <playerName>")
                    return
                end
                if args[2] == "add" then
                    if args[3] then
                        local playerGUID = statsUtil:LookupGUID(args[3])
                        if not playerGUID then
                            self:FPrint("Couldn't find '%s' in your history.", args[3] or "")
                            return
                        end
                        vipUtil:SetPlayerStatus(playerGUID, args[3])
                        self:FPrint("Added %s to the VIP List.", args[3])
                    else
                        self:FPrint("You need to specify a player to add the VIP Status.")
                    end
                elseif args[2] == "remove" then
                    if args[3] then
                        local playerGUID = statsUtil:LookupGUID(args[3])
                        if not playerGUID then
                            self:FPrint("Couldn't find '%s' in your history.", args[3] or "")
                            return
                        end
                        vipUtil:SetPlayerStatus(playerGUID, nil)
                        self:FPrint("Removed %s from the VIP List.", args[3])
                    else
                        self:FPrint("You need to specify a player to remove the VIP Status.")
                    end
                elseif args[2] == "list" then
                    local list = vipUtil:GetLoyaltyList()
                    if args[3] then
                        local playerGUID = statsUtil:LookupGUID(args[3])
                        if not playerGUID then
                            self:FPrint("Couldn't find '%s' in your history.", args[3] or "")
                            return
                        end
                        local data = list[playerGUID]
                        if data then
                            self:FPrint("%s has %s Loyalty for payout.", data.name, data.amount)
                        end
                        return
                    end
                    self:FPrint("VIP List:")
                    for _, data in pairs(list) do
                        self:FPrint("%s has %s Loyalty for payout.", data.name, data.amount)
                    end
                end
                return
            elseif args[1] == "test" then
                local targetName = UnitName("target")
                if not targetName then
                    self:FPrint("You need to have a target selected for the test game.")
                    return
                end
                local targetGUID = UnitGUID("target")
                if not targetGUID then
                    self:FPrint("Couldn't find GUID for your target.")
                    return
                end
                local tradeInfo = {
                    guid = targetGUID,
                    name = targetName,
                    bet = 20000 -- 2g in copper
                }
                gameUtil.NewGame(nil, tradeInfo)

                -- Simular la elección del jugador
                local choices = { "UNDER", "OVER", "7" }
                local randomChoice = choices[math.random(#choices)]
                gameUtil.SelectChoice(targetGUID, randomChoice)

                self:FPrint("Test game started for target '%s' with a bet of 2g and choice '%s'.", targetName,
                    randomChoice)
                return
            end
        end

        ui:ToggleVisibility()
    end)
end
