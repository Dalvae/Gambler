local ADDON_NAME = ...
---@cast ADDON_NAME string

---@class AddonPrivate
local Private = select(2, ...)

local constants = {}

Private.constants = constants

constants.ADDON_NAME = ADDON_NAME
constants.ADDON_VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
constants.ADDON_MEDIA_PATH = [[Interface\AddOns\]] .. constants.ADDON_NAME .. [[\Media]]

constants.PLAYER_NAME = UnitName("player")
constants.ROLL_MESSAGE_MATCH = RANDOM_ROLL_RESULT:format(constants.PLAYER_NAME, 0, 1, 6):gsub(0, "%%d"):gsub("%-", "%%p")
    :gsub("%(", "%%p"):gsub("%)", "%%p")
constants.CHOICES = {
    ["UNDER"] = true,
    ["OVER"] = true,
    ["7"] = true
}
constants.MESSAGE_TYPES = {
    ["BET_ACCEPTED"] = "Your Bet of %s was received! Type 'under', '7' or 'over' to pick your choice.",
    ["CHOICE_PENDING"] = "Your Choice is still missing %s! Type 'under', '7' or 'over' to pick your choice.",
    ["CHOICE_PICKED"] = "Your Choice '%s' was saved! Rolling the Dice... Good Luck!",
    ["GAME_OUTCOME"] = "The Dice rolled %d! That's a %s for you.",
    ["WON_PAYOUT"] = "You just won %s! Open trade to receive winnings!",
    ["UNDER_MIN_BET"] = "You're trying to bet %s which is under the minimum Bet that is currently: %s!",
    ["OVER_MAX_BET"] = "You're about to bet %s even though the max allowed Bet is currently: %s!",
    ["PENDING_PAYOUT"] = "I owe you %s. Trade me anytime and I'll give it back to you.",
    ["BUSY_WITH_GAME"] = "I'm sorry, I'm in another gamble. Can you wait a second please?",
    ["RULES1"] = "Welcome, %s!, Casino Rules (Guess the dice total):",
    ["RULES2"] = "Over 7 / Under 7: Win x2",
    ["RULES3"] = "Exactly 7: Win x4",
    ["RULES4"] = "Bet Limits: %s - %s",
    ["RULES5"] = "Open Trade when ready. Good Luck",
    ["PERSONAL_STATS"] = "Your Stats: %dW, %dL, +%s, -%s",
    ["NUM_ENTRY"] = "%d. %s",
    ["NO_FORMAT"] = "%s",
    ["LOYALTY_MIN_BET_NOT_MET"] = "The current minimun for a loyalty bonus is %s, bet more if you want a loyalty bonus",

}

constants.COLORS = {
    POSITIVE = CreateColorFromHexString("FF2ecc71"),
    NEUTRAL = CreateColorFromHexString("FFf1c40f"),
    NEGATIVE = CreateColorFromHexString("FFe74c3c"),
    WHITE = CreateColorFromHexString("FFecf0f1"),
    GREY = CreateColorFromHexString("FFbdc3c7"),
}
constants.MEDIA = {
    FONTS = {
        DEFAULT = constants.ADDON_MEDIA_PATH .. [[\Fonts\Default\NotoSans-Bold.ttf]],
    },
    TEXTURES = {
        LOGO = constants.ADDON_MEDIA_PATH .. [[\Textures\logo.tga]]
    }
}

constants.FONT_OBJECTS = {
    NORMAL = constants.ADDON_NAME .. 'Normal',
    HEADING = constants.ADDON_NAME .. 'Heading'
}

do
    local font = CreateFont(constants.FONT_OBJECTS.NORMAL)
    font:SetFont(constants.MEDIA.FONTS.DEFAULT, 12, "OUTLINE")
    font:SetJustifyH("LEFT")
    font:SetJustifyV("MIDDLE")
    font:SetTextColor(constants.COLORS.WHITE:GetRGBA())
end
do
    local font = CreateFont(constants.FONT_OBJECTS.HEADING)
    font:SetFont(constants.MEDIA.FONTS.DEFAULT, 16, "OUTLINE")
    font:SetJustifyH("LEFT")
    font:SetJustifyV("MIDDLE")
    font:SetTextColor(constants.COLORS.WHITE:GetRGBA())
end
