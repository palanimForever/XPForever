local addonName, ns = ...
local L = ns.L
local state = ns.state

-- Number and color formatting plus the text items for the bar text and the info text.

local TEXT_SEPARATOR = "  |cff808080·|r  "

-- WoW normally formats numbers in the client language. If a language is forced for testing
-- (ns.FORCE_LOCALE), numbers are written in that language's format, too.
local NUMBER_FORMATS = {
    enUS = { thousands = ",", decimal = "." },
    deDE = { thousands = ".", decimal = "," },
}
local forcedFormat = ns.FORCE_LOCALE and NUMBER_FORMATS[ns.FORCE_LOCALE]

function ns.FormatNumber(value)
    local rounded = math.floor(value + 0.5)
    if not forcedFormat then
        return BreakUpLargeNumbers(rounded)
    end
    local text, replaced = tostring(rounded), 1
    while replaced > 0 do
        text, replaced = text:gsub("^(-?%d+)(%d%d%d)", "%1" .. forcedFormat.thousands .. "%2")
    end
    return text
end

-- DECIMAL_SEPERATOR (sic) is Blizzard's localized decimal separator, e.g. "," on deDE.
function ns.FormatPercent(value)
    local decimal = forcedFormat and forcedFormat.decimal or DECIMAL_SEPERATOR or "."
    return (string.format("%.1f", value):gsub("%.", decimal))
end

function ns.FormatDuration(seconds)
    local minutes = math.max(1, math.floor(seconds / 60 + 0.5))
    if minutes >= 60 then
        return string.format("%dh %02dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%dm", minutes)
end

-- Mouse icons from Blizzard's new player tutorial for usage hints in tooltips.
local MOUSE_ATLAS = {
    LeftButton = "newplayertutorial-icon-mouse-leftbutton",
    RightButton = "newplayertutorial-icon-mouse-rightbutton",
}
local HINT_ICON_HEIGHT = 16

local function ModifierName(modifier)
    if modifier == "CTRL" then return CTRL_KEY_TEXT or "Ctrl" end
    if modifier == "SHIFT" then return SHIFT_KEY_TEXT or "Shift" end
end

-- Usage hint like "Ctrl + [mouse]  Reset session". If the mouse icon is missing in the client,
-- the plain text (fallback) is returned.
function ns.ClickHint(button, modifier, action, fallback)
    local atlas = MOUSE_ATLAS[button]
    local info = atlas and C_Texture.GetAtlasInfo(atlas)
    if not info then return fallback end
    local width = math.floor(HINT_ICON_HEIGHT * info.width / info.height + 0.5)
    local prefix = modifier and (ModifierName(modifier) .. " + ") or ""
    return prefix .. CreateAtlasMarkup(atlas, width, HINT_ICON_HEIGHT) .. "  " .. action
end

-- Colors are stored as hex strings ("ffRRGGBB") in the settings.
function ns.GetColor(key)
    return CreateColorFromHexString(XPForeverDB[key])
end

-- Text items. Each setting is named prefix + id, e.g. "barRate" or "infoRate".
-- value() returns the value or nil (hide the item).
ns.TEXT_ITEMS = {
    { id = "Level", label = L.itemLabelLevel, value = function()
        return tostring(state.level)
    end },
    { id = "XP", label = L.itemLabelXP, value = function()
        return string.format("%s / %s", ns.FormatNumber(state.xp), ns.FormatNumber(state.max))
    end },
    { id = "Remaining", label = L.itemLabelRemaining, value = function()
        return ns.FormatNumber(state.max - state.xp)
    end },
    { id = "Percent", label = L.itemLabelPercent, value = function()
        return ns.FormatPercent(state.xp / math.max(state.max, 1) * 100) .. " %"
    end },
    { id = "Quests", label = L.itemLabelQuests, color = "colorQuest", value = function()
        return state.questXP > 0 and "+" .. ns.FormatNumber(state.questXP) or nil
    end },
    { id = "Rested", label = L.itemLabelRested, color = "colorRested", value = function()
        return state.rested > 0 and "+" .. ns.FormatNumber(state.rested) or nil
    end },
    { id = "Rate", label = L.itemLabelRate, value = function()
        local rate = ns.GetRate()
        return rate and ns.FormatNumber(rate * 3600) or L.itemUnknown
    end },
    { id = "Time", label = L.itemLabelTime, value = function()
        local seconds = ns.GetTimeToLevel()
        return seconds and ns.FormatDuration(seconds) or L.itemUnknown
    end },
    { id = "Kills", label = L.itemLabelKills, value = function()
        local kills = ns.GetKillsToLevel()
        return kills and "~" .. ns.FormatNumber(kills) or L.itemUnknown
    end },
    { id = "Session", label = L.itemLabelSession, value = function()
        return "+" .. ns.FormatNumber((ns.GetSessionStats()))
    end },
}

function ns.HasTextItems(prefix)
    for _, item in ipairs(ns.TEXT_ITEMS) do
        if XPForeverDB[prefix .. item.id] then return true end
    end
    return false
end

-- Builds one line of text from all items enabled under the prefix ("bar"/"info").
-- Labels in gold, values in white or in their bar color.
function ns.BuildText(prefix)
    local db = XPForeverDB
    local parts = {}
    for _, item in ipairs(ns.TEXT_ITEMS) do
        if db[prefix .. item.id] then
            local value = item.value()
            if value then
                local valueColor = item.color and ns.GetColor(item.color) or HIGHLIGHT_FONT_COLOR
                table.insert(parts, NORMAL_FONT_COLOR:WrapTextInColorCode(item.label) .. " "
                    .. valueColor:WrapTextInColorCode(value))
            end
        end
    end
    return table.concat(parts, TEXT_SEPARATOR)
end
