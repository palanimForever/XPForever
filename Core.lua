local addonName, ns = ...
local L = ns.L

-- Entry point: default settings, events, periodic updates and slash commands.
-- Load order (see .toc): embeds.xml (libs) → Locale → Core → Stats → Text → Bar → InfoText
-- → MinimapButton → Options.

local REFRESH_DELAY = 0.1 -- seconds; merges related events into a single redraw
local QUEST_UPDATE_DELAY = 0.5 -- QUEST_LOG_UPDATE fires very often and is batched
local TICK_INTERVAL = 5 -- seconds; for time-based values like XP/h and time to level

-- Account-wide settings. Colors are hex strings ("ffRRGGBB"), as returned by the settings color picker.
ns.defaults = {
    -- Bar
    barStyle = "modern", -- "modern" | "classic"
    height = 16,
    showSegments = true,
    showPercent = true,
    animate = true,
    showQuestXP = true,
    showRestedXP = true,
    showRestIndicator = true,
    showTooltip = true,
    showMinimapButton = true,
    minimap = {}, -- minimap button position, managed by LibDBIcon
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

    -- Colors
    colorXP = "ff9954f5",
    colorQuest = "ffffb32e",
    colorRested = "ff3894ff",
    questOpacity = 45, -- percent
    restedOpacity = 30, -- percent
    fillGradient = true,

    -- Info text
    infoEnabled = true,
    infoPosition = "auto", -- "auto" | "free"
    infoOffset = 4,
    infoFontSize = 12,
    infoPoint = nil, -- { x, y } when placed freely
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

    -- Statistics
    rateWindow = 600, -- seconds, 0 = whole session
}

-- Branding: author and brand color in one place so all Palanim addons look the same.
ns.AUTHOR = "Palanim"
ns.BRAND_COLOR = CreateColorFromHexString("ff9966ff")
-- The packager replaces @project-version@ with the git tag on release; locally the placeholder remains.
local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
ns.VERSION = version:find("^@") and "dev" or version

-- "XPForever by Palanim", addon name in the brand color.
function ns.BrandLine()
    return ns.BRAND_COLOR:WrapTextInColorCode(addonName) .. " " .. L.byAuthor:format(ns.AUTHOR)
end

function ns.Print(message)
    print(ns.BRAND_COLOR:WrapTextInColorCode(addonName) .. " " .. message)
end

-- Redraw all visible parts or re-apply the settings.
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

-- Default value of a setting; tables are copied so the defaults are never modified.
function ns.GetDefault(key)
    local value = ns.defaults[key]
    return type(value) == "table" and CopyTable(value) or value
end

-- Show/hide the info text (left-click on the bar, right-click on the minimap button).
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

-- On a quest turn-in, PLAYER_XP_UPDATE and QUEST_TURNED_IN arrive shortly after each other (order not
-- guaranteed). Redraw once after a short delay so XP and the quest preview change in a single step.
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

-- Keep time-based texts (XP/h, time to level) and the info text position up to date.
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

    -- Migrate settings from older versions.
    if XPForeverDB.alwaysShowText then XPForeverDB.barTextMode = "always" end
    XPForeverDB.alwaysShowText = nil
    XPForeverDB.probe = nil
    XPForeverDB.infoLocked = nil -- option removed (moving is now Shift-drag)

    for key in pairs(ns.defaults) do
        if XPForeverDB[key] == nil then XPForeverDB[key] = ns.GetDefault(key) end
    end

    ns.Options:Register()
    ns.MinimapButton:Init()
end

-- Also fires after every loading screen; the init functions only run the first time.
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
        ns.Options:ShowStylePromptOnce()
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

-- CPU time (Blizzard's addon profiler, which always runs anyway) and memory. Reads the values only
-- when called; the result is also stored in XPForeverDB.perf (readable after /reload).
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

-- Developer diagnostics: state of Blizzard's experience bars and rested markers (readable after /reload
-- in XPForeverDB.debug).
local function ReportBlizzardBars()
    local result = {}
    local xpIndex = StatusTrackingBarInfo and StatusTrackingBarInfo.BarsEnum.Experience
    for i, container in ipairs(StatusTrackingBarManager and StatusTrackingBarManager.barContainers or {}) do
        local bar = container.bars and container.bars[xpIndex]
        local tick = bar and bar.ExhaustionTick
        local entry = {
            container = container:GetName() or tostring(i),
            shownBarIndex = container.shownBarIndex,
            containerShown = container:IsShown(),
        }
        if bar then
            entry.barAlpha, entry.barEffectiveAlpha = bar:GetAlpha(), bar:GetEffectiveAlpha()
            entry.barShown = bar:IsShown()
        end
        if tick then
            entry.tickAlpha, entry.tickEffectiveAlpha = tick:GetAlpha(), tick:GetEffectiveAlpha()
            entry.tickShown, entry.tickVisible = tick:IsShown(), tick:IsVisible()
            entry.tickStrata, entry.tickIgnoreParentAlpha = tick:GetFrameStrata(), tick:IsIgnoringParentAlpha()
            local normal = tick:GetNormalTexture()
            entry.tickTextureAlpha = normal and normal:GetAlpha()
        end
        table.insert(result, entry)
        ns.Print(string.format("%s: Marker sichtbar=%s, Alpha=%.2f (effektiv %.2f)", entry.container,
            tostring(entry.tickVisible), entry.tickAlpha or -1, entry.tickEffectiveAlpha or -1))
    end
    XPForeverDB.debug = result
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
    elseif msg == "debug" then
        ReportBlizzardBars()
    elseif msg == "style" then
        ns.Options:ShowStylePrompt()
    else
        ns.Print("/xpf  –  " .. L.helpOptions)
        ns.Print("/xpf style  –  " .. L.helpStyle)
        ns.Print("/xpf reset  –  " .. L.helpReset)
        ns.Print("/xpf perf  –  " .. L.helpPerf)
    end
end
