---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon
local statsUtil = Private.StatsUtil

---@class VipUtil
local vipUtil = {}
Private.VipUtil = vipUtil


---@param playerGUID string
---@return boolean|?
function vipUtil:GetPlayerStatus(playerGUID)
    local vipList = self:GetList()
    if not vipList then return false end
    return vipList[playerGUID]
end

---@param playerGUID string
function vipUtil:GetPlayerValue(playerGUID)
    local loyaltyValues = addon:GetDatabaseValue("loyaltyAmount")
    return loyaltyValues[playerGUID] or 0
end

---@param playerGUID string
---@param status boolean|?
function vipUtil:SetPlayerStatus(playerGUID, status)
    addon:SetDatabaseValue("loyaltyList." .. playerGUID, status)
end

---@return table
function vipUtil:GetList()
    local list = addon:GetDatabaseValue("loyaltyList")
    return list
end

function vipUtil:GetLoyaltyList()
    local filteredList = {}
    local loyaltyValues = addon:GetDatabaseValue("loyaltyAmount") or {}
    for playerGUID, amount in pairs(loyaltyValues) do
        if self:CanUseCommands(playerGUID) then
            filteredList[playerGUID] = {
                name = statsUtil:LookupName(playerGUID),
                amount = amount
            }
        end
    end
    return filteredList
end

---@param guid string
function vipUtil:CanUseCommands(guid)
    local isLoyaltyOn = addon:GetDatabaseValue("loyalty")
    local isClosed = addon:GetDatabaseValue("loyaltyClosed")
    local hasLoyalty = self:GetPlayerStatus(guid)
    return (isLoyaltyOn and isClosed and hasLoyalty) or (isLoyaltyOn and not isClosed) or false
end

---@param playerGUID string
---@param value number
function vipUtil:SetPlayerValue(playerGUID, value)
    local loyaltyValues = addon:GetDatabaseValue("loyaltyAmount") or {}
    loyaltyValues[playerGUID] = value
    addon:SetDatabaseValue("loyaltyAmount", loyaltyValues)
end
