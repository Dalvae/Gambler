---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants

local defaultDatabase = {
    activeGame = {},
    completeGames = {},
    pendingPayout = {},
    loyaltyAmount = {},
    loyaltyList = {},
    framePosition = {"RIGHT"},
    minBet = 1000,
    maxBet = 100000,
    whisperLose = true,
    allowStats = true,
    sayPopups = false,
    loyalty = false,
    loyaltyClosed = false,
    loyaltyPercent = 5,
}

---@class GambleAddon : RasuAddonBase
local addon = LibStub("RasuAddon"):CreateAddon(
    const.ADDON_NAME,
    "GambleDB",
    defaultDatabase
)

Private.Addon = addon


function addon:GetGameVersion()
    return C_AddOns.GetAddOnMetadata(const.ADDON_NAME, "X-Flavor")
end