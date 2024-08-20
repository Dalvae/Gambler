---@class AddonPrivate
local Private = select(2, ...)
local const = Private.constants
local addon = Private.Addon

---@class StatsUtil
local statsUtil = {
    ---@class GambleHistory
    ---@field DB table
    ---@field indexedDB table
    ---@field lastUpdate number
    historyCache = {
        DB = {},
        indexedDB = {},
        lastUpdate = 0
    }
}
Private.StatsUtil = statsUtil

function statsUtil:IndexDB(db)
    local indexed = {}
    for timeKey, info in pairs(db) do
        local copied = addon:CopyTable(info)
        copied.timeKey = timeKey
        tinsert(indexed, copied)
    end
    sort(indexed, function(a, b)
        return tonumber(a.timeKey) > tonumber(b.timeKey)
    end)
    return indexed
end

function statsUtil:GetHistory()
    local now = GetTime()

    local history = addon:GetDatabaseValue("completeGames")
    self.historyCache = {
        DB = history,
        lastUpdate = now,
        indexedDB = self:IndexDB(history)
    }

    return self.historyCache
end

---@param secondsBack number
---@return table
function statsUtil:GetHistoryTime(secondsBack)
    local timedHistory = {}
    local now = time()
    local history = self:GetHistory()
    for _, game in ipairs(history.indexedDB) do
        if game.time >= now - secondsBack then
            tinsert(timedHistory, game)
        end
    end
    return timedHistory
end

function statsUtil:GetHistoryGames(gameCount)
    local games = {}
    local history = self:GetHistory()
    if history and history.indexedDB then
        for i = 1, math.min(gameCount, #history.indexedDB) do
            table.insert(games, history.indexedDB[i])
        end
    end
    return games
end

function statsUtil:GetDayTops()
    local history = self:GetHistoryTime(86400)
    local players = {}
    local stats = {}
    for _, game in ipairs(history) do
        if not players[game.guid] then
            tinsert(stats, {
                playerName = game.name,
                playerGUID = game.guid,
                stats = self:GetPlayerStats(game.guid, history)
            })
            players[game.guid] = true
        end
    end

    sort(stats, function(a, b)
        return a.won > b.won
    end)
    return stats
end

---@param playerGUID string
---@return PlayerStats
function statsUtil:GetPlayerStats(playerGUID, history)
    if not history then history = self:GetHistory() end

    ---@class PlayerStats
    ---@field wins number
    ---@field loses number
    ---@field paid number
    ---@field won number
    local playerStats = {
        wins = 0,
        loses = 0,
        paid = 0,
        won = 0,
    }
    for _, game in pairs(history.DB or history) do
        ---@cast game GameInfo
        if game.guid == playerGUID then
            playerStats.paid = playerStats.paid + game.bet
            if game.outcome == "WIN" then
                playerStats.wins = playerStats.wins + 1
                playerStats.won = playerStats.won + game.payout
            else
                playerStats.loses = playerStats.loses + 1
            end
        end
    end
    return playerStats
end

---@param playerName string
---@param history table|?
---@return string|?
function statsUtil:LookupGUID(playerName, history)
    if not playerName then return end
    if not history then history = self:GetHistory() end
    for _, game in pairs(history.DB or history) do
        ---@cast game GameInfo
        if game.name:lower() == playerName:lower() then
            return game.guid
        end
    end
end

---@param playerGUID string
---@param history table|?
---@return string|?
function statsUtil:LookupName(playerGUID, history)
    if not playerGUID then return end
    if not history then history = self:GetHistory() end
    for _, game in pairs(history.DB or history) do
        ---@cast game GameInfo
        if game.guid:lower() == playerGUID:lower() then
            return game.name
        end
    end
end
