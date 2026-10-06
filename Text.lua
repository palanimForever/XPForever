local addonName, ns = ...
local L = ns.L
local state = ns.state

-- Zahlen- und Farbformatierung sowie die Textbausteine für Leisten-Text und Info-Text.

local TEXT_SEPARATOR = "  |cff808080·|r  "

-- Normalerweise formatiert WoW Zahlen nach der Client-Sprache. Ist zum Testen eine Sprache erzwungen
-- (ns.FORCE_LOCALE), werden auch die Zahlen in deren Format geschrieben.
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

-- DECIMAL_SEPERATOR (sic) ist Blizzards lokalisiertes Dezimaltrennzeichen, z. B. "," auf deDE.
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

-- Maus-Symbole aus Blizzards Einsteiger-Tutorial für Bedienhinweise in Tooltips.
local MOUSE_ATLAS = {
    LeftButton = "newplayertutorial-icon-mouse-leftbutton",
    RightButton = "newplayertutorial-icon-mouse-rightbutton",
}
local HINT_ICON_HEIGHT = 16

local function ModifierName(modifier)
    if modifier == "CTRL" then return CTRL_KEY_TEXT or "Ctrl" end
    if modifier == "SHIFT" then return SHIFT_KEY_TEXT or "Shift" end
end

-- Bedienhinweis wie "Strg + [Maus]  Sitzung zurücksetzen". Fehlt das Maus-Symbol im Client,
-- wird der reine Text (fallback) zurückgegeben.
function ns.ClickHint(button, modifier, action, fallback)
    local atlas = MOUSE_ATLAS[button]
    local info = atlas and C_Texture.GetAtlasInfo(atlas)
    if not info then return fallback end
    local width = math.floor(HINT_ICON_HEIGHT * info.width / info.height + 0.5)
    local prefix = modifier and (ModifierName(modifier) .. " + ") or ""
    return prefix .. CreateAtlasMarkup(atlas, width, HINT_ICON_HEIGHT) .. "  " .. action
end

-- Farben stehen als Hex-String ("ffRRGGBB") in den Einstellungen.
function ns.GetColor(key)
    return CreateColorFromHexString(XPForeverDB[key])
end

-- Textbausteine. Die Einstellung heißt jeweils Präfix + id, z. B. "barRate" oder "infoRate".
-- value() liefert den Wert oder nil (Baustein ausblenden).
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

-- Baut eine Textzeile aus allen Bausteinen, die unter dem Präfix ("bar"/"info") aktiviert sind.
-- Bezeichnungen in Gold, Werte in Weiß bzw. in ihrer Leistenfarbe.
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
