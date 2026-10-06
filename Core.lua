local addonName, ns = ...
local L = ns.L

-- Einstiegspunkt: Standardeinstellungen, Events, regelmäßige Aktualisierung und Chat-Befehle.
-- Ladereihenfolge (siehe .toc): embeds.xml (Libs) → Locale → Core → Stats → Text → Bar → InfoText
-- → MinimapButton → Options.

local REFRESH_DELAY = 0.1 -- Sekunden; fasst zusammengehörige Events zu einem Neuzeichnen zusammen
local QUEST_UPDATE_DELAY = 0.5 -- QUEST_LOG_UPDATE feuert sehr oft und wird gebündelt
local TICK_INTERVAL = 5 -- Sekunden; für zeitabhängige Werte wie XP/h und Zeit bis Level-up

-- Account-weite Einstellungen. Farben als Hex-Strings ("ffRRGGBB"), wie sie der Farbwähler der Settings liefert.
ns.defaults = {
    -- Leiste
    height = 22,
    showSegments = true,
    showPercent = true,
    animate = true,
    showQuestXP = true,
    showRestedXP = true,
    showRestIndicator = true,
    showTooltip = true,
    showMinimapButton = true,
    minimap = {}, -- Position des Minimap-Buttons, verwaltet von LibDBIcon
    barTextMode = "hover", -- "hover" | "always" | "never"
    barLevel = true,
    barXP = true,
    barRemaining = true,
    barPercent = false,
    barQuests = false,
    barRested = false,
    barRate = true,
    barTime = true,
    barKills = false,
    barSession = false,

    -- Farben
    colorXP = "ff9954f5",
    colorQuest = "ffffb32e",
    colorRested = "ff3894ff",
    questOpacity = 45, -- Prozent
    restedOpacity = 30, -- Prozent
    fillGradient = true,

    -- Info-Text
    infoEnabled = true,
    infoPosition = "auto", -- "auto" | "free"
    infoOffset = 4,
    infoFontSize = 12,
    infoPoint = nil, -- { x, y } bei freier Position
    infoLevel = false,
    infoXP = false,
    infoRemaining = false,
    infoPercent = false,
    infoQuests = true,
    infoRested = true,
    infoRate = true,
    infoTime = true,
    infoKills = true,
    infoSession = false,

    -- Statistik
    rateWindow = 600, -- Sekunden, 0 = ganze Sitzung
}

-- Branding: Autor und Markenfarbe an einer Stelle, damit alle Palanim-Addons gleich auftreten.
ns.AUTHOR = "Palanim"
ns.BRAND_COLOR = CreateColorFromHexString("ff9966ff")
-- Der Packager ersetzt @project-version@ beim Release durch den Git-Tag; lokal steht der Platzhalter.
local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
ns.VERSION = version:find("^@") and "dev" or version

-- "XPForever von Palanim", Addon-Name in der Markenfarbe.
function ns.BrandLine()
    return ns.BRAND_COLOR:WrapTextInColorCode(addonName) .. " " .. L.byAuthor:format(ns.AUTHOR)
end

function ns.Print(message)
    print(ns.BRAND_COLOR:WrapTextInColorCode(addonName) .. " " .. message)
end

-- Alle sichtbaren Teile neu zeichnen bzw. Einstellungen neu anwenden.
function ns.Refresh()
    ns.Bar:Refresh()
    ns.InfoText:Refresh()
end

function ns.ApplySettings()
    ns.Bar:ApplySettings()
    ns.InfoText:ApplySettings()
    ns.MinimapButton:ApplySettings()
    ns.Refresh()
end

-- Standardwert einer Einstellung; Tabellen werden kopiert, damit Defaults nie mitverändert werden.
function ns.GetDefault(key)
    local value = ns.defaults[key]
    return type(value) == "table" and CopyTable(value) or value
end

-- Info-Text ein-/ausblenden (Linksklick auf die Leiste, Rechtsklick auf den Minimap-Button).
function ns.ToggleInfoText()
    local show = not XPForeverDB.infoEnabled
    ns.Options:SetValue("infoEnabled", show)
    ns.Print(show and L.infoShown or L.infoHidden)
end

function ns.ResetSession()
    ns.Stats.ResetSession()
    ns.Refresh()
    ns.Print(L.sessionReset)
end

-- Bei einer Quest-Abgabe kommen PLAYER_XP_UPDATE und QUEST_TURNED_IN kurz nacheinander (Reihenfolge
-- nicht garantiert). Kurz gesammelt neu zeichnen, damit XP und Quest-Vorschau in einem Schritt wechseln.
local refreshPending = false
local function ScheduleRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(REFRESH_DELAY, function()
        refreshPending = false
        ns.Refresh()
    end)
end

local questUpdatePending = false
local function ScheduleQuestUpdate()
    if questUpdatePending then return end
    questUpdatePending = true
    C_Timer.After(QUEST_UPDATE_DELAY, function()
        questUpdatePending = false
        ns.Stats.UpdateQuestXP()
        ns.Refresh()
    end)
end

-- Zeitabhängige Texte (XP/h, Zeit bis Level-up) und die Position des Info-Texts nachführen.
local function Tick()
    ns.Bar:RefreshText()
    ns.InfoText:Anchor()
    ns.InfoText:Refresh()
end

local frame = CreateFrame("Frame")
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name ~= addonName then return end
    frame:UnregisterEvent("ADDON_LOADED")

    XPForeverDB = XPForeverDB or {}
    XPForeverCharDB = XPForeverCharDB or {}

    -- Alte Einstellungen aus v0.1 übernehmen.
    if XPForeverDB.alwaysShowText then XPForeverDB.barTextMode = "always" end
    XPForeverDB.alwaysShowText = nil
    XPForeverDB.probe = nil
    XPForeverDB.infoLocked = nil -- Option entfallen (Verschieben jetzt per Shift + Ziehen)

    for key in pairs(ns.defaults) do
        if XPForeverDB[key] == nil then XPForeverDB[key] = ns.GetDefault(key) end
    end

    ns.Options:Register()
    ns.MinimapButton:Init()
end

-- Feuert auch nach jedem Ladebildschirm; Init-Funktionen laufen nur beim ersten Mal.
function handlers.PLAYER_ENTERING_WORLD(isInitialLogin)
    if isInitialLogin or not ns.Stats.HasSession() then
        ns.Stats.ResetSession()
    end
    ns.Stats.UpdateXP()
    ns.Stats.UpdateQuestXP()

    if not ns.Bar.frame then
        ns.Bar:Init()
        ns.InfoText:Init()
        C_Timer.NewTicker(TICK_INTERVAL, Tick)
    end
    ns.ApplySettings()
end

function handlers.PLAYER_XP_UPDATE()
    ns.Stats.UpdateXP()
    ScheduleRefresh()
end
handlers.PLAYER_LEVEL_UP = handlers.PLAYER_XP_UPDATE
handlers.UPDATE_EXHAUSTION = handlers.PLAYER_XP_UPDATE
handlers.ENABLE_XP_GAIN = handlers.PLAYER_XP_UPDATE
handlers.DISABLE_XP_GAIN = handlers.PLAYER_XP_UPDATE

handlers.QUEST_LOG_UPDATE = ScheduleQuestUpdate

function handlers.QUEST_TURNED_IN(questID, xpReward)
    ns.Stats.OnQuestTurnedIn(questID, xpReward)
    ScheduleRefresh()
end

function handlers.PLAYER_UPDATE_RESTING()
    ns.Bar:UpdateResting()
end

frame:SetScript("OnEvent", function(_, event, ...) handlers[event](...) end)
for event in pairs(handlers) do frame:RegisterEvent(event) end

-- Rechenzeit (Blizzards AddOn-Profiler, läuft ohnehin immer) und Speicher. Liest die Werte nur
-- im Moment des Aufrufs aus; das Ergebnis landet auch in XPForeverDB.perf (nach /reload lesbar).
local function ReportPerformance()
    local metric = Enum.AddOnProfilerMetric
    local result = { time = date("%Y-%m-%d %H:%M:%S") }
    if C_AddOnProfiler and C_AddOnProfiler.IsEnabled() then
        local function get(key) return C_AddOnProfiler.GetAddOnMetric(addonName, metric[key]) end
        result.recentMs = get("RecentAverageTime")
        result.sessionMs = get("SessionAverageTime")
        result.peakMs = get("PeakTime")
        result.ticksOver1Ms = get("CountTimeOver1Ms")
        result.allAddOnsRecentMs = C_AddOnProfiler.GetOverallMetric(metric.RecentAverageTime)
    end
    UpdateAddOnMemoryUsage()
    result.memoryKB = GetAddOnMemoryUsage(addonName)
    XPForeverDB.perf = result

    if result.recentMs then
        ns.Print(L.perfCPU:format(result.recentMs, result.sessionMs, result.peakMs, result.ticksOver1Ms))
        ns.Print(L.perfAllAddOns:format(result.allAddOnsRecentMs))
    end
    ns.Print(L.perfMemory:format(result.memoryKB))
end

SLASH_XPFOREVER1 = "/xpf"
SlashCmdList.XPFOREVER = function(msg)
    msg = strtrim(msg):lower()
    if msg == "" then
        ns.Options:Open()
    elseif msg == "reset" then
        ns.ResetSession()
    elseif msg == "perf" then
        ReportPerformance()
    else
        ns.Print("/xpf  –  " .. L.helpOptions)
        ns.Print("/xpf reset  –  " .. L.helpReset)
        ns.Print("/xpf perf  –  " .. L.helpPerf)
    end
end
