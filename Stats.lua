local addonName, ns = ...

-- XP state, quest XP and session statistics (XP/h, kills to level).
-- Session data lives in XPForeverCharDB so it survives a /reload.
--
-- XP/h runs on an "active clock" that only advances while the player is doing something (moving,
-- fighting, gaining XP). Idle time (AFK, long breaks in town) doesn't lower the rate.

local GAIN_HISTORY_SECONDS = 3600
local KILL_SAMPLES = 10
local MAX_KILL_SHARE = 0.25 -- larger single gains (discovery, special rewards) don't count as kills
local CLASSIFY_DELAY = 0.5 -- how long an XP gain is held back to match quest turn-ins
local QUEST_MATCH_WINDOW = 2
local TURNED_IN_MEMORY = 10 -- seconds a turned-in quest stays excluded from quest XP
local MIN_RATE_SECONDS = 60
local IDLE_AFTER = 180 -- seconds without activity until the active clock stops

-- Current XP state, read by the bar, the info text and the text items.
local state = { xp = 0, max = 1, level = 1, rested = 0, questXP = 0, questCount = 0 }
ns.state = state

local Stats = {}
ns.Stats = Stats

local initialized = false
local recentQuestXP = 0
local turnedInQuests = {}
local restedBeforeGain = 0 -- highest rested XP since the last gain: rested only drops through XP gains
local lastActivity = GetTime()
local lastClockUpdate = GetTime()
local moving = false

local function CharDB()
    return XPForeverCharDB
end

function Stats.ResetSession()
    local db = CharDB()
    db.session = { start = time(), gained = 0, active = 0 }
    db.gains = {}
    db.kills = {}
end

-- Sessions from versions without the active clock are started anew; their kill samples still
-- contained the rested bonus.
function Stats.HasSession()
    local db = CharDB()
    return db.session and db.session.active and db.gains and db.kills
end

function Stats.MarkActive()
    lastActivity = GetTime()
end

function Stats.SetMoving(isMoving)
    moving = isMoving
    Stats.MarkActive()
end

-- Advances the active clock by the time since the last call, unless the player has been idle.
function Stats.UpdateActiveClock()
    local now = GetTime()
    if moving or UnitAffectingCombat("player") then lastActivity = now end
    local idleSince = lastActivity + IDLE_AFTER
    if lastClockUpdate < idleSince then
        local session = CharDB().session
        session.active = session.active + math.min(now, idleSince) - lastClockUpdate
    end
    lastClockUpdate = now
end

-- Kill detection: every XP gain is held back briefly. If a QUEST_TURNED_IN arrives meanwhile,
-- its XP is subtracted. Whatever remains counts as a kill.
-- Kills are stored without the rested bonus: while rested XP lasts, a kill gives double XP and the
-- bonus is taken from the rested pool. So base = half the gain, or gain minus the remaining rested XP.
local function ClassifyGain(amount, restedBefore)
    C_Timer.After(CLASSIFY_DELAY, function()
        local questPart = math.min(amount, recentQuestXP)
        recentQuestXP = recentQuestXP - questPart
        local gained = amount - questPart
        local killXP = math.max(gained / 2, gained - restedBefore)
        if killXP > 0 and killXP < state.max * MAX_KILL_SHARE then
            local kills = CharDB().kills
            table.insert(kills, killXP)
            while #kills > KILL_SAMPLES do table.remove(kills, 1) end
        end
        ns.Refresh()
    end)
end

local function RecordGain(amount)
    local db = CharDB()
    db.session.gained = db.session.gained + amount
    Stats.MarkActive()
    Stats.UpdateActiveClock()
    local active = db.session.active
    table.insert(db.gains, { t = active, xp = amount })
    while db.gains[1] and db.gains[1].t < active - GAIN_HISTORY_SECONDS do
        table.remove(db.gains, 1)
    end
    ClassifyGain(amount, restedBeforeGain)
end

function Stats.UpdateXP()
    local xp, max, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")

    local rested = GetXPExhaustion() or 0
    local gained = 0
    if initialized then
        gained = level > state.level and (state.max - state.xp) + xp or xp - state.xp
        if gained > 0 then RecordGain(gained) end
    end

    state.xp, state.max, state.level = xp, max, level
    state.rested = rested
    restedBeforeGain = (gained > 0 or not initialized) and rested or math.max(restedBeforeGain, rested)
    initialized = true
end

function Stats.UpdateQuestXP()
    local total, count = 0, 0
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and not turnedInQuests[info.questID]
            and C_QuestLog.IsComplete(info.questID) then
            total = total + (GetQuestLogRewardXP(info.questID) or 0)
            count = count + 1
        end
    end
    state.questXP, state.questCount = total, count
end

-- Quests just turned in may stay in the quest log briefly but no longer count as quest XP.
-- Their XP is also remembered for the kill detection.
function Stats.OnQuestTurnedIn(questID, xpReward)
    turnedInQuests[questID] = true
    C_Timer.After(TURNED_IN_MEMORY, function() turnedInQuests[questID] = nil end)
    Stats.UpdateQuestXP()

    xpReward = xpReward or 0
    recentQuestXP = recentQuestXP + xpReward
    -- Drop unmatched quest XP after a short time so later kills aren't swallowed.
    C_Timer.After(QUEST_MATCH_WINDOW, function()
        recentQuestXP = math.max(0, recentQuestXP - xpReward)
    end)
end

function ns.ShouldShow()
    return state.level < GetMaxPlayerLevel() and not IsXPUserDisabled()
end

function ns.IsQuestReady()
    return state.questXP > 0 and state.xp + state.questXP >= state.max
end

-- XP per active second over the configured period, nil while there is too little data.
function ns.GetRate()
    local db = CharDB()
    local active = db.session.active
    if active < MIN_RATE_SECONDS then return nil end

    local window = XPForeverDB.rateWindow
    if window == 0 then
        if db.session.gained <= 0 then return nil end
        return db.session.gained / active
    end

    local sum = 0
    for _, gain in ipairs(db.gains) do
        if gain.t >= active - window then sum = sum + gain.xp end
    end
    if sum <= 0 then return nil end
    return sum / math.min(window, active)
end

function ns.GetTimeToLevel()
    local rate = ns.GetRate()
    return rate and (state.max - state.xp) / rate
end

-- Estimated kills to level, based on the average of the recent kills (without rested bonus).
-- Kills give double XP until the rested XP is used up, then normal XP.
function ns.GetKillsToLevel()
    local kills = CharDB().kills
    if #kills == 0 then return nil end
    local sum = 0
    for _, xp in ipairs(kills) do sum = sum + xp end
    local perKill = sum / #kills
    local needed = state.max - state.xp
    local rested = state.rested
    if 2 * rested >= needed then
        return math.ceil(needed / (2 * perKill))
    end
    return math.ceil((needed - rested) / perKill)
end

-- XP and active time of this session.
function ns.GetSessionStats()
    local session = CharDB().session
    return session.gained, session.active
end
